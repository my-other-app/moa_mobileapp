import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/config/env/env.dart';
import 'package:finnet/core/network/interceptors/auth_interceptor.dart';
import 'package:finnet/core/network/interceptors/cert_pinning_interceptor.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/network/interceptors/logging_interceptor.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';

/// Builds the single Dio instance used app-wide, with the full interceptor
/// stack: auth token injection + refresh-on-401, cert pinning, error
/// handling, and debug logging.
Dio buildAppDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  // Add interceptors - order matters!
  dio.interceptors.addAll([
    AuthInterceptor(SecureStorageService(), dio),
    ErrorInterceptor(),
    if (kDebugMode) LoggingInterceptor(),
  ]);

  if (!kDebugMode) {
    configureCertPinning(dio);
  }

  return dio;
}

/// Provider for the app-wide Dio HTTP client instance. Backed by the same
/// singleton Dio as [APIService.instance] — there is only one real Dio
/// instance in the app, reachable through either access pattern.
final dioProvider = Provider<Dio>((ref) => APIService.instance.dio);

/// API result wrapper for consistent response handling.
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult._({this.data, this.error, required this.isSuccess});

  factory ApiResult.success(T data) => ApiResult._(data: data, isSuccess: true);
  factory ApiResult.failure(String error) =>
      ApiResult._(error: error, isSuccess: false);

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String error) onFailure,
  }) {
    if (isSuccess && data != null) {
      return onSuccess(data as T);
    }
    return onFailure(error ?? 'Unknown error occurred');
  }
}
