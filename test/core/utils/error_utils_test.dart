import 'package:dio/dio.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

DioException _boxed(ApiException e) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.badResponse,
      error: e,
    );

DioException _raw(int status, Object? body) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
    ),
  );
}

void main() {
  group('extractErrorMessage', () {
    test('an ApiException reads as the server\'s words, not its toString()',
        () {
      // What APIService.request throws. It used to fall through to
      // toString(): "ApiException: Invalid email (badRequest, code: 400)".
      final e = ApiException.fromResponse(400, {'message': 'Invalid email'});

      final message = extractErrorMessage(e);

      expect(message, 'Invalid email');
      expect(message, isNot(contains('ApiException')));
      expect(message, isNot(contains('400')));
    });

    test('so does the DioException a direct Dio call throws', () {
      final e = _boxed(ApiException.fromResponse(409, {'message': 'Already registered'}));

      expect(extractErrorMessage(e), 'Already registered');
    });

    test('and one that never reached the interceptor', () {
      expect(extractErrorMessage(_raw(400, {'detail': 'Bad date'})), 'Bad date');
    });

    test('a 5xx, a timeout and no connection are friendly copy', () {
      expect(extractErrorMessage(_raw(500, {'message': 'Internal Server Error'})),
          ApiException.serverErrorMessage);
      expect(
        extractErrorMessage(DioException(
          requestOptions: RequestOptions(path: '/x'),
          type: DioExceptionType.connectionTimeout,
        )),
        ApiException.timeoutMessage,
      );
      expect(
        extractErrorMessage(const ApiException(
          message: 'SocketException: Failed host lookup',
          type: ApiExceptionType.network,
        )),
        ApiException.networkMessage,
      );
    });

    test("the caller's default beats the generic last resort", () {
      expect(
        extractErrorMessage(_raw(400, null), defaultMessage: 'Could not save.'),
        'Could not save.',
      );
    });

    test("Exception('Words') reads as the words", () {
      expect(extractErrorMessage(Exception('Sign in was cancelled')),
          'Sign in was cancelled');
    });

    test('anything else reads as the default, never its toString()', () {
      expect(extractErrorMessage(TypeError(), defaultMessage: 'Oops'), 'Oops');
      expect(
        extractErrorMessage(
          PlatformException(code: 'sign_in_failed', message: 'ApiException: 10'),
          defaultMessage: 'Could not sign in with Google.',
        ),
        'Could not sign in with Google.',
      );
      expect(extractErrorMessage(null, defaultMessage: 'Oops'), 'Oops');
    });

    test('a Failure reads as its message, a String as itself', () {
      expect(extractErrorMessage(const NetworkFailure(message: 'Offline')),
          'Offline');
      expect(extractErrorMessage('Plain words'), 'Plain words');
    });
  });

  group('errorCodeOf', () {
    test('reads the code from either shape', () {
      final api = ApiException.fromResponse(
          401, {'message': 'Enter the code', 'error_code': 'TOTP_REQUIRED'});

      expect(errorCodeOf(api), 'TOTP_REQUIRED');
      expect(errorCodeOf(_boxed(api)), 'TOTP_REQUIRED');
      expect(errorCodeOf(_raw(403, {'error_code': 'ACCOUNT_SUSPENDED'})),
          'ACCOUNT_SUSPENDED');
    });

    test('is null for anything that is not an API error', () {
      expect(errorCodeOf(Exception('x')), isNull);
      expect(errorCodeOf(_raw(400, {'message': 'x'})), isNull);
    });
  });

  test('statusCodeOf', () {
    expect(statusCodeOf(_raw(404, null)), 404);
    expect(statusCodeOf(StateError('x')), isNull);
  });
}
