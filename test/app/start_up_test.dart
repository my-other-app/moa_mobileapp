import 'dart:async';

import 'package:finnet/app/start_up.dart';
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

/// The app's first screens: the splash, then sign-in.
Widget _app() => ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
            (ref) => _FakeAuth(const AuthState(isInitialized: true))),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(initialLocation: '/splash', routes: [
          GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
          GoRoute(
              path: '/auth/onboarding',
              builder: (_, __) => const Text('SIGN IN')),
        ]),
      ),
    );

/// What [body] logs with debugPrint. The binding checks that debugPrint is
/// put back before the test ends, so it is put back here, not in tearDown.
Future<List<String>> _logged(Future<void> Function() body) async {
  final printed = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) => printed.add('$message');
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return printed;
}

void main() {
  testWidgets(
      'the app is handed over to be drawn first, and push set-up only starts '
      'after -- on iOS it used to hold everything for up to ten seconds',
      (tester) async {
    final pushDone = Completer<void>();
    final order = <String>[];
    final drawn = <Widget>[];

    runAppThenStartPush(
      _app(),
      pushSetUp: () {
        order.add('push set-up started');
        return pushDone.future;
      },
      run: (app) {
        order.add('app drawn');
        drawn.add(app);
      },
    );
    // It returned at once, without waiting for push set-up.
    expect(order, ['app drawn', 'push set-up started']);
    expect(pushDone.isCompleted, isFalse);

    // The first screen, and on to sign-in, while push set-up still has not
    // answered.
    await tester.pumpWidget(drawn.single);
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('My Other App'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(pushDone.isCompleted, isFalse);

    pushDone.complete();
  });

  testWidgets('a push set-up that fails is logged; nothing is thrown',
      (tester) async {
    final printed = await _logged(() async {
      runAppThenStartPush(
        const Text('the app'),
        pushSetUp: () async => throw StateError('no APNs token'),
        run: (_) {},
      );
      await tester.pump();
    });

    expect(printed,
        contains('NotificationService initialization error: '
            'Bad state: no APNs token'));
  });

  testWidgets('one that throws before it starts is caught the same way',
      (tester) async {
    final printed = await _logged(() async {
      runAppThenStartPush(
        const Text('the app'),
        pushSetUp: () => throw StateError('Firebase is not set up'),
        run: (_) {},
      );
      await tester.pump();
    });

    expect(printed,
        contains('NotificationService initialization error: '
            'Bad state: Firebase is not set up'));
  });

  testWidgets('without Firebase, the app is drawn with no push set-up',
      (tester) async {
    final drawn = <Widget>[];
    const app = Text('the app');
    final printed = await _logged(() async {
      runAppThenStartPush(app, run: drawn.add);
      await tester.pump();
    });

    expect(drawn, [same(app)]);
    expect(printed.where((m) => m.contains('NotificationService')), isEmpty);
  });
}
