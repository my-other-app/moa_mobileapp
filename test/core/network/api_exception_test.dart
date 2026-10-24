import 'package:dio/dio.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// What [ErrorInterceptor] makes of a response with [status] and [body].
ApiException _throughInterceptor(int status, Object? body) {
  final options = RequestOptions(path: '/x');
  ApiException? seen;
  ErrorInterceptor().onError(
    DioException(
      requestOptions: options,
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: status,
        data: body,
      ),
    ),
    _Capture((e) => seen = e),
  );
  return seen!;
}

void main() {
  group('the error envelope', () {
    test('a string message is the message, with code, errors and track id',
        () {
      final e = ApiException.fromResponse(400, {
        'message': 'Profile already exists',
        'errors': {'profile': 'exists'},
        'error_code': 'PROFILE_EXISTS',
        'track_id': 't-1',
      });

      expect(e.type, ApiExceptionType.badRequest);
      expect(e.message, 'Profile already exists');
      expect(e.serverMessage, 'Profile already exists');
      expect(e.errorCode, 'PROFILE_EXISTS');
      expect(e.errors, {'profile': 'exists'});
      expect(e.trackId, 't-1');
    });

    test('an older route\'s {"detail": "..."} is read', () {
      final e = ApiException.fromResponse(404, {'detail': 'Event not found'});

      expect(e.message, 'Event not found');
      expect(e.userMessage, 'Event not found');
    });

    test("FastAPI's validation list reads as its first message", () {
      final e = ApiException.fromResponse(422, {
        'detail': [
          {'loc': ['body', 'email'], 'msg': 'field required', 'type': 'x'},
        ],
      });

      expect(e.type, ApiExceptionType.badRequest);
      expect(e.message, 'Field required');
    });

    test('"Invalid request" gives way to the field error under it', () {
      // /user/register for an address already taken.
      final e = ApiException.fromResponse(400, {
        'message': 'Invalid Request',
        'errors': {'email': 'email already exists'},
      });

      expect(e.message, 'Email already exists');
      expect(e.fieldErrors, {'email': 'email already exists'});
    });

    group('a map in message', () {
      // Older responses put the field errors in `message` itself. Reading it
      // `as String?` threw inside the interceptor, so these never reached
      // the screen.
      const body = {
        'message': {'email': 'email already exists', 'password': 'too short'},
        'errors': null,
        'error_code': null,
      };

      test('does not throw, and keeps the fields', () {
        final e = ApiException.fromResponse(400, body);

        expect(e.fieldErrors, {
          'email': 'email already exists',
          'password': 'too short',
        });
        expect(e.message, 'Email already exists');
      });

      test('reaches the caller through the interceptor', () {
        final e = _throughInterceptor(400, body);

        expect(e.type, ApiExceptionType.badRequest);
        expect(e.userMessage, 'Email already exists');
        expect(e.fieldErrors!['password'], 'too short');
      });

      test('falls back to detail when message is not a string', () {
        final e = ApiException.fromResponse(400, {
          'message': {'email': ['is taken']},
          'detail': 'That address is already registered.',
        });

        expect(e.message, 'That address is already registered.');
        expect(e.fieldErrors, {
          'email': ['is taken'],
        });
      });

      test('a list of errors under a field reads as its first', () {
        final e = ApiException.fromResponse(400, {
          'message': {
            'email': ['is taken', 'is too long'],
          },
        });

        expect(e.message, 'Is taken');
      });
    });

    test("the rate limiter's {error: ...} is replaced with plain words", () {
      final e = ApiException.fromResponse(
          429, {'error': 'Rate limit exceeded: 20 per 1 minute'});

      expect(e.userMessage, 'Too many attempts. Please wait a minute and try again.');
    });

    test('a coded 429 keeps the server\'s words', () {
      final e = ApiException.fromResponse(429, {
        'message': 'Too many wrong passwords. Try again in 4 min.',
        'error_code': 'LOGIN_LOCKED',
      });

      expect(e.userMessage, 'Too many wrong passwords. Try again in 4 min.');
    });

    test('401, 403 and 404 keep the server\'s words', () {
      expect(
        ApiException.fromResponse(401, {'message': 'Incorrect username or password'})
            .userMessage,
        'Incorrect username or password',
      );
      expect(
        ApiException.fromResponse(403, {'message': 'Registrations are closed'})
            .userMessage,
        'Registrations are closed',
      );
      expect(
        ApiException.fromResponse(404, {'message': 'Club not found'}).userMessage,
        'Club not found',
      );
    });

    test('and fall back to plain copy when the server says nothing', () {
      expect(ApiException.fromResponse(401, null).userMessage,
          ApiException.sessionEndedMessage);
      expect(ApiException.fromResponse(403, '<html>').userMessage,
          "You don't have permission to do that.");
      expect(ApiException.fromResponse(404, {}).userMessage,
          "We couldn't find that. It may have been removed.");
    });
  });

  group('5xx', () {
    test("the catch-all's words are not shown", () {
      final e = ApiException.fromResponse(500, {
        'message': 'Internal Server Error',
        'errors': {'error': 'An error occurred while processing the request'},
        'track_id': 'abc',
      });

      expect(e.type, ApiExceptionType.server);
      expect(e.userMessage, ApiException.serverErrorMessage);
      expect(e.serverMessage, 'Internal Server Error');
      expect(e.trackId, 'abc');
    });

    test('nor an exception\'s own text', () {
      final e = ApiException.fromResponse(
          500, {'message': 'Failed to create order: KeyError(\'amount\')'});

      expect(e.userMessage, ApiException.serverErrorMessage);
    });

    test('a 502 page from the proxy is friendly copy', () {
      expect(ApiException.fromResponse(502, '<html>Bad gateway</html>').userMessage,
          ApiException.serverErrorMessage);
    });

    test('but a refusal raised on purpose, with a code, is said as is', () {
      final e = ApiException.fromResponse(503, {
        'message': "The club's payment gateway can't be reached right now.",
        'error_code': 'GATEWAY_UNAVAILABLE',
      });

      expect(e.userMessage,
          "The club's payment gateway can't be reached right now.");
    });
  });

  group('no response', () {
    DioException dio(DioExceptionType type, {Object? error}) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: type,
          error: error,
          message: 'The connection errored: Connection refused',
        );

    test('a timeout', () {
      final e = ApiException.fromDioException(dio(DioExceptionType.receiveTimeout));
      expect(e.type, ApiExceptionType.timeout);
      expect(e.userMessage, ApiException.timeoutMessage);
    });

    test('a transform timeout (Dio 5.10+) is a timeout too', () {
      final e =
          ApiException.fromDioException(dio(DioExceptionType.transformTimeout));
      expect(e.type, ApiExceptionType.timeout);
      expect(e.userMessage, ApiException.timeoutMessage);
    });

    test('no connection', () {
      final e =
          ApiException.fromDioException(dio(DioExceptionType.connectionError));
      expect(e.type, ApiExceptionType.network);
      expect(e.userMessage, ApiException.networkMessage);
    });

    test("Dio's own words never become the message", () {
      final e = ApiException.fromDioException(dio(DioExceptionType.unknown));
      expect(e.userMessage, isNot(contains('connection errored')));
    });
  });

  test('a code any screen can meet is worded for a person', () {
    final e = ApiException.fromResponse(403, {
      'message': 'This account has been suspended',
      'error_code': 'ACCOUNT_SUSPENDED',
    });

    expect(e.errorCode, 'ACCOUNT_SUSPENDED');
    expect(e.userMessage, ApiException.accountSuspendedMessage);
  });

  test('a session ended for a reused refresh token reads as an ended session',
      () {
    final e = ApiException.fromResponse(401, {
      'message': 'This session was ended because its sign-in was used from '
          'two places. Sign in again.',
      'error_code': 'SESSION_REUSED',
    });

    expect(e.errorCode, 'SESSION_REUSED');
    expect(e.userMessage, ApiException.sessionEndedMessage);
  });

  test('the user message never carries a class name or a status code', () {
    for (final status in [400, 401, 403, 404, 409, 422, 429, 500, 503]) {
      final message = ApiException.fromResponse(status, null).userMessage;
      expect(message, isNot(contains('ApiException')), reason: '$status');
      expect(message, isNot(contains('$status')), reason: '$status');
    }
  });
}

class _Capture extends ErrorInterceptorHandler {
  _Capture(this.onCaptured);

  final void Function(ApiException) onCaptured;

  @override
  void next(DioException err) {
    final e = err.error;
    if (e is ApiException) onCaptured(e);
  }
}
