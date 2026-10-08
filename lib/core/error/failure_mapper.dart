import 'package:dio/dio.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';

/// Turn a transport-level [ApiException] into a domain [Failure].
///
/// This lived as a private `_mapApiExceptionToFailure` copied into four
/// repository implementations. Four copies of a switch over the same enum is
/// four chances for them to disagree -- and they already did in small ways,
/// which is invisible until a screen reports the wrong kind of error and
/// someone chases a network problem that was really a validation one.
///
/// Adding a case to [ApiExceptionType] now fails to compile here, once,
/// instead of silently falling through in whichever copies were missed.
Failure mapApiExceptionToFailure(ApiException e) {
  switch (e.type) {
    case ApiExceptionType.network:
    case ApiExceptionType.timeout:
      return NetworkFailure(message: e.message);
    case ApiExceptionType.unauthorized:
    case ApiExceptionType.forbidden:
      return AuthFailure(message: e.message);
    case ApiExceptionType.badRequest:
      return ValidationFailure(message: e.message);
    case ApiExceptionType.notFound:
      // The code is carried so a caller can tell "no such thing" from a
      // server that simply fell over.
      return ServerFailure(message: e.message, code: '404');
    case ApiExceptionType.server:
      return ServerFailure(message: e.message);
    case ApiExceptionType.cancelled:
    case ApiExceptionType.unknown:
      return UnknownFailure(message: e.message);
  }
}

/// Turn anything a data source can throw into a [Failure].
///
/// Prefer this over calling [mapApiExceptionToFailure] from a `on ApiException`
/// clause. Only [APIService.request] unwraps the exception: [ErrorInterceptor]
/// builds an [ApiException] and then hands it to `handler.next` inside a *new*
/// [DioException], because that is the only thing an error handler may pass
/// along. So a data source that calls `dio.get` directly -- which is all of
/// them -- throws a [DioException] carrying the [ApiException] in `.error`,
/// and a `on ApiException` clause above it never runs.
///
/// That was live in every repository: each one caught [ApiException] after a
/// raw-Dio data source call, so every real error fell through to the bare
/// `catch` and became an [UnknownFailure]. An expired session looked the same
/// as a parse bug, which is why nothing ever prompted a re-login.
Failure mapErrorToFailure(Object error) {
  if (error is ApiException) return mapApiExceptionToFailure(error);

  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return mapApiExceptionToFailure(inner);

    // A DioException that never reached ErrorInterceptor -- a cancellation,
    // or one built by AuthInterceptor when a retry threw. Classify from the
    // transport type rather than reporting it as unknown.
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return NetworkFailure(message: error.message ?? 'Connection failed');
      case DioExceptionType.badCertificate:
        return NetworkFailure(
          message: error.message ?? 'Certificate could not be verified',
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return UnknownFailure(message: error.message ?? error.toString());
    }
  }

  return UnknownFailure(message: error.toString());
}
