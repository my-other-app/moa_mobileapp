import 'package:finnet/features/auth/data/services/password_reset_service.dart';
import 'package:finnet/features/auth/presentation/auth_routes.dart';
import 'package:finnet/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'auth_fakes.dart';
import 'password_reset_fakes.dart';

Future<void> _pump(
  WidgetTester tester, {
  required FakePasswordResetService service,
  required MemoryStorage storage,
  String email = '',
}) async {
  tester.view.physicalSize = const Size(440, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/auth/forgot-password',
    routes: [
      GoRoute(
        path: '/auth/forgot-password',
        builder: (context, state) => ForgotPasswordPage(
          initialEmail: email,
          service: service,
          storage: storage,
        ),
      ),
      GoRoute(
        path: '/auth/profile-check',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          return Scaffold(body: Text('Profile check ${extra['accessToken']}'));
        },
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.pump();
  await tester.enterText(field, text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
  await tester.pump();
}

/// The code boxes take their digits through one hidden field.
Future<void> _typeCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byKey(const ValueKey('code-input')), code);
  await tester.pump();
}

void main() {
  testWidgets('from the address to a new password, signed in at the end',
      (tester) async {
    final service = FakePasswordResetService();
    final storage = MemoryStorage();
    await _pump(tester,
        service: service, storage: storage, email: 'asha@example.com');

    // The address typed on the sign-in sheet is already there.
    expect(find.text('Forgot your password?'), findsOneWidget);
    expect(find.text('asha@example.com'), findsOneWidget);
    await _tap(tester, 'reset-send');

    expect(service.requested, ['asha@example.com']);
    expect(find.text('Reset your password'), findsOneWidget);
    // Never says whether the address has an account.
    expect(
        find.textContaining('has an account with a password'), findsOneWidget);
    expect(find.byKey(const ValueKey('reset-countdown')), findsOneWidget);

    await _typeCode(tester, '123456');
    await _type(tester, 'reset-new-password', 'hunter22');
    await _type(tester, 'reset-confirm-password', 'hunter22');
    await _tap(tester, 'reset-submit');
    await tester.pumpAndSettle();

    expect(service.resets.single['code'], '123456');
    expect(service.resets.single['new_password'], 'hunter22');
    // The session the reset opened is stored, and sign-in carries on.
    expect(storage.values['access_token'], 'access');
    expect(storage.values['refresh_token'], 'refresh');
    expect(find.text('Profile check access'), findsOneWidget);
  });

  testWidgets('passwords that do not match are caught before sending',
      (tester) async {
    final service = FakePasswordResetService();
    await _pump(tester,
        service: service, storage: MemoryStorage(), email: 'a@b.co');
    await _tap(tester, 'reset-send');

    await _typeCode(tester, '123456');
    await _type(tester, 'reset-new-password', 'hunter22');
    await _type(tester, 'reset-confirm-password', 'hunter23');
    await _tap(tester, 'reset-submit');

    expect(find.text("The two passwords don't match."), findsOneWidget);
    expect(service.resets, isEmpty);
  });

  testWidgets('a wrong code is said plainly and cleared for the next one',
      (tester) async {
    final service = FakePasswordResetService()
      ..nextReset = PasswordResetException.fromResponse(400, {
        'error_code': 'CODE_INVALID',
        'errors': {'attempts_left': 2},
      });
    final storage = MemoryStorage();
    await _pump(tester, service: service, storage: storage, email: 'a@b.co');
    await _tap(tester, 'reset-send');

    await _typeCode(tester, '000000');
    await _type(tester, 'reset-new-password', 'hunter22');
    await _type(tester, 'reset-confirm-password', 'hunter22');
    await _tap(tester, 'reset-submit');

    expect(find.byKey(const ValueKey('reset-error')), findsOneWidget);
    expect(find.textContaining('2 tries left'), findsOneWidget);
    expect(storage.values, isEmpty);
  });

  testWidgets('an account with two-step verification asks for its code',
      (tester) async {
    final service = FakePasswordResetService()
      ..nextReset = PasswordResetException.fromResponse(401, {
        'error_code': 'TOTP_REQUIRED',
        'message': 'Enter the code from your authenticator app as well.',
      });
    final storage = MemoryStorage();
    await _pump(tester, service: service, storage: storage, email: 'a@b.co');
    await _tap(tester, 'reset-send');
    expect(find.byKey(const ValueKey('reset-totp')), findsNothing);

    await _typeCode(tester, '123456');
    await _type(tester, 'reset-new-password', 'hunter22');
    await _type(tester, 'reset-confirm-password', 'hunter22');
    await _tap(tester, 'reset-submit');

    expect(find.byKey(const ValueKey('reset-totp')), findsOneWidget);
    expect(find.textContaining('two-step verification'), findsOneWidget);

    service.nextReset =
        const PasswordResetTokens(accessToken: 'a2', refreshToken: 'r2');
    await _type(tester, 'reset-totp', '654321');
    await _tap(tester, 'reset-submit');
    await tester.pumpAndSettle();

    expect(service.resets.last['totp_code'], '654321');
    expect(storage.values['access_token'], 'a2');
  });

  test('the route takes the address from the sign-in sheet', () {
    final route = authRoutes.whereType<GoRoute>().single;
    expect(route.path, '/auth/forgot-password');
  });
}
