/// Types of API exceptions for categorizing errors.
enum ApiExceptionType {
  network,
  timeout,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  server,
  cancelled,
  unknown,
}

/// Custom exception class for API errors.
///
/// Provides consistent error handling across the application.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ApiExceptionType type;
  final dynamic originalError;

  const ApiException({
    required this.message,
    this.statusCode,
    this.type = ApiExceptionType.unknown,
    this.originalError,
  });

  @override
  String toString() =>
      'ApiException: $message (${type.name}, code: $statusCode)';

  /// Whether this error is due to authentication issues.
  bool get isAuthError => type == ApiExceptionType.unauthorized;

  /// Whether this error is due to network issues.
  bool get isNetworkError =>
      type == ApiExceptionType.network || type == ApiExceptionType.timeout;

  /// Whether this error is a server-side error.
  bool get isServerError => type == ApiExceptionType.server;

  /// User-friendly error message for display.
  String get userMessage {
    switch (type) {
      case ApiExceptionType.network:
        return 'Please check your internet connection and try again.';
      case ApiExceptionType.timeout:
        return 'The request timed out. Please try again.';
      case ApiExceptionType.unauthorized:
        return 'Your session has expired. Please log in again.';
      case ApiExceptionType.forbidden:
        return 'You don\'t have permission to perform this action.';
      case ApiExceptionType.notFound:
        return 'The requested resource was not found.';
      case ApiExceptionType.server:
        return 'Something went wrong on our end. Please try again later.';
      case ApiExceptionType.cancelled:
        return 'The request was cancelled.';
      default:
        return message;
    }
  }
}
