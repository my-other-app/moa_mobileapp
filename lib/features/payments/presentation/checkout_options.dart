import 'package:finnet/features/payments/domain/entities/payment_order.dart';

/// What Razorpay Checkout opens with for [order]: the order's own `key_id`
/// (a club's own account, or the platform's), or [fallbackKey] -- the key
/// compiled into the app -- when the order has none (an older server).
Map<String, dynamic> razorpayCheckoutOptions(
  PaymentOrder order, {
  required String fallbackKey,
  required String name,
  required String email,
  required String phone,
}) {
  return {
    'key': order.checkoutKey(fallbackKey: fallbackKey),
    'order_id': order.razorpayOrderId,
    'amount': order.amountPaise,
    'currency': 'INR',
    'name': 'MyOtherApp',
    'prefill': {'name': name, 'email': email, 'contact': phone},
  };
}
