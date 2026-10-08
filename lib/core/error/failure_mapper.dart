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
