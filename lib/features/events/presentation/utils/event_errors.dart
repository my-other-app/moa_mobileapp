import 'package:dio/dio.dart';
import 'package:finnet/core/network/api_exception.dart';

// Reading errors for the events and payments screens.
//
// `APIService.request` rethrows the interceptor's ApiException on its own, and
// `ApiException.toString()` is "ApiException: <message> (forbidden, code: 403)"
// -- which is what `extractErrorMessage` showed people, because it only knows
// DioException. These helpers read the ApiException (bare, or inside a
// DioException) and the server's envelope directly, so the screens here can
// branch on `error_code` and never print an exception's toString.

/// The ApiException behind [error], whichever way it arrived.
ApiException? apiExceptionOf(Object? error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return inner;
  }
  return null;
}

Map<dynamic, dynamic>? _body(Object? error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) return data;
  }
  return null;
}

/// The server's `error_code`, when it sent one.
String? errorCodeOf(Object? error) {
  final code = apiExceptionOf(error)?.errorCode;
  if (code != null && code.isNotEmpty) return code;
  final fromBody = _body(error)?['error_code'];
  return fromBody is String && fromBody.isNotEmpty ? fromBody : null;
}

/// The HTTP status, when there was a response.
int? statusOf(Object? error) {
  final api = apiExceptionOf(error);
  if (api?.statusCode != null) return api!.statusCode;
  if (error is DioException) return error.response?.statusCode;
  return null;
}

/// What the server said in its own words, when it said it as a sentence.
///
/// Field errors come back as a map under `message`; those are not a sentence
/// and are left to the caller.
String? serverMessageOf(Object? error) {
  final said = apiExceptionOf(error)?.serverMessage;
  if (said != null && said.trim().isNotEmpty) return said.trim();
  final body = _body(error);
  for (final key in const ['message', 'detail', 'error']) {
    final value = body?[key];
    if (value is String && value.trim().isNotEmpty) return value.trim();
  }
  return null;
}

/// A sentence a person can read for [error]; [fallback] when there is none.
///
/// The server's own words where it explained itself (except a 5xx, whose
/// words are for us, not for them), then the friendly copy for the kind of
/// failure, and never an exception's toString.
String readableError(Object? error, {required String fallback}) {
  final api = apiExceptionOf(error);
  final status = statusOf(error);
  final serverError = status != null && status >= 500;

  final said = serverMessageOf(error);
  if (said != null && !serverError) return said;

  if (api != null) {
    switch (api.type) {
      case ApiExceptionType.network:
      case ApiExceptionType.timeout:
      case ApiExceptionType.unauthorized:
      case ApiExceptionType.server:
      case ApiExceptionType.cancelled:
        return api.userMessage;
      default:
        return fallback;
    }
  }

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'The request timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'Please check your internet connection and try again.';
      default:
        break;
    }
    if (serverError) {
      return 'Something went wrong on our end. Please try again later.';
    }
  }
  return fallback;
}

/// `GET /events/{id}/networking` refuses with 403 NETWORKING_UNAVAILABLE when
/// the club's plan doesn't include it.
const networkingUnavailableCode = 'NETWORKING_UNAVAILABLE';

/// The copy for a networking page that can't load.
String networkingErrorMessage(Object? error) {
  if (errorCodeOf(error) == networkingUnavailableCode) {
    return "Networking isn't available for this event.";
  }
  return readableError(
    error,
    fallback:
        "We couldn't load the people at this event. Try again in a moment.",
  );
}
