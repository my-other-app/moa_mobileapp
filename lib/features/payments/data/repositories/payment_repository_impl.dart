import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:finnet/features/payments/domain/entities/payment_order.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:finnet/features/payments/domain/repositories/payment_repository.dart';

/// Provider for the payments repository.
final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepositoryImpl(
    remoteDataSource: ref.watch(paymentRemoteDataSourceProvider),
  );
});

/// Turn whatever a payments call threw into a [Failure] a person can read.
///
/// 409 UPDATE_APP_TO_PAY becomes an [UpdateAppToPayFailure] carrying the
/// server's words and `errors.web_url`. Anything else keeps the kind from
/// [mapErrorToFailure] and the server's own `message` where there is one.
@visibleForTesting
Failure paymentFailureFrom(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    final inner = error.error;
    final code = inner is ApiException
        ? inner.errorCode
        : (data is Map ? data['error_code'] : null);
    if (code == updateAppToPayCode) {
      final errors = data is Map ? data['errors'] : null;
      final webUrl = errors is Map ? errors['web_url'] : null;
      final message = data is Map ? data['message'] : null;
      return UpdateAppToPayFailure(
        message: message is String && message.isNotEmpty
            ? message
            : const UpdateAppToPayFailure().message,
        webUrl: webUrl is String && webUrl.isNotEmpty ? webUrl : null,
      );
    }
  }

  final mapped = mapErrorToFailure(error);
  final message = error is DioException
      ? extractErrorMessage(error, defaultMessage: mapped.message)
      : mapped.message;
  final status = error is DioException ? error.response?.statusCode : null;
  final code = mapped.code ?? status?.toString();

  if (mapped is NetworkFailure) return NetworkFailure(message: message, code: code);
  if (mapped is AuthFailure) return AuthFailure(message: message, code: code);
  if (mapped is ValidationFailure) {
    return ValidationFailure(message: message, code: code);
  }
  if (mapped is ServerFailure) return ServerFailure(message: message, code: code);
  return UnknownFailure(message: message, code: code);
}

/// Implementation of [PaymentRepository].
class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource remoteDataSource;

  PaymentRepositoryImpl({required this.remoteDataSource});

  Future<Result<T>> _guard<T>(String name, Future<T> Function() call) async {
    try {
      return Either.right(await call());
    } catch (e) {
      debugPrint('PaymentRepository.$name error: $e');
      return Either.left(paymentFailureFrom(e));
    }
  }

  @override
  Future<Result<PaymentOrder>> createRegistrationOrder({
    required int eventId,
    required String registrationId,
  }) {
    return _guard('createRegistrationOrder', () async {
      final order = await remoteDataSource.createRegistrationOrder(
        eventId: eventId,
        registrationId: registrationId,
      );
      return order.toEntity();
    });
  }

  @override
  Future<Result<void>> verifyPayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
  }) {
    return _guard('verifyPayment', () {
      return remoteDataSource.verifyPayment(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId,
      );
    });
  }
}
