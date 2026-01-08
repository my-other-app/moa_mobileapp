import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/storage/secure_storage_service.dart';

/// Interceptor that automatically adds authentication token to requests.
///
/// Handles:
/// - Adding Bearer token to Authorization header
/// - Skipping auth for specific requests (using 'skipAuth' extra)
/// - Token refresh on 401 errors with request retry
class AuthInterceptor extends Interceptor {
  final Ref _ref;
  final Dio _dio;

  // Lock to prevent concurrent refresh attempts
  bool _isRefreshing = false;
  final List<void Function()> _refreshQueue = [];

  AuthInterceptor(this._ref, this._dio);

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
    // Only handle 401 errors for non-auth endpoints
    if (err.response?.statusCode == 401 &&
        !err.requestOptions.path.contains('/auth/')) {
      debugPrint(
          'AuthInterceptor: 401 Unauthorized - Attempting token refresh');

      try {
        // If already refreshing, queue this request
        if (_isRefreshing) {
          debugPrint('AuthInterceptor: Refresh in progress, queuing request');
          await _queueRequest(() async {
            await _retryRequest(err.requestOptions, handler);
          });
          return;
        }

        // Start refresh process
        _isRefreshing = true;

        final secureStorage = _ref.read(secureStorageServiceProvider);
        final refreshToken = await secureStorage.getRefreshToken();

        if (refreshToken == null || refreshToken.isEmpty) {
          debugPrint('AuthInterceptor: No refresh token available');
          _isRefreshing = false;
          await _handleLogout();
          handler.next(err);
          return;
        }

        // Call refresh token endpoint
        final response = await _dio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
          options: Options(
            extra: {'skipAuth': true}, // Skip auth for refresh call
          ),
        );

        if (response.statusCode == 200) {
          // Save new tokens
          final newAccessToken = response.data['access_token'] as String?;
          final newRefreshToken = response.data['refresh_token'] as String?;

          if (newAccessToken != null && newRefreshToken != null) {
            await secureStorage.saveAccessToken(newAccessToken);
            await secureStorage.saveRefreshToken(newRefreshToken);

            debugPrint('AuthInterceptor: Token refresh successful');

            // Process queued requests
            _isRefreshing = false;
            await _processQueue();

            // Retry original request
            await _retryRequest(err.requestOptions, handler);
            return;
          }
        }

        // Refresh failed
        debugPrint('AuthInterceptor: Token refresh failed');
        _isRefreshing = false;
        await _handleLogout();
        handler.next(err);
      } catch (e) {
        debugPrint('AuthInterceptor: Error during token refresh: $e');
        _isRefreshing = false;
        _refreshQueue.clear();

        // Only logout if refresh token is invalid, not on network errors
        if (e is DioException && e.response?.statusCode == 401) {
          await _handleLogout();
        }

        handler.next(err);
      }
    } else {
      handler.next(err);
    }
  }

  Future<void> _retryRequest(
    RequestOptions requestOptions,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final secureStorage = _ref.read(secureStorageServiceProvider);
      final token = await secureStorage.getAccessToken();

      // Update request with new token
      requestOptions.headers['Authorization'] = 'Bearer $token';

      // Retry the request
      final response = await _dio.fetch(requestOptions);
      handler.resolve(response);
    } catch (e) {
      debugPrint('AuthInterceptor: Error retrying request: $e');
      if (e is DioException) {
        handler.next(e);
      } else {
        handler.next(
          DioException(
            requestOptions: requestOptions,
            error: e,
          ),
        );
      }
    }
  }

  Future<void> _queueRequest(void Function() callback) async {
    _refreshQueue.add(callback);

    // Wait for refresh to complete
    while (_isRefreshing) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _processQueue() async {
    debugPrint(
        'AuthInterceptor: Processing ${_refreshQueue.length} queued requests');

    for (final callback in _refreshQueue) {
      try {
        callback();
      } catch (e) {
        debugPrint('AuthInterceptor: Error processing queued request: $e');
      }
    }

    _refreshQueue.clear();
  }

  Future<void> _handleLogout() async {
    debugPrint('AuthInterceptor: Handling logout due to auth failure');

    try {
      final secureStorage = _ref.read(secureStorageServiceProvider);
      await secureStorage.delete(key: 'access_token');
      await secureStorage.delete(key: 'refresh_token');

      // Note: Navigation to login should be handled by the app's auth state listener
      // The auth provider will detect missing tokens and navigate appropriately
    } catch (e) {
      debugPrint('AuthInterceptor: Error during logout: $e');
    }
  }
}
