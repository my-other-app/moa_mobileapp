import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:finnet/core/config/env/env.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:finnet/features/payments/domain/repositories/payment_repository.dart';
import 'package:finnet/features/payments/presentation/checkout_options.dart';

/// Paying for a registration: the ticket and whatever was picked from the
/// shelf, in one Razorpay checkout — the same three steps the website takes.
class RegistrationCheckout {
  /// Asks the API for a Razorpay order for this registration, opens the
  /// checkout with the order's own key, and verifies the payment.
  ///
  /// Right(true) once verified, or when the server says it is already paid
  /// (409 ALREADY_PAID: nothing is owed, so there is nothing to open);
  /// Right(false) when the person backed out or the payment failed. Left
  /// when no order could be made -- among them an `UpdateAppToPayFailure`,
  /// which carries the website link, and a `NothingToPayFailure`.
  static Future<Result<bool>> pay({
    required PaymentRepository repository,
    required int eventId,
    required String registrationId,
    required String name,
    required String email,
    required String phone,
  }) async {
    final made = await repository.createRegistrationOrder(
      eventId: eventId,
      registrationId: registrationId,
    );
    if (made.isLeft) {
      if (made.left is AlreadyPaidFailure) return Either.right(true);
      return Either.left(made.left);
    }
    final order = made.right;

    final completer = Completer<bool>();
    final razorpay = Razorpay();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) async {
      final paymentId = r.paymentId;
      if (paymentId == null) {
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      final verified = await repository.verifyPayment(
        razorpayOrderId: order.razorpayOrderId,
        razorpayPaymentId: paymentId,
      );
      if (!completer.isCompleted) completer.complete(verified.isRight);
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!completer.isCompleted) completer.complete(false);
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
