import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/features/auth/presentation/pages/splash_screen.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A settled auth state, without the real notifier's secure-storage read.
class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// The app's start-up routes, reduced to labels.
GoRouter _router() => GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/', builder: (_, __) => const Text('HOME')),
        GoRoute(
          path: '/threads/:threadId',
          builder: (_, state) =>
              Text('THREAD ${state.pathParameters['threadId']}'),
        ),
        GoRoute(
          path: '/auth/onboarding',
          builder: (_, __) => const Text('SIGN IN'),
        ),
      ],
    );

Future<GoRouter> _start(WidgetTester tester, {required bool signedIn}) async {
  final router = _router();
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith((ref) => _FakeAuth(AuthState(
            accessToken: signedIn ? 'token' : null,
            isInitialized: true,
          ))),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  // The splash holds for 1.5s, then routes; the launch route follows a frame
  // later. Timed pumps, not pumpAndSettle, while the splash pulses forever.
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.pump();
  await tester.pump();
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(NotificationService.pendingLaunch.clear);
  tearDown(NotificationService.pendingLaunch.clear);

  testWidgets('signed in, a launch tap opens its page on top of home',
      (tester) async {
    NotificationService.pendingLaunch
        .hold(const {'type': 'club_thread', 'thread_id': 'abc'});

    final router = await _start(tester, signedIn: true);

    expect(find.text('THREAD abc'), findsOneWidget);
    // Consumed: nothing left to open on a later start-up.
    expect(NotificationService.pendingLaunch.take(), isNull);

    // Back returns home rather than leaving the app.
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('signed in with no launch tap, start-up is unchanged',
      (tester) async {
    final router = await _start(tester, signedIn: true);

    expect(find.text('HOME'), findsOneWidget);
    expect(router.canPop(), isFalse);
  });

  testWidgets('signed out, the launch tap is dropped, not kept for later',
      (tester) async {
    NotificationService.pendingLaunch
        .hold(const {'type': 'event_reminder', 'event_id': '12'});

    await _start(tester, signedIn: false);

    expect(find.text('SIGN IN'), findsOneWidget);
    // A kept route would open out of nowhere the next time the splash
    // runs.
    expect(NotificationService.pendingLaunch.take(), isNull);
  });
}
