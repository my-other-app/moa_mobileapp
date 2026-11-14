import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:finnet/core/config/env/env.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:finnet/features/payments/domain/repositories/payment_repository.dart';
import 'package:finnet/features/payments/payment_confirmation.dart';
import 'package:finnet/features/payments/presentation/checkout_options.dart';

/// Paying for a registration: the ticket and whatever was picked from the
/// shelf, in one Razorpay checkout — the same three steps the website takes.
class RegistrationCheckout {
  /// Asks the API for a Razorpay order for this registration, opens the
  /// checkout with the order's own key, and confirms the payment
  /// ([PaymentConfirmation]).
  ///
  /// Right([CheckoutResult.paid]) once verified, or when the server says it
  /// is already paid (409 ALREADY_PAID: nothing is owed, so there is
  /// nothing to open); [CheckoutResult.notCompleted] when the person backed
  /// out or the payment failed in the checkout. Once Razorpay has said the
  /// payment went through, never notCompleted: [CheckoutResult.paid],
  /// [CheckoutResult.removed] (the registration was taken off the list; it
  /// is refunded), or [CheckoutResult.confirming] -- verify kept failing
  /// and the registration ([isPaidNow], by default `/events/info`) doesn't
  /// read as paid yet. [whileConfirming] wraps that part, to say so on the
  /// screen while it runs.
  ///
  /// Left when no order could be made -- among them an
  /// `UpdateAppToPayFailure`, which carries the website link, and a
  /// `NothingToPayFailure`.
  ///
  /// [sellable] is `canSellInApp` for the event: false (a paid online event
  /// on an iPhone) answers [InAppSaleBlockedFailure] without asking for an
  /// order, so no checkout can open for it whichever screen asked.
  static Future<Result<CheckoutResult>> pay({
    required PaymentRepository repository,
    required int eventId,
    required String registrationId,
    required String name,
    required String email,
    required String phone,
    bool sellable = true,
    PaidCheck? isPaidNow,
    Future<CheckoutResult> Function(Future<CheckoutResult> confirming)?
        whileConfirming,
  }) async {
    if (!sellable) return Either.left(const InAppSaleBlockedFailure());
    final made = await repository.createRegistrationOrder(
      eventId: eventId,
      registrationId: registrationId,
    );
    if (made.isLeft) {
      if (made.left is AlreadyPaidFailure) {
        return Either.right(CheckoutResult.paid);
      }
      return Either.left(made.left);
    }
    final order = made.right;
    final confirmation = PaymentConfirmation(
      repository: repository,
      isPaidNow: isPaidNow ?? registrationPaidNow(eventId),
    );

    final completer = Completer<CheckoutResult>();
    final razorpay = Razorpay();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (completer.isCompleted) return;
      // Razorpay has taken the money: from here on the answer is paid,
      // removed or still confirming -- never "pay again".
      final confirming = confirmation.confirm(
        razorpayOrderId: order.razorpayOrderId,
        paymentId: r.paymentId,
      );
      completer.complete(whileConfirming?.call(confirming) ?? confirming);
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!completer.isCompleted) completer.complete(CheckoutResult.notCompleted);
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
    razorpay.open(razorpayCheckoutOptions(
      order,
      fallbackKey: Env.razorpayKeyId,
      name: name,
      email: email,
      phone: phone,
    ));
    try {
      return Either.right(await completer.future);
    } finally {
      razorpay.clear();
    }
  }
}
