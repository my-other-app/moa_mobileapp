import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/auth/data/services/authentication_service.dart';
import 'package:finnet/features/auth/presentation/sign_in_errors.dart';
import 'package:finnet/features/auth/presentation/widgets/two_step_sheet.dart';
import 'package:flutter/material.dart';
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

Future<void> _pumpSheet(
  WidgetTester tester, {
  required Future<String?> Function(String) onSubmit,
  String? initialError,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: TwoStepSheet(
        email: 'asha@example.com',
        onSubmit: onSubmit,
        initialError: initialError,
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('POST /auth/token', () {
    late _ScriptedAdapter adapter;
    late AuthenticationService service;

    setUp(() {
      adapter = _ScriptedAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ErrorInterceptor());
      service = AuthenticationService(api: APIService.over(dio));
    });

    test('without a code: the username and password form, as before', () async {
      adapter.answers.add((200, {'access_token': 'a', 'refresh_token': 'r'}));

      await service.signInWithEmail(email: 'a@b.co', password: 'p&w');

      final sent = adapter.requests.single;
      expect(sent.path, '/auth/token');
      expect(sent.contentType, 'application/x-www-form-urlencoded');
      expect(sent.data, 'username=a%40b.co&password=p%26w');
      expect(sent.extra['skipAuth'], isTrue);
    });

    test('with the code: totp_code goes in the same form', () async {
      adapter.answers.add((200, {'access_token': 'a', 'refresh_token': 'r'}));

      await service.signInWithEmail(
          email: 'a@b.co', password: 'pw', totpCode: ' 123456 ');

      expect(adapter.requests.single.data,
          'username=a%40b.co&password=pw&totp_code=123456');
    });

    test("TOTP_REQUIRED arrives with its code, for the cubit to ask", () async {
      adapter.answers.add((
        401,
        {
          'message': 'Enter the code from your authenticator app',
          'error_code': 'TOTP_REQUIRED',
        }
      ));

      await expectLater(
        service.signInWithEmail(email: 'a@b.co', password: 'pw'),
        throwsA(isA<ApiException>()
            .having((e) => e.errorCode, 'errorCode', 'TOTP_REQUIRED')),
      );
    });
  });

  group('the code sheet', () {
    testWidgets('six digits are tried as soon as they are in', (tester) async {
      final tried = <String>[];
      await _pumpSheet(tester, onSubmit: (code) async {
        tried.add(code);
        return null;
      });

      expect(find.textContaining('authenticator app for asha@example.com'),
          findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('code-input')), '123456');
      await tester.pump();

      expect(tried, ['123456']);
      expect(find.byKey(const ValueKey('two-step-error')), findsNothing);
    });

    testWidgets('a refused code is said, and cleared for the next',
        (tester) async {
      await _pumpSheet(tester,
          onSubmit: (code) async => twoStepWrongCodeMessage);

      await tester.enterText(
          find.byKey(const ValueKey('code-input')), '000000');
      await tester.pump();
      await tester.pump();

      expect(find.text(twoStepWrongCodeMessage), findsOneWidget);
      final input =
          tester.widget<TextField>(find.byKey(const ValueKey('code-input')));
      expect(input.controller!.text, isEmpty);
    });

    testWidgets('a recovery code can be used instead', (tester) async {
      final tried = <String>[];
      await _pumpSheet(tester, onSubmit: (code) async {
        tried.add(code);
        return null;
      });

      await tester.tap(find.byKey(const ValueKey('two-step-switch')));
      await tester.pump();
      expect(find.textContaining('recovery codes you saved'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('two-step-recovery')),
          'ab12-cd34-ef56-7890');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('two-step-submit')));
      await tester.pump();

      expect(tried, ['ab12-cd34-ef56-7890']);
    });

    testWidgets('why the last code was refused shows on opening',
        (tester) async {
      await _pumpSheet(tester,
          onSubmit: (_) async => null, initialError: twoStepWrongCodeMessage);

      expect(find.text(twoStepWrongCodeMessage), findsOneWidget);
    });
  });
}
