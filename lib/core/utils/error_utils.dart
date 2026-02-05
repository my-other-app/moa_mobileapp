import 'package:dio/dio.dart';

/// Extracts a user-friendly error message from any exception,
/// with special handling for DioException to get the actual API error message.
String extractErrorMessage(dynamic error,
    {String defaultMessage = 'An error occurred'}) {
  if (error is DioException) {
    // Try to extract message from response data
    final responseData = error.response?.data;
    if (responseData != null) {
      if (responseData is Map) {
        // Check for common error message fields
        if (responseData['message'] != null) {
          return responseData['message'].toString();
        }
        if (responseData['detail'] != null) {
          // FastAPI validation errors have detail as a list
          final detail = responseData['detail'];
          if (detail is List && detail.isNotEmpty) {
            // Get first validation error message
            final firstError = detail.first;
            if (firstError is Map && firstError['msg'] != null) {
              return firstError['msg'].toString();
            }
            return detail.map((e) => e['msg'] ?? e.toString()).join(', ');
          }
          return detail.toString();
        }
        if (responseData['error'] != null) {
          return responseData['error'].toString();
        }
      } else if (responseData is String && responseData.isNotEmpty) {
        return responseData;
      }
    }

    // Fall back to Dio's error message
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }

    // Handle common Dio exception types
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode == 401) return 'Session expired. Please login again.';
        if (statusCode == 403)
          return 'You don\'t have permission for this action.';
        if (statusCode == 404) return 'The requested resource was not found.';
        if (statusCode == 500) return 'Server error. Please try again later.';
        return 'Request failed with status $statusCode';
      default:
        return defaultMessage;
    }
  }

  // For non-Dio exceptions, use toString but clean it up
  final errorString = error.toString();
  // Remove common prefixes that aren't user-friendly
  if (errorString.startsWith('Exception:')) {
    return errorString.substring(10).trim();
  }

  return errorString;
}
