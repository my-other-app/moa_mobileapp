import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/config/env/env.dart';

/// Paying for a registration: the ticket and whatever was picked from the
/// shelf, in one Razorpay checkout — the same three steps the website takes.
class RegistrationCheckout {
  /// Asks the API for a Razorpay order for this registration, opens the
  /// checkout, and verifies the payment. Resolves true once verified;
  /// false when the person backed out or the payment failed.
  static Future<bool> pay({
    required int eventId,
    required String registrationId,
    required String name,
    required String email,
    required String phone,
  }) async {
    final orderRes = await APIService.instance.request(
      '/payments/orders',
      DioMethod.post,
      param: {
        'source': 'event_registration',
        'payload': {'event_id': eventId, 'event_registration_id': registrationId},
      },
    );
    final order = orderRes.data as Map<String, dynamic>;
    final razorpayOrderId = order['razorpay_order_id'] as String;
    final amountRupees = (order['amount'] as num).toDouble();

    final completer = Completer<bool>();
    final razorpay = Razorpay();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) async {
      try {
        await APIService.instance.request(
          '/payments/verify',
          DioMethod.post,
          param: {'razorpay_order_id': razorpayOrderId, 'razorpay_payment_id': r.paymentId},
          skipAuth: true,
        );
        if (!completer.isCompleted) completer.complete(true);
      } catch (e) {
        debugPrint('verify failed: $e');
        if (!completer.isCompleted) completer.complete(false);
      }
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!completer.isCompleted) completer.complete(false);
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse r) {});
    razorpay.open({
      'key': Env.razorpayKeyId,
      'order_id': razorpayOrderId,
      'amount': (amountRupees * 100).round(),
      'currency': 'INR',
      'name': 'MyOtherApp',
      'prefill': {'name': name, 'email': email, 'contact': phone},
    });
    try {
      return await completer.future;
    } finally {
      razorpay.clear();
    }
  }
}
