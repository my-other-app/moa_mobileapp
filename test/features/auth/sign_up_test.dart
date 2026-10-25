import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart' show RouteAdapter, useFakeApi;
import 'sign_in_page_harness.dart';

Finder _field(String label) => find.widgetWithText(TextFormField, label);

/// LOGIN WITH EMAIL, then "Create one": the sheet for a new account.
Future<void> _openSignUp(WidgetTester tester) async {
  await tester.tap(find.text('LOGIN WITH EMAIL'));
  await tester.pumpAndSettle();
  await tester.tap(find.text("Don't have an account? Create one"));
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester,
    {String name = '', String email = '', String password = ''}) async {
  await tester.enterText(_field('Full Name'), name);
  await tester.enterText(_field('Email'), email);
  await tester.enterText(_field('Password'), password);
}

Future<void> _create(WidgetTester tester) async {
  await tester.tap(find.text('CREATE ACCOUNT'));
  await tester.pumpAndSettle();
}

void main() {
  late RouteAdapter api;

  setUp(() {
    api = useFakeApi();
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('"Create one" turns the sheet into a new account, with a name',
      (tester) async {
    await pumpSignIn(tester);
    await tester.tap(find.text('LOGIN WITH EMAIL'));
    await tester.pumpAndSettle();

    expect(find.text('Sign In with Email'), findsOneWidget);
    expect(_field('Full Name'), findsNothing);
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.text("Don't have an account? Create one"));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(_field('Full Name'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    // A new account has no password to forget.
    expect(find.text('Forgot password?'), findsNothing);
    // The terms are agreed to here too.
    expect(find.byKey(const ValueKey('terms-consent')), findsNWidgets(2));

    // And back.
    await tester.tap(find.text('Already have an account? Sign In'));
    await tester.pumpAndSettle();
    expect(_field('Full Name'), findsNothing);
    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets(
      'a new account is registered, its tokens kept, and the address goes on '
      'to be verified', (tester) async {
    api.on('POST', '/user/register', {
      'access_token': 'access-new',
      'refresh_token': 'refresh-new',
      'token_type': 'Bearer',
    });
    final landed = await pumpSignIn(tester);
    await _openSignUp(tester);

    await _fill(tester,
        name: '  Asha Menon ',
        email: ' asha@example.com ',
        password: 'secret1');
    await _create(tester);

    final sent = api.sent('POST', '/user/register').single;
    // Trimmed, but the password exactly as typed.
    expect(sent.data, {
      'full_name': 'Asha Menon',
      'email': 'asha@example.com',
      'password': 'secret1',
    });
    expect(sent.extra['skipAuth'], isTrue);
    expect(await SecureStorageService().getAccessToken(), 'access-new');
    expect(await SecureStorageService().getRefreshToken(), 'refresh-new');
    // Not the profile check: first the code sent to the address, then the
    // onboarding.
    expect(landed.single.page, 'verify-email');
    expect(landed.single.extra, {
      'email': 'asha@example.com',
      'onboarding': true,
      'accessToken': 'access-new',
      'profileUrl': '',
    });
  });

  testWidgets('an empty form says what is missing, and sends nothing',
      (tester) async {
    await pumpSignIn(tester);
    await _openSignUp(tester);

    await _create(tester);

    expect(find.text('Please enter your name'), findsOneWidget);
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    expect(api.requests, isEmpty);
    // Still open, to be finished.
    expect(find.text('Create Account'), findsOneWidget);
  });

  testWidgets(
      'a mistyped address and a short password are caught before anything '
      'is sent', (tester) async {
    await pumpSignIn(tester);
    await _openSignUp(tester);

    await _fill(tester,
        name: 'Asha Menon', email: 'asha.example.com', password: '12345');
    await _create(tester);

    expect(find.text('Please enter a valid email'), findsOneWidget);
    // The server's own rule, held here too.
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets(
      'an address that already has an account says so, keeps nothing and '
      'stays on sign-in', (tester) async {
    // What /user/register answers for an address in use.
    api.on(
        'POST',
        '/user/register',
        {
          'message': 'Invalid Request',
          'errors': {'email': 'email already exists'},
        },
        status: 400);
    final landed = await pumpSignIn(tester);
    await _openSignUp(tester);

    await _fill(tester,
        name: 'Asha Menon', email: 'asha@example.com', password: 'secret1');
    await _create(tester);

    expect(find.textContaining('already exists'), findsOneWidget);
    expect(find.textContaining('Invalid Request'), findsNothing);
    expect(find.textContaining('ApiException'), findsNothing);
    expect(await SecureStorageService().getAccessToken(), isNull);
    expect(landed, isEmpty);
    expect(find.text('LOGIN WITH EMAIL'), findsOneWidget);
  });
}
