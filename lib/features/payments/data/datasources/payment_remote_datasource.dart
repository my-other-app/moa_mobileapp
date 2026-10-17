import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/payments/data/models/payment_order_model.dart';

/// Provider for the payments remote data source.
final paymentRemoteDataSourceProvider = Provider<PaymentRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return PaymentRemoteDataSourceImpl(dio);
});

/// Sent as `?checkout=` on every order: this build opens checkout with the
/// order's own `key_id`, so it can pay an event sold on a club's own Razorpay
/// account. Without it the server answers those with 409 UPDATE_APP_TO_PAY.
const checkoutVersion = 2;

/// Remote calls for payments, checked against the backend's
/// `app/api/payments/router.py`.
abstract class PaymentRemoteDataSource {
  /// `POST /payments/orders?checkout=2` with
  /// `{source: "event_registration", payload: {event_id, event_registration_id}}`.
  Future<PaymentOrderModel> createRegistrationOrder({
    required int eventId,
    required String registrationId,
  });

  /// `POST /payments/verify` with `{razorpay_order_id, razorpay_payment_id}`.
  /// Sent without the user's token, as it always has been.
  Future<void> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
  });
}

/// Implementation of [PaymentRemoteDataSource] over the app's Dio.
class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  final Dio _dio;

  PaymentRemoteDataSourceImpl(this._dio);

  @override
  Future<PaymentOrderModel> createRegistrationOrder({
    required int eventId,
    required String registrationId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/payments/orders',
      queryParameters: {'checkout': checkoutVersion},
      data: {
        'source': 'event_registration',
        'payload': {'event_id': eventId, 'event_registration_id': registrationId},
      },
    );
    return PaymentOrderModel.fromJson(response.data);
  }

  @override
  Future<void> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
  }) async {
    await _dio.post<dynamic>(
      '/payments/verify',
      data: {
        'razorpay_order_id': razorpayOrderId,
        'razorpay_payment_id': razorpayPaymentId,
      },
      options: Options(extra: {'skipAuth': true}),
    );
  }
}
