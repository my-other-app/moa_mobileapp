import 'package:finnet/features/auth/data/services/change_password_service.dart';
import 'package:finnet/features/auth/presentation/cubits/password_reset_cubit.dart'
    show PasswordResetCopy;
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/presentation/pages/settings/change_password_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';

/// The session as the page leaves it: renewed with new tokens, or ended.
class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth()
      : super(const AuthState(accessToken: 'old', isInitialized: true));

  final renewed = <(String, String)>[];
  int logouts = 0;

  @override
  Future<void> renewSession(
      {required String accessToken, required String refreshToken}) async {
    renewed.add((accessToken, refreshToken));
    state = state.copyWith(
        accessToken: accessToken, refreshToken: refreshToken);
  }

  @override
  Future<void> logout() async {
    logouts++;
    state = const AuthState(isInitialized: true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

const _tokens = {
  'access_token': 'new-access',
  'refresh_token': 'new-refresh',
  'token_type': 'Bearer',
};

void main() {
  late RouteAdapter api;
  late _FakeAuth auth;
  late List<Object?> closedWith;

  setUp(() {
    api = useFakeApi();
    auth = _FakeAuth();
    closedWith = [];
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => auth),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => closedWith.add(await Navigator.of(context)
                  .push<bool>(MaterialPageRoute(
                      builder: (_) => const ChangePasswordPage()))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester,
      {String current = 'old-secret',
      String next = 'new-secret',
      String? again}) async {
    await tester.enterText(find.byKey(ChangePasswordPage.currentKey), current);
    await tester.enterText(find.byKey(ChangePasswordPage.newKey), next);
    await tester.enterText(
        find.byKey(ChangePasswordPage.confirmKey), again ?? next);
    await tester.tap(find.byKey(ChangePasswordPage.saveKey));
    await tester.pumpAndSettle();
  }

  group('checked before anything is sent, as sign-up checks', () {
    testWidgets('the current password is needed', (tester) async {
      await pump(tester);
      await fill(tester, current: '');
      expect(find.text('Enter your current password.'), findsOneWidget);
      expect(api.sent('POST', '/auth/change-password'), isEmpty);
    });

    testWidgets('at least 6 characters', (tester) async {
      await pump(tester);
      await fill(tester, next: 'abc12');
      expect(find.text(PasswordResetCopy.shortPassword), findsOneWidget);
      expect(api.sent('POST', '/auth/change-password'), isEmpty);
    });

    testWidgets('typed the same twice', (tester) async {
      await pump(tester);
      await fill(tester, next: 'new-secret', again: 'new-secreT');
      expect(find.text(PasswordResetCopy.mismatch), findsOneWidget);
      expect(api.sent('POST', '/auth/change-password'), isEmpty);
    });

    testWidgets('not the one they have now', (tester) async {
      await pump(tester);
      await fill(tester, current: 'same-secret', next: 'same-secret');
      expect(find.text(ChangePasswordPage.sameAsCurrent), findsOneWidget);
      expect(api.sent('POST', '/auth/change-password'), isEmpty);
    });
  });

  testWidgets(
      'changed: the server is told, this phone signs in again with the new '
      'password, and the page closes', (tester) async {
    api
      ..on('POST', '/auth/change-password',
          {'success': true, 'message': 'Password changed successfully'})
      ..on('POST', '/auth/token', _tokens);
    await pump(tester);

    await fill(tester);

    expect(api.sent('POST', '/auth/change-password').single.data,
        {'old_password': 'old-secret', 'new_password': 'new-secret'});
    final signIn = api.sent('POST', '/auth/token').single;
    expect(signIn.data,
        'username=${Uri.encodeComponent(testProfile.email)}&password=new-secret');
    expect(signIn.extra['skipAuth'], isTrue);
    expect(auth.renewed, [('new-access', 'new-refresh')]);
    expect(auth.logouts, 0);
    expect(closedWith, [true]);
    expect(find.text(ChangePasswordPage.changed), findsOneWidget);
  });

  testWidgets('a wrong current password is said under it, and kept off',
      (tester) async {
    api.on('POST', '/auth/change-password',
        {'message': 'Incorrect old password'},
        status: 400);
    await pump(tester);

    await fill(tester);

    expect(find.text(ChangePasswordException.wrongCurrentMessage),
        findsOneWidget);
    expect(api.sent('POST', '/auth/token'), isEmpty);
    expect(auth.renewed, isEmpty);
    expect(closedWith, isEmpty);

    // Typing again clears it.
    await tester.enterText(find.byKey(ChangePasswordPage.currentKey), 'x');
    await tester.pump();
    expect(find.text(ChangePasswordException.wrongCurrentMessage),
        findsNothing);
  });

  testWidgets("a locked account says the server's wait", (tester) async {
    api.on(
        'POST',
        '/auth/change-password',
        {
          'message': 'Too many wrong passwords. Try again in 14 min.',
          'error_code': 'LOGIN_LOCKED',
        },
        status: 429);
    await pump(tester);

    await fill(tester);

    expect(find.text('Too many wrong passwords. Try again in 14 min.'),
        findsOneWidget);
  });

  testWidgets(
      'with two-step verification it cannot sign in again by itself: it '
      'says so and ends the session', (tester) async {
    api
      ..on('POST', '/auth/change-password', {'success': true, 'message': 'ok'})
      ..on('POST', '/auth/token',
          {'message': 'Enter your code', 'error_code': 'TOTP_REQUIRED'},
          status: 401);
    await pump(tester);

    await fill(tester);

    expect(auth.renewed, isEmpty);
    expect(auth.logouts, 1);
    expect(find.text(ChangePasswordPage.signInAgain), findsOneWidget);
  });

  group('the profile says which accounts have a password', () {
    test('provider email', () {
      final model = UserProfileModel.fromJson(
          {'id': 1, 'email': 'a@b.c', 'provider': 'email'});
      expect(model.toEntity().hasPassword, isTrue);
      expect(model.toJson()['provider'], 'email');
    });

    test('Google, Apple, or a server that does not say', () {
      for (final provider in ['google', 'apple', null]) {
        expect(
            UserProfileModel.fromJson(
                {'id': 1, 'email': 'a@b.c', 'provider': provider})
                .toEntity()
                .hasPassword,
            isFalse,
            reason: '$provider');
      }
    });
  });
}
