import 'package:dio/dio.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/utils/error_utils.dart';

export 'package:finnet/core/utils/error_utils.dart'
    show apiExceptionOf, errorCodeOf, statusCodeOf;

// Reading errors for the events and payments screens.
//
// The ApiException behind an error, its `error_code` and its status come
// from core (`apiExceptionOf`, `errorCodeOf`, `statusCodeOf` in
// core/utils/error_utils.dart), re-exported here so the screens that import
// this file keep one import. What is left here is the events screens' own
// reading: the server's words where it explained itself, and the copy for a
// page that can't load.

Map<dynamic, dynamic>? _body(Object? error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) return data;
  }
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
  final status = statusCodeOf(error);
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
