import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/auth/data/services/email_verification_service.dart';
import 'package:flutter_test/flutter_test.dart';

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

EmailVerificationException _from(int status, Object? body) =>
    EmailVerificationException.fromResponse(status, body);

void main() {
  group('the server\'s refusals become what the screen says', () {
    test('a wrong code carries the tries left', () {
      final e = _from(400, {
        'message': "That code isn't right. 3 tries left.",
        'error_code': 'CODE_INVALID',
        'errors': {'attempts_left': 3},
      });
      expect(e.kind, EmailVerificationErrorKind.wrongCode);
      expect(e.attemptsLeft, 3);
      expect(e.message, "That code isn't right. 3 tries left.");
    });

    test('expired, and dead after five wrong tries', () {
      expect(_from(400, {'error_code': 'CODE_EXPIRED'}).kind,
          EmailVerificationErrorKind.expired);
      final locked = _from(400, {
        'error_code': 'CODE_LOCKED',
        'errors': {'attempts_left': 0},
      });
      expect(locked.kind, EmailVerificationErrorKind.tooManyAttempts);
      expect(locked.attemptsLeft, 0);
      expect(locked.message, 'Too many wrong tries. Ask for a new code.');
    });

    test('too soon or too often: retry_after is how long to wait', () {
      for (final code in ['CODE_RECENTLY_SENT', 'CODE_DAILY_LIMIT']) {
        final e = _from(429, {
          'message': 'We just sent you a code.',
          'error_code': code,
          'errors': {'retry_after': 42},
        });
        expect(e.kind, EmailVerificationErrorKind.throttled);
        expect(e.retryAfter, 42);
      }
      // The per-address limiter answers in its own shape.
      final limiter = _from(429, {'error': 'Rate limit exceeded: 5 per 1 minute'});
      expect(limiter.kind, EmailVerificationErrorKind.throttled);
      expect(limiter.retryAfter, 60);
    });

    test('already verified, a lapsed session, and anything else', () {
      expect(_from(409, {'error_code': 'ALREADY_VERIFIED'}).kind,
          EmailVerificationErrorKind.alreadyVerified);
      expect(_from(401, {'message': 'Could not validate credentials'}).kind,
          EmailVerificationErrorKind.sessionExpired);
      final other = _from(500, {'message': 'Internal Server Error'});
      expect(other.kind, EmailVerificationErrorKind.unknown);
      expect(_from(502, 'Bad gateway').message,
          'Something went wrong. Please try again.');
    });
  });

  group('calls', () {
    late _ScriptedAdapter adapter;
    late EmailVerificationService service;

    setUp(() {
      adapter = _ScriptedAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ErrorInterceptor());
      service = EmailVerificationService(dio: dio);
    });

    test('send-code and verify hit the endpoints and read their answers',
        () async {
      adapter.answers
        ..add((
          200,
          {'sent': true, 'email': 'a@b.co', 'expires_in': 900, 'retry_after': 60}
        ))
        ..add((
          200,
          {
            'email_verified': true,
            'email_verified_at': '2026-10-17T10:00:00+05:30',
            'merged': true,
            'registrations_transferred': 2,
          }
        ));

      final sent = await service.sendCode();
      final verified = await service.verify('123456');

      expect(adapter.requests.map((r) => '${r.method} ${r.path}'), [
        'POST /auth/email/send-code',
        'POST /auth/email/verify',
      ]);
      expect(adapter.requests.last.data, {'code': '123456'});
      expect((sent.email, sent.expiresIn, sent.retryAfter), ('a@b.co', 900, 60));
      expect(verified.merged, isTrue);
      expect(verified.registrationsTransferred, 2);
    });

    test('a refusal arrives as an EmailVerificationException', () async {
      adapter.answers.add((
        400,
        {
          'message': "That code isn't right. 4 tries left.",
          'error_code': 'CODE_INVALID',
          'errors': {'attempts_left': 4},
        }
      ));

      await expectLater(
        service.verify('000000'),
        throwsA(isA<EmailVerificationException>()
            .having((e) => e.kind, 'kind', EmailVerificationErrorKind.wrongCode)
            .having((e) => e.attemptsLeft, 'attemptsLeft', 4)),
      );
    });

    test('a lapsed session is renewed through the profile and tried again',
        () async {
      adapter.answers
        ..add((401, {'message': 'Token has expired'}))
        ..add((200, {'id': 1, 'email': 'a@b.co'}))
        ..add((
          200,
          {'sent': true, 'email': 'a@b.co', 'expires_in': 900, 'retry_after': 60}
        ));

      final sent = await service.sendCode();

      expect(adapter.requests.map((r) => r.path), [
        '/auth/email/send-code',
        '/user/profile/me',
        '/auth/email/send-code',
      ]);
      expect(sent.email, 'a@b.co');
    });
  });
}
