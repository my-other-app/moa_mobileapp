import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/config/env/env.dart';
import 'package:myotherapp/core/network/interceptors/auth_interceptor.dart';
import 'package:myotherapp/core/network/interceptors/cert_pinning_interceptor.dart';
import 'package:myotherapp/core/network/interceptors/error_interceptor.dart';
import 'package:myotherapp/core/network/interceptors/logging_interceptor.dart';

/// Provider for the Dio HTTP client instance.
///
/// This client is configured with:
/// - Base URL from environment
/// - Auth interceptor for automatic token injection and refresh
/// - Error interceptor for consistent error handling
/// - Certificate pinning for MITM protection (production)
/// - Logging interceptor for debug mode
final dioProvider = Provider<Dio>((ref) {
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
    CertPinningInterceptor(), // Security first
    AuthInterceptor(ref, dio), // Pass dio for refresh API calls
    ErrorInterceptor(),
    if (kDebugMode) LoggingInterceptor(),
  ]);

  return dio;
});

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
