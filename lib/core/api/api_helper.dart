import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/services/analytics_service.dart';

export 'package:finnet/core/network/api_exception.dart';
export 'package:finnet/core/network/dio_client.dart' show ApiResult;
export 'package:finnet/core/cache/api_cache.dart' show CachePolicy, CacheScope;

enum DioMethod { post, get, put, delete, patch }

/// APIService - uses the single app-wide Dio client with the full
/// interceptor stack.
///
/// All requests automatically include:
/// - Auth token injection + refresh-on-401 (via AuthInterceptor)
/// - Error handling (via ErrorInterceptor), with API errors also logged
///   to analytics
/// - Logging in debug mode (via LoggingInterceptor)
class APIService {
  final Dio _dio;

  APIService._(this._dio);

  /// An APIService over [dio], for tests.
  @visibleForTesting
  factory APIService.over(Dio dio) => APIService._(dio);

  /// The one real Dio instance used app-wide.
  Dio get dio => _dio;

  /// Get APIService instance from Riverpod ref.
  /// Preferred way to access the service.
  static APIService fromRef(Ref ref) {
    return APIService._(ref.read(dioProvider));
  }

  /// Singleton access — same underlying Dio as [fromRef]/[dioProvider],
  /// for call sites without access to a Riverpod [Ref].
  static final APIService instance = APIService._(_buildDio());

  static Dio _buildDio() {
    final dio = buildAppDio();

    // Log API errors to analytics, in addition to the shared ErrorInterceptor.
    // Never awaited and never allowed to throw: this used to await the log
    // before passing the error on, so when Firebase had failed to start
    // (AnalyticsService.instance throws) every failed request hung forever
    // instead of failing.
    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        logApiErrorQuietly(error);
        handler.next(error);
      },
    ));

    return dio;
  }

  /// Make an API request with automatic error handling.
  Future<Response> request(
    String endpoint,
    DioMethod method, {
    Map<String, dynamic>? param,
    String? contentType,
    dynamic formData,
    bool skipAuth = false,
    Map<String, dynamic>? headers,
    CachePolicy? cache,
  }) async {
    try {
      // Configure request options
      final options = Options(
        contentType: contentType,
        headers: headers,
        extra: {
          'skipAuth': skipAuth,
          // Only a GET is ever saved; ApiCacheInterceptor ignores the rest.
          if (cache != null) ...cache.extra,
        },
      );

      switch (method) {
        case DioMethod.post:
          return await _dio.post(
            endpoint,
            data: param ?? formData,
            options: options,
          );
        case DioMethod.get:
          return await _dio.get(
            endpoint,
            queryParameters: param,
            options: options,
          );
        case DioMethod.put:
          return await _dio.put(
            endpoint,
            data: param ?? formData,
            options: options,
          );
        case DioMethod.delete:
          return await _dio.delete(
            endpoint,
            data: param ?? formData,
            options: options,
          );
        case DioMethod.patch:
          return await _dio.patch(
            endpoint,
            data: param ?? formData,
            options: options,
          );
      }
    } on DioException catch (e) {
      // If error interceptor converted it to ApiException, rethrow that
      if (e.error is ApiException) {
        throw e.error as ApiException;
      }
      debugPrint('API request failed: ${e.message}');
      rethrow;
    }
  }

  /// The saved answer to `GET [endpoint]` (with [param]), or null when
  /// there is none or it is older than the cache keeps anything. Reads the
  /// disk only; never the network.
  Future<dynamic> savedCopy(
    String endpoint, {
    Map<String, dynamic>? param,
    CachePolicy policy = CachePolicy.shared,
  }) async {
    return ApiCache.instance
        .savedAnswer(_dio, endpoint, query: param, scope: policy.scope);
  }

  /// `GET [endpoint]`, stale-while-revalidate: [onData] gets the saved
  /// answer at once (`fresh: false`) if there is one, then the network's
  /// (`fresh: true`). A 304 hands back the saved body, which is current.
  ///
  /// When the network fails after a saved copy was shown, the copy stays
  /// and nothing is thrown: the offline strip says why. With nothing saved,
  /// the failure is thrown as [request] throws it.
  Future<void> getSavedThenFresh(
    String endpoint, {
    Map<String, dynamic>? param,
    CachePolicy policy = CachePolicy.shared,
    required void Function(dynamic data, {required bool fresh}) onData,
  }) async {
    dynamic saved;
    try {
      saved = await savedCopy(endpoint, param: param, policy: policy);
    } catch (e) {
      debugPrint('APIService: no saved copy of $endpoint: $e');
    }
    if (saved != null) onData(saved, fresh: false);
    try {
      final response = await request(
        endpoint,
        DioMethod.get,
        param: param,
        cache: policy,
      );
      final offline =
          ApiCacheInterceptor.answerOf(response) == CachedAnswer.offline;
      // Offline, the interceptor answered with the copy already shown.
      if (offline && saved != null) return;
      onData(response.data, fresh: !offline);
    } catch (e) {
      if (saved == null) rethrow;
      debugPrint('APIService: kept the saved copy of $endpoint: $e');
    }
  }

  /// Typed request with automatic JSON parsing.
  Future<ApiResult<T>> requestTyped<T>(
    String endpoint,
    DioMethod method, {
    required T Function(dynamic json) fromJson,
    Map<String, dynamic>? param,
    String? contentType,
    dynamic formData,
    bool skipAuth = false,
  }) async {
    try {
      final response = await request(
        endpoint,
        method,
        param: param,
        contentType: contentType,
        formData: formData,
        skipAuth: skipAuth,
      );

      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        return ApiResult.success(fromJson(response.data));
      }
      return ApiResult.failure(
          'Request failed with status ${response.statusCode}');
    } on ApiException catch (e) {
      return ApiResult.failure(e.userMessage);
    } catch (e) {
      return ApiResult.failure('An unexpected error occurred');
    }
  }
}

/// Report a failed request to analytics without waiting on it or letting
/// its failure reach the request.
@visibleForTesting
void logApiErrorQuietly(
  DioException error, {
  Future<void> Function(String path, int? status, String? message)? log,
}) {
  try {
    final report = log ??
        (path, status, message) =>
            AnalyticsService.instance.logApiError(path, status, message);
    unawaited(report(
      error.requestOptions.path,
      error.response?.statusCode,
      error.message,
    ).catchError((Object e) {
      debugPrint('APIService: could not log the API error: $e');
    }));
  } catch (e) {
    debugPrint('APIService: could not log the API error: $e');
  }
}

/// Riverpod provider for APIService with proper Dio client.
final apiServiceProvider = Provider<APIService>((ref) {
  return APIService.fromRef(ref);
});
