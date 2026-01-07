import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/storage/secure_storage_service.dart';

/// Interceptor that automatically adds authentication token to requests.
///
/// Handles:
/// - Adding Bearer token to Authorization header
/// - Skipping auth for specific requests (using 'skipAuth' extra)
/// - Token refresh on 401 errors (TODO)
class AuthInterceptor extends Interceptor {
  final Ref _ref;

  AuthInterceptor(this._ref);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Check if this request should skip authentication
    final skipAuth = options.extra['skipAuth'] == true;

    if (!skipAuth) {
      try {
        final secureStorage = _ref.read(secureStorageServiceProvider);
        final token = await secureStorage.getAccessToken();

        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        debugPrint('AuthInterceptor: Error getting token: $e');
      }
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Token expired or invalid
      debugPrint('AuthInterceptor: 401 Unauthorized - Token may be expired');

      // TODO: Implement token refresh logic
      // For now, we'll just pass the error along
      // In a full implementation, you would:
      // 1. Try to refresh the token
      // 2. Retry the original request
      // 3. If refresh fails, log out the user
    }

    handler.next(err);
  }
}
