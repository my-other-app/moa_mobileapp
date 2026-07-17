import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/services/analytics_service.dart';

export 'package:finnet/core/network/api_exception.dart';
export 'package:finnet/core/network/dio_client.dart' show ApiResult;

enum DioMethod { post, get, put, delete, patch }

/// APIService - uses the single app-wide Dio client with the full
/// interceptor stack.
///
/// All requests automatically include:
/// - Auth token injection + refresh-on-401 (via AuthInterceptor)
/// - Certificate pinning (via CertPinningInterceptor, production only)
/// - Error handling (via ErrorInterceptor), with API errors also logged
///   to analytics
/// - Logging in debug mode (via LoggingInterceptor)
class APIService {
  final Dio _dio;

  APIService._(this._dio);

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

    // Log API errors to analytics, in addition to the shared ErrorInterceptor
    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        await AnalyticsService.instance.logApiError(
          error.requestOptions.path,
          error.response?.statusCode,
          error.message,
        );
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
  }) async {
    try {
      // Configure request options
      final options = Options(
        contentType: contentType,
        headers: headers,
        extra: {'skipAuth': skipAuth},
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

/// Riverpod provider for APIService with proper Dio client.
final apiServiceProvider = Provider<APIService>((ref) {
  return APIService.fromRef(ref);
});
