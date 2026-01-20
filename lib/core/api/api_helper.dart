import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/config/env/env.dart';
import 'package:myotherapp/core/network/dio_client.dart';
import 'package:myotherapp/core/network/api_exception.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/core/services/analytics_service.dart';

export 'package:myotherapp/core/network/api_exception.dart';
export 'package:myotherapp/core/network/dio_client.dart' show ApiResult;

enum DioMethod { post, get, put, delete, patch }

/// APIService - uses singleton Dio client with proper interceptors.
///
/// All requests automatically include:
/// - Auth token injection (via AuthInterceptor)
/// - Certificate pinning (via CertPinningInterceptor)
/// - Error handling (via ErrorInterceptor)
/// - Logging in debug mode (via LoggingInterceptor)
class APIService {
  final Dio _dio;

  APIService._(this._dio);

  /// Get APIService instance from Riverpod ref.
  /// Preferred way to access the service.
  static APIService fromRef(Ref ref) {
    return APIService._(ref.read(dioProvider));
  }

  /// Legacy singleton access - uses Env.apiBaseUrl with manual token handling.
  static final APIService instance = APIService._(_createLegacyDio());

  static Dio _createLegacyDio() {
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

    // Add interceptor for manual token injection in legacy mode
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final skipAuth = options.extra['skipAuth'] == true;
        if (!skipAuth) {
          try {
            final token = await SecureStorage.instance.getAccessToken();
            if (token.accessToken.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer ${token.accessToken}';
            }
          } catch (e) {
            debugPrint('Legacy Dio: Error getting token: $e');
          }
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Log API errors to analytics
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
