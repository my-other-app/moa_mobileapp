import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/payments/domain/entities/payment_order.dart';

/// Paying through Razorpay: making the order, then confirming the payment.
abstract class PaymentRepository {
  /// The order for a registration (its ticket and any shelf picks). Fails
  /// with an `UpdateAppToPayFailure` when the server says this client
  /// cannot pay the event.
  Future<Result<PaymentOrder>> createRegistrationOrder({
    required int eventId,
    required String registrationId,
  });

  /// Tells the server a checkout succeeded; it confirms with Razorpay.
  Future<Result<void>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
  });
}
