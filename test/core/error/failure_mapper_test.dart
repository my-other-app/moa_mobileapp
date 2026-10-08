import 'package:dio/dio.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// What `ErrorInterceptor` hands to the next error handler: an [ApiException]
/// boxed inside a fresh [DioException], because that is the only type
/// `handler.next` accepts. Anything calling `dio.get` directly sees this, not
/// the [ApiException].
DioException _asThrownByDio(ApiException e) {
  return DioException(
    requestOptions: RequestOptions(path: '/whatever'),
    type: DioExceptionType.badResponse,
    error: e,
  );
}

void main() {
  group('mapErrorToFailure', () {
    test('unwraps an ApiException boxed in a DioException', () {
      // The bug this exists for: every repository caught `on ApiException`
      // after a raw-Dio data source call, so this object fell through to the
      // bare `catch` and became an UnknownFailure. An expired session was
      // indistinguishable from a parse bug, so nothing prompted a re-login.
      final failure = mapErrorToFailure(_asThrownByDio(const ApiException(
        message: 'Unauthorized. Please log in again.',
        statusCode: 401,
        type: ApiExceptionType.unauthorized,
      )));

      expect(failure, isA<AuthFailure>());
      expect(failure.message, 'Unauthorized. Please log in again.');
    });

    test('also accepts a bare ApiException', () {
      // APIService.request unwraps before rethrowing, so both shapes reach
      // the same mapper.
      final failure = mapErrorToFailure(const ApiException(
        message: 'Bad input',
        type: ApiExceptionType.badRequest,
      ));

      expect(failure, isA<ValidationFailure>());
    });

    test('classifies a DioException that never reached the interceptor', () {
      // AuthInterceptor can emit one of these when a token-refresh retry
      // throws something that is not a DioException.
      final failure = mapErrorToFailure(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
        message: 'No route to host',
      ));

      expect(failure, isA<NetworkFailure>());
      expect(failure.message, 'No route to host');
    });

    test('a cancellation is not a network failure', () {
      // A cancelled request must not offer a retry button the way a dropped
      // connection does.
      final failure = mapErrorToFailure(DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.cancel,
      ));

      expect(failure, isA<UnknownFailure>());
    });

    test('falls back to UnknownFailure for anything else', () {
      expect(mapErrorToFailure(StateError('nope')), isA<UnknownFailure>());
    });
  });

  group('ErrorInterceptor keeps the server message', () {
    test('a 401 keeps the reason the server gave', () {
      // The check-in endpoint answers 401 with "User is not a volunteer for
      // this event". The friendly copy in `message` would tell a door
      // volunteer to log in again, which is the wrong instruction, so the
      // real reason has to survive somewhere.
      final interceptor = ErrorInterceptor();
      final requestOptions = RequestOptions(path: '/events/volunteer/checkin/1');
      ApiException? seen;
      interceptor.onError(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: 401,
            data: const {
              'message': 'User is not a volunteer for this event',
              'error_code': null,
            },
          ),
        ),
        _CapturingHandler((e) => seen = e),
      );

      expect(seen, isNotNull);
      expect(seen!.type, ApiExceptionType.unauthorized);
      expect(seen!.message, 'Unauthorized. Please log in again.');
      expect(seen!.serverMessage, 'User is not a volunteer for this event');
    });

    test('a 400 carries error_code through when the server sets one', () {
      final requestOptions = RequestOptions(path: '/x');
      ApiException? seen;
      ErrorInterceptor().onError(
        DioException(
          requestOptions: requestOptions,
          type: DioExceptionType.badResponse,
          response: Response<dynamic>(
            requestOptions: requestOptions,
            statusCode: 400,
            data: const {'message': 'Nope', 'error_code': 'TICKET_USED'},
          ),
        ),
        _CapturingHandler((e) => seen = e),
      );

      expect(seen!.errorCode, 'TICKET_USED');
      expect(seen!.serverMessage, 'Nope');
    });
  });
}

/// Captures the [ApiException] the interceptor boxes into its outgoing
/// [DioException], without running a real Dio error chain.
class _CapturingHandler extends ErrorInterceptorHandler {
  _CapturingHandler(this.onCaptured);

  final void Function(ApiException) onCaptured;

  @override
  void next(DioException err) {
    final e = err.error;
    if (e is ApiException) onCaptured(e);
  }
}
