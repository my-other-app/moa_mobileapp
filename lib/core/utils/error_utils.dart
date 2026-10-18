import 'package:dio/dio.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';

/// The words to show a person for [error], whatever threw it.
///
/// - An API error -- an [ApiException] from `APIService.request`, or the
///   [DioException] carrying one that a direct Dio call throws -- reads as
///   [ApiException.userMessage]: the server's `message` (or an older route's
///   `detail`) for a 4xx, friendly copy for a dropped connection, a timeout
///   or a 5xx.
/// - A [Failure] reads as its message; a [String] as itself.
/// - `throw Exception('Words')` reads as "Words": that is app copy.
/// - Anything else -- a [TypeError], a `PlatformException`, a custom
///   exception's `toString()` -- reads as [defaultMessage]. It used to read as
///   its `toString()`, which is how people saw
///   "ApiException: ... (badRequest, code: 400)".
///
/// Never returns a class name or a status code.
String extractErrorMessage(
  Object? error, {
  String defaultMessage = ApiException.genericMessage,
}) {
  if (error == null) return defaultMessage;
  if (error is String) return _orDefault(error, defaultMessage);
  if (error is Failure) return _orDefault(error.message, defaultMessage);

  final api = apiExceptionOf(error);
  if (api != null) {
    final message = api.userMessage;
    // "Something went wrong" is the last resort; a caller who knows what was
    // being attempted ("Could not load this club") says it better.
    return message == ApiException.genericMessage
        ? defaultMessage
        : _orDefault(message, defaultMessage);
  }

  if (error is Exception) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return _orDefault(text.substring('Exception: '.length), defaultMessage);
    }
  }
  return defaultMessage;
}

/// The API error behind [error], from either shape the app throws.
///
/// `APIService.request` throws the [ApiException] itself; a data source that
/// calls Dio directly throws the [DioException] that [ErrorInterceptor]
/// packed it into. A [DioException] that never reached the interceptor is
/// read the same way the interceptor would have read it. Anything else is
/// not an API error, and gets null.
ApiException? apiExceptionOf(Object? error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return inner;
    return ApiException.fromDioException(error);
  }
  return null;
}

/// The backend's `error_code` for [error] (`ACCOUNT_SUSPENDED`,
/// `TOTP_REQUIRED`, `UPDATE_APP_TO_PAY`...), or null.
///
/// Branch on this rather than on the message: codes are stable, prose is not.
String? errorCodeOf(Object? error) => apiExceptionOf(error)?.errorCode;

/// The HTTP status [error] came back with, or null when there was no answer.
int? statusCodeOf(Object? error) => apiExceptionOf(error)?.statusCode;

String _orDefault(String text, String defaultMessage) =>
    text.trim().isEmpty ? defaultMessage : text.trim();
