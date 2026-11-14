import 'package:flutter/foundation.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:finnet/features/payments/domain/repositories/payment_repository.dart';

/// What paying for a registration came to.
enum CheckoutResult {
  /// Paid: verified now, or already paid before (409 ALREADY_PAID).
  paid,

  /// The person closed the checkout, or the payment failed there: nothing
  /// was taken, and the registration is still waiting for its payment.
  notCompleted,

  /// Razorpay said the payment went through, and the server hasn't
  /// confirmed it yet: the verify failed even when asked again (a venue's
  /// Wi-Fi, a deploy), and the registration doesn't read as paid yet. The
  /// server confirms it by itself (Razorpay's webhook), so the person is
  /// never asked to pay again.
  confirming,

  /// 409 REGISTRATION_REMOVED: the organiser took the registration off the
  /// list before the payment went through. The server refunds it in full.
  removed,
}

/// What a person reads while [CheckoutResult.confirming].
const paymentConfirmingMessage = "We're confirming your payment. Your ticket "
    "will show here once it's confirmed, and you don't need to pay again.";

/// What a person reads for [CheckoutResult.removed], when the server says
/// nothing of its own.
const registrationRemovedMessage = 'This registration was cancelled before '
    'the payment went through. The payment is being refunded in full.';

/// Whether the registration reads as paid now; null when that couldn't be
/// read. Asked after a payment the server didn't confirm.
typedef PaidCheck = Future<bool?> Function();

/// `/events/info/{eventId}` as the person signed in: whether their
/// registration is paid (`is_paid`), or null when it couldn't be read.
PaidCheck registrationPaidNow(int eventId) => () async {
      try {
        final response =
            await APIService.instance.dio.get<dynamic>('/events/info/$eventId');
        final info = jsonObject(response.data);
        if (info == null || info['is_registered'] != true) return null;
        return jsonBool(info['is_paid']);
      } catch (e) {
        debugPrint('PaymentConfirmation: could not read the registration: $e');
        return null;
      }
    };

/// After Razorpay said a payment went through: tell the server, and keep at
/// it when the answer doesn't come.
///
/// `POST /payments/verify` is asked again after each of [verifyWaits] (1 s,
/// 3 s, 8 s) when it got no answer, the server was down or busy (5xx), the
/// address was over its limit (429 RATE_LIMITED), or Razorpay didn't have
/// the payment yet (404 PAYMENT_NOT_FOUND). Then the registration itself
/// is read ([isPaidNow]) after each of [recheckWaits]: paid by the webhook
/// meanwhile is paid. Anything else is [CheckoutResult.confirming], never
/// "pay again".
class PaymentConfirmation {
  PaymentConfirmation({
    required this.repository,
    this.isPaidNow,
    this.verifyWaits = const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 8),
    ],
    this.recheckWaits = const [
      Duration.zero,
      Duration(seconds: 3),
      Duration(seconds: 7),
    ],
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? Future<void>.delayed;

  final PaymentRepository repository;
  final PaidCheck? isPaidNow;
  final List<Duration> verifyWaits;
  final List<Duration> recheckWaits;
  final Future<void> Function(Duration) _wait;

  /// The server's message for [CheckoutResult.removed], if it sent one.
  String? removedMessage;

  /// [paymentId] null: Razorpay said it went through without saying which
  /// payment. Nothing to verify; the registration is read.
  Future<CheckoutResult> confirm({
    required String razorpayOrderId,
    String? paymentId,
  }) async {
    if (paymentId != null && paymentId.isNotEmpty) {
      for (var attempt = 0;; attempt++) {
        final verified = await repository.verifyPayment(
          razorpayOrderId: razorpayOrderId,
          razorpayPaymentId: paymentId,
        );
        if (verified.isRight) return CheckoutResult.paid;
        final failure = verified.left;
        if (failure.code == alreadyPaidCode) return CheckoutResult.paid;
        if (failure.code == registrationRemovedCode) {
          removedMessage = failure.message;
          return CheckoutResult.removed;
        }
        if (!worthAskingAgain(failure) || attempt >= verifyWaits.length) break;
        await _wait(verifyWaits[attempt]);
      }
    }
    final check = isPaidNow;
    if (check != null) {
      for (final wait in recheckWaits) {
        await _wait(wait);
        if (await check() == true) return CheckoutResult.paid;
      }
    }
    return CheckoutResult.confirming;
  }

  /// A verify failure that may well go through if asked again.
  @visibleForTesting
  static bool worthAskingAgain(Failure failure) {
    if (failure is NetworkFailure) return true;
    final code = failure.code;
    if (code == rateLimitedCode || code == '429') return true;
    if (code == paymentNotFoundCode) return true;
    // A 5xx: the server, or the gateway in front of it, down or busy. A
    // plain 404 is a ServerFailure too, and is not this.
    return failure is ServerFailure && code != '404';
  }
}
