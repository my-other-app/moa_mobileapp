import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// A page with something on it that needs an account.
class _ClubPage extends ConsumerWidget {
  const _ClubPage({required this.id, this.extra});

  final String id;
  final Object? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          Text('club $id ${extra ?? ''}'),
          ElevatedButton(
            onPressed: () {
              if (ensureSignedIn(context, ref, 'Sign in to follow clubs.')) {
                ref.read(_followed.notifier).state = true;
              }
            },
            child: const Text('FOLLOW'),
          ),
        ],
      ),
    );
  }
}

final _followed = StateProvider<bool>((ref) => false);

/// Stands in for the whole sign-in flow: its button is "signed in".
class _SignIn extends ConsumerWidget {
  const _SignIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: ElevatedButton(
        onPressed: () => goAfterSignIn(context, ref),
        child: const Text('SIGNED IN'),
      ),
    );
  }
}

GoRouter _router() => GoRouter(
      initialLocation: '/clubs/12',
      routes: [
        GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('home'))),
        GoRoute(
            path: '/clubs/:id',
            builder: (context, state) => _ClubPage(
                id: state.pathParameters['id']!, extra: state.extra)),
        GoRoute(
            path: '/auth/onboarding',
            builder: (context, state) => const _SignIn()),
      ],
    );

Future<ProviderContainer> _pump(WidgetTester tester,
    {required bool signedIn, GoRouter? router}) async {
  final container = ProviderContainer(overrides: [
    isAuthenticatedProvider.overrideWithValue(signedIn),
  ]);
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router ?? _router()),
  ));
  await tester.pump();
  return container;
}

void main() {
  testWidgets('signed in, the action just happens', (tester) async {
    final c = await _pump(tester, signedIn: true);

    await tester.tap(find.text('FOLLOW'));
    await tester.pumpAndSettle();

    expect(c.read(_followed), isTrue);
    expect(find.byKey(const ValueKey('sign-in-prompt')), findsNothing);
  });

  testWidgets('signed out, it asks first and does nothing on "Not now"',
      (tester) async {
    final c = await _pump(tester, signedIn: false);

    await tester.tap(find.text('FOLLOW'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sign-in-prompt')), findsOneWidget);
    expect(find.text('Sign in to follow clubs.'), findsOneWidget);
    expect(c.read(_followed), isFalse);

    await tester.tap(find.byKey(const ValueKey('sign-in-prompt-later')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sign-in-prompt')), findsNothing);
    expect(find.text('club 12 '), findsOneWidget);
    expect(c.read(signInReturnProvider), isNull);
  });

  testWidgets('signing in from the ask comes back to the same page',
      (tester) async {
    final router = _router();
    final c = await _pump(tester, signedIn: false, router: router);
    router.go('/clubs/12', extra: 'slug=robotics');
    await tester.pumpAndSettle();

    await tester.tap(find.text('FOLLOW'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sign-in-prompt-go')));
    await tester.pumpAndSettle();

    // On the sign-in screen, with the club remembered.
    expect(find.text('SIGNED IN'), findsOneWidget);
    expect(c.read(signInReturnProvider)?.location, '/clubs/12');

    await tester.tap(find.text('SIGNED IN'));
    await tester.pumpAndSettle();

    // Back on the club, opened as it was, and the page is used up.
    expect(find.text('club 12 slug=robotics'), findsOneWidget);
    expect(c.read(signInReturnProvider), isNull);
  });

  testWidgets('a page left long ago is not where sign-in lands',
      (tester) async {
    final router = _router();
    final c = await _pump(tester, signedIn: false, router: router);
    c.read(signInReturnProvider.notifier).state = SignInReturn('/clubs/12',
        at: DateTime.now().subtract(const Duration(hours: 2)));
    router.go('/auth/onboarding');
    await tester.pumpAndSettle();

    await tester.tap(find.text('SIGNED IN'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('with nothing to come back to, sign-in lands at home',
      (tester) async {
    final router = _router();
    await _pump(tester, signedIn: false, router: router);
    router.go('/auth/onboarding');
    await tester.pumpAndSettle();

    await tester.tap(find.text('SIGNED IN'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
  });
}
