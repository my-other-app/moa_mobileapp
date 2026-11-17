import 'package:finnet/features/auth/presentation/pages/splash_screen.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// An auth state set by hand, without the real notifier's storage read.
class _Auth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _Auth(super.state);

  void read({required bool signedIn}) => state = AuthState(
        accessToken: signedIn ? 'token' : null,
        isInitialized: true,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

Future<_Auth> _start(WidgetTester tester, AuthState state) async {
  final auth = _Auth(state);
  final router = GoRouter(initialLocation: '/splash', routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/', builder: (_, __) => const Text('HOME')),
    GoRoute(path: '/auth/onboarding', builder: (_, __) => const Text('SIGN IN')),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [authStateProvider.overrideWith((ref) => auth)],
    child: MaterialApp.router(routerConfig: router),
  ));
  return auth;
}

/// Frames worth [ms] milliseconds, without settling: the splash pulses
/// forever.
Future<void> _wait(WidgetTester tester, int ms) async {
  for (var i = 0; i < ms ~/ 50; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  testWidgets('the session already read: home at once, no fixed wait',
      (tester) async {
    await _start(
        tester, const AuthState(accessToken: 'token', isInitialized: true));

    // Routed within a frame or two, nowhere near the 1.5 s it used to
    // hold for.
    await _wait(tester, 100);
    expect(find.text('HOME'), findsOneWidget);
    // And the page transition over well before then.
    await _wait(tester, 500);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('signed out: sign-in at once', (tester) async {
    await _start(tester, const AuthState(isInitialized: true));
    await _wait(tester, 100);

    expect(find.text('SIGN IN'), findsOneWidget);
  });

  testWidgets(
      'a slow keychain: the splash waits for it, and never sends a signed-in '
      'person to sign-in in the meantime', (tester) async {
    final auth = await _start(tester, const AuthState());

    await _wait(tester, 12000);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('SIGN IN'), findsNothing);

    auth.read(signedIn: true);
    await _wait(tester, 100);
    expect(find.text('HOME'), findsOneWidget);
  });
}
