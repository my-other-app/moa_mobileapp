import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/config/env/env.dart';
import 'package:finnet/core/network/interceptors/auth_interceptor.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/network/interceptors/logging_interceptor.dart';
import 'package:finnet/core/network/interceptors/retry_interceptor.dart';
import 'package:finnet/core/network/interceptors/topic_change_interceptor.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';

/// Builds the single Dio instance used app-wide, with the full interceptor
/// stack: one retry for a GET that never reached the server, the offline
/// state, saved answers revalidated by ETag (for GETs that ask), auth token
/// injection + refresh-on-401, error handling, and debug
/// logging.
///
/// There is no certificate pinning. The interceptor that claimed to pin
/// installed a `badCertificateCallback`, which the platform only calls for a
/// certificate it has already rejected -- so it could never pin a valid one,
/// and with no fingerprints configured it did nothing at all.
Dio buildAppDio() {
  final dio = Dio(
    BaseOptions(
      baseUrl: Env.apiBaseUrl,
      // 15 s to connect, then one retry for a read (RetryInterceptor): a
      // dead network is reported in about half a minute, not a minute.
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      // Uploads (a profile picture, a post's photo) on a slow uplink.
      sendTimeout: const Duration(seconds: 60),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ),
  );

  NetworkStatus.instance.probeTarget = Uri.tryParse(Env.apiBaseUrl);

  // Add interceptors - order matters! Errors pass through them in this
  // order: a connection failure on a GET is retried first; only a failure
  // that survives the retry tells the app it is offline, and is then
  // answered from the saved copy if the request asked for one.
  dio.interceptors.addAll([
    RetryInterceptor(dio),
    NetworkStatusInterceptor(),
    ApiCacheInterceptor(),
    AuthInterceptor(SecureStorageService(), dio),
    ErrorInterceptor(),
    TopicChangeInterceptor(),
    if (kDebugMode) LoggingInterceptor(),
  ]);

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
