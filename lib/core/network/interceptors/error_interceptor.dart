import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:finnet/core/network/api_exception.dart';

/// Interceptor for consistent error handling across all API requests.
///
/// Converts DioExceptions to custom ApiException for easier handling
/// in the application layer.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final apiException = _handleError(err);

    debugPrint('ErrorInterceptor: ${apiException.message}');

    handler.next(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: apiException,
      ),
    );
  }

  ApiException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message:
              'Connection timed out. Please check your internet connection.',
          statusCode: null,
          type: ApiExceptionType.timeout,
        );

      case DioExceptionType.connectionError:
        return ApiException(
          message: 'No internet connection. Please check your network.',
          statusCode: null,
          type: ApiExceptionType.network,
        );

      case DioExceptionType.badResponse:
        return _handleBadResponse(error.response);

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request was cancelled.',
          statusCode: null,
          type: ApiExceptionType.cancelled,
        );

      default:
        return ApiException(
          message: error.message ?? 'An unexpected error occurred.',
          statusCode: null,
          type: ApiExceptionType.unknown,
        );
    }
  }

  ApiException _handleBadResponse(Response? response) {
    final statusCode = response?.statusCode;

    // What the server said, kept apart from what we show. The friendly copy
    // below replaces the server's words for most statuses; `serverMessage`
    // carries the original through so a caller that needs the real reason --
    // check-in classifying a refusal at the door, say -- can still read it.
    String? serverMessage;
    String? errorCode;
    if (response?.data is Map<String, dynamic>) {
      final data = response!.data as Map<String, dynamic>;
      serverMessage = (data['message'] ?? data['error']) as String?;
      errorCode = data['error_code'] as String?;
    }
    final message = serverMessage ?? 'An error occurred';

    switch (statusCode) {
      case 400:
        return ApiException(
          message: message,
          statusCode: 400,
          type: ApiExceptionType.badRequest,
          serverMessage: serverMessage,
          errorCode: errorCode,
        );
      case 401:
        return ApiException(
          message: 'Unauthorized. Please log in again.',
          statusCode: 401,
          type: ApiExceptionType.unauthorized,
          serverMessage: serverMessage,
          errorCode: errorCode,
        );
      case 403:
        return ApiException(
          message: 'You do not have permission to access this resource.',
          statusCode: 403,
          type: ApiExceptionType.forbidden,
          serverMessage: serverMessage,
          errorCode: errorCode,
        );
      case 404:
        return ApiException(
          message: 'Resource not found.',
          statusCode: 404,
          type: ApiExceptionType.notFound,
          serverMessage: serverMessage,
          errorCode: errorCode,
        );
      case 500:
      case 502:
      case 503:
        return ApiException(
          message: 'Server error. Please try again later.',
          statusCode: statusCode,
          type: ApiExceptionType.server,
          serverMessage: serverMessage,
          errorCode: errorCode,
        );
      default:
        return ApiException(
          message: message,
          statusCode: statusCode,
          type: ApiExceptionType.unknown,
          serverMessage: serverMessage,
          errorCode: errorCode,
        );
    }
  }
}
