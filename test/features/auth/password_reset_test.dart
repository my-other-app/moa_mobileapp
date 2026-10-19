import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/auth/data/services/password_reset_service.dart';
import 'package:finnet/features/auth/presentation/cubits/password_reset_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'password_reset_fakes.dart';

/// Answers each request with the next scripted (status, body).
class _ScriptedAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<(int, Object?)> answers = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = answers.removeAt(0);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

PasswordResetException _from(int status, Object? body) =>
    PasswordResetException.fromResponse(status, body);

void main() {
  group('the API contract', () {
    late _ScriptedAdapter adapter;
    late PasswordResetService service;

    setUp(() {
      adapter = _ScriptedAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ErrorInterceptor());
      service = PasswordResetService(dio: dio);
    });

    test('forgot: POST /auth/password/forgot with the address, no session',
        () async {
      adapter.answers.add((200, {'sent': true}));

      await service.requestCode('  asha@example.com ');

      final sent = adapter.requests.single;
      expect('${sent.method} ${sent.path}', 'POST /auth/password/forgot');
      expect(sent.data, {'email': 'asha@example.com'});
      expect(sent.extra['skipAuth'], isTrue);
      expect(sent.headers['Authorization'], isNull);
    });

    test('reset: POST /auth/password/reset, and the answer is a session',
        () async {
      adapter.answers.add((
        200,
        {
          'token_type': 'bearer',
          'access_token': 'new-access',
          'refresh_token': 'new-refresh',
        }
      ));

      final tokens = await service.reset(
        email: 'asha@example.com',
        code: '123456',
        newPassword: 'hunter22',
      );

      final sent = adapter.requests.single;
      expect('${sent.method} ${sent.path}', 'POST /auth/password/reset');
      // No totp_code at all for an account without two-step verification.
      expect(sent.data, {
        'email': 'asha@example.com',
        'code': '123456',
        'new_password': 'hunter22',
      });
      expect(sent.extra['skipAuth'], isTrue);
      expect(tokens.accessToken, 'new-access');
      expect(tokens.refreshToken, 'new-refresh');
    });

    test('reset sends the authenticator code when there is one', () async {
      adapter.answers.add((200, {'access_token': 'a', 'refresh_token': 'r'}));

      await service.reset(
        email: 'asha@example.com',
        code: '123456',
        newPassword: 'hunter22',
        totpCode: ' 654321 ',
      );

      expect((adapter.requests.single.data as Map)['totp_code'], '654321');
    });

    test('a wrong code arrives with the tries left', () async {
      adapter.answers.add((
        400,
        {
          'message': "That code isn't right. Check the email address and the "
              'code, or ask for a new one.',
          'error_code': 'CODE_INVALID',
          'errors': {'attempts_left': 3},
        }
      ));

      await expectLater(
        service.reset(email: 'a@b.co', code: '000000', newPassword: 'abcdef'),
        throwsA(isA<PasswordResetException>()
            .having((e) => e.kind, 'kind', PasswordResetErrorKind.wrongCode)
            .having((e) => e.attemptsLeft, 'attemptsLeft', 3)
            .having((e) => e.message, 'message', contains('3 tries left'))),
      );
    });

    test('a 200 without tokens is not a sign-in', () async {
      adapter.answers.add((200, {'token_type': 'bearer'}));

      await expectLater(
        service.reset(email: 'a@b.co', code: '123456', newPassword: 'abcdef'),
        throwsA(isA<PasswordResetException>()),
      );
    });
  });

  group("the server's refusals, in words", () {
    test('expired and locked codes need a new one', () {
      final expired = _from(400, {'error_code': 'CODE_EXPIRED'});
      expect(expired.kind, PasswordResetErrorKind.expired);
      expect(expired.needsNewCode, isTrue);

      final locked = _from(400, {
        'error_code': 'CODE_LOCKED',
        'errors': {'attempts_left': 0},
      });
      expect(locked.kind, PasswordResetErrorKind.tooManyAttempts);
      expect(locked.message, 'Too many wrong tries. Ask for a new code.');
      expect(locked.needsNewCode, isTrue);
    });

    test('two-step verification: needed, and wrong', () {
      final required = _from(401, {
        'message': 'Enter the code from your authenticator app as well.',
        'error_code': 'TOTP_REQUIRED',
      });
      expect(required.kind, PasswordResetErrorKind.totpRequired);
      expect(required.needsNewCode, isFalse);

      final wrong = _from(401, {
        'error_code': 'TOTP_INVALID',
        'errors': {'attempts_left': 2},
      });
      expect(wrong.kind, PasswordResetErrorKind.totpInvalid);
      expect(
          wrong.message, "That authenticator code isn't right. 2 tries left.");
    });

    test('a refused field, the limiter, the server, the network', () {
      expect(
          _from(422, {
            'detail': [
              {
                'loc': ['body', 'new_password'],
                'msg': 'too short'
              }
            ]
          }).kind,
          PasswordResetErrorKind.invalidInput);
      expect(
          _from(429, {'error': 'Rate limit exceeded: 5 per 1 minute'}).message,
          PasswordResetException.throttledMessage);
      expect(_from(500, {'message': 'Internal Server Error'}).message,
          PasswordResetException.serverMessage);
      expect(
        PasswordResetException.fromDio(DioException(
          requestOptions: RequestOptions(path: '/auth/password/forgot'),
          type: DioExceptionType.connectionError,
        )).kind,
        PasswordResetErrorKind.network,
      );
    });
  });

  group('the flow', () {
    late FakePasswordResetService service;
    late PasswordResetCubit cubit;

    setUp(() {
      service = FakePasswordResetService();
      cubit = PasswordResetCubit(service: service);
    });

    tearDown(() => cubit.dispose());

    Future<void> toCodeStep() => cubit.requestCode('asha@example.com');

    test('an address is needed before anything is sent', () async {
      await cubit.requestCode('not-an-address');

      expect(service.requested, isEmpty);
      expect(cubit.state.step, PasswordResetStep.email);
      expect(cubit.state.error, PasswordResetCopy.enterEmail);
    });

    test('asking for a code moves on, whatever the address', () async {
      await toCodeStep();

      expect(service.requested, ['asha@example.com']);
      expect(cubit.state.step, PasswordResetStep.code);
      expect(cubit.state.email, 'asha@example.com');
      // At most one code a minute: the resend waits.
      expect(cubit.state.resendIn, 60);
      expect(cubit.state.canResend, isFalse);
    });

    test('what is typed is checked before it is sent', () async {
      await toCodeStep();

      Future<String?> attempt(String code, String pw, String again) async {
        await cubit.reset(code: code, newPassword: pw, confirmPassword: again);
        return cubit.state.error;
      }

      expect(await attempt('123', 'abcdef', 'abcdef'),
          PasswordResetCopy.enterCode);
      expect(await attempt('123456', 'abc', 'abc'),
          PasswordResetCopy.shortPassword);
      expect(await attempt('123456', 'abcdef', 'abcdeg'),
          PasswordResetCopy.mismatch);
      expect(service.resets, isEmpty);
    });

    test('the right code signs in with the new password', () async {
      await toCodeStep();

      await cubit.reset(
          code: '123 456',
          newPassword: 'hunter22',
          confirmPassword: 'hunter22');

      expect(service.resets.single, {
        'email': 'asha@example.com',
        'code': '123456',
        'new_password': 'hunter22',
        'totp_code': null,
      });
      expect(cubit.state.step, PasswordResetStep.done);
      expect(cubit.state.tokens?.accessToken, 'access');
    });

    test('a wrong code says so and can be tried again', () async {
      await toCodeStep();
      service.nextReset = const PasswordResetException(
        PasswordResetErrorKind.wrongCode,
        "That code isn't right. 4 tries left.",
        attemptsLeft: 4,
      );

      await cubit.reset(
          code: '000000', newPassword: 'hunter22', confirmPassword: 'hunter22');

      expect(cubit.state.step, PasswordResetStep.code);
      expect(cubit.state.error, "That code isn't right. 4 tries left.");
      expect(cubit.state.codeUsable, isTrue);
    });

    test('a dead code needs a new one before anything else is sent', () async {
      await toCodeStep();
      service.nextReset = const PasswordResetException(
        PasswordResetErrorKind.tooManyAttempts,
        'Too many wrong tries. Ask for a new code.',
      );
      await cubit.reset(
          code: '000000', newPassword: 'hunter22', confirmPassword: 'hunter22');
      expect(cubit.state.codeUsable, isFalse);

      await cubit.reset(
          code: '123456', newPassword: 'hunter22', confirmPassword: 'hunter22');
      expect(service.resets, hasLength(1));
    });

    test('two-step verification: the authenticator code goes with it',
        () async {
      await toCodeStep();
      service.nextReset = const PasswordResetException(
        PasswordResetErrorKind.totpRequired,
        'This account uses two-step verification.',
      );
      await cubit.reset(
          code: '123456', newPassword: 'hunter22', confirmPassword: 'hunter22');
      expect(cubit.state.needsTotp, isTrue);

      // Without it, nothing is sent.
      await cubit.reset(
          code: '123456', newPassword: 'hunter22', confirmPassword: 'hunter22');
      expect(cubit.state.error, PasswordResetCopy.enterTotp);
      expect(service.resets, hasLength(1));

      service.nextReset =
          const PasswordResetTokens(accessToken: 'a', refreshToken: 'r');
      await cubit.reset(
          code: '123456',
          newPassword: 'hunter22',
          confirmPassword: 'hunter22',
          totpCode: '654321');
      expect(service.resets.last['totp_code'], '654321');
      expect(cubit.state.step, PasswordResetStep.done);
    });

    test('a throttled request says to wait, and the wait runs', () async {
      service.nextRequest = const PasswordResetException(
        PasswordResetErrorKind.throttled,
        PasswordResetException.throttledMessage,
      );

      await cubit.requestCode('asha@example.com');

      expect(cubit.state.step, PasswordResetStep.email);
      expect(cubit.state.error, PasswordResetException.throttledMessage);
      expect(cubit.state.resendIn, 60);
    });

    test('a different address goes back to the first step', () async {
      await toCodeStep();
      cubit.changeEmail();

      expect(cubit.state.step, PasswordResetStep.email);
      expect(cubit.state.email, 'asha@example.com');
      expect(cubit.state.resendIn, 0);
    });
  });
}
