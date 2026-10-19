import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// An auth state that tests set by hand, without the real notifier's
/// secure-storage read.
class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  void set(AuthState next) => state = next;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

const _signedIn = AuthState(accessToken: 'token', isInitialized: true);
const _signedOut = AuthState(isInitialized: true);

void main() {
  group('authRedirect', () {
    test('the splash screen routes itself', () {
      expect(authRedirect(const AuthState(), '/splash'), isNull);
      expect(authRedirect(_signedIn, '/splash'), isNull);
    });

    test('nothing opens before the stored session has been read', () {
      expect(authRedirect(const AuthState(), '/events'), '/splash');
      expect(authRedirect(const AuthState(), '/events/hack-night-04'),
          '/splash');
    });

    test('signed out, a page about the person leads to sign-in, and back',
        () {
      // How an ended session reaches the screen: the state changes, the
      // router re-runs this on the page the person is on.
      expect(authRedirect(_signedOut, '/profile/settings'),
          '/auth/onboarding?from=%2Fprofile%2Fsettings');
      expect(authRedirect(_signedOut, '/events'),
          '/auth/onboarding?from=%2Fevents');
      // The query comes back too.
      expect(authRedirect(_signedOut, '/profile/badges?x=1'),
          '/auth/onboarding?from=%2Fprofile%2Fbadges%3Fx%3D1');
    });

    test('signed out, the public pages open', () {
      for (final location in [
        '/',
        '/events/12',
        '/events/hack-night-04',
        '/events/hack-night-04?live=room',
        '/events/explore?topic=design',
        '/clubs/circuit-society',
        '/clubs/explore',
        '/threads/abc',
        '/tickets/abc-123',
        '/certificates/abc-123',
        '/topics/development',
        // Each asks for an account at its own action.
        '/events/hack-night-04/register',
        '/events/hack-night-04/compete',
        '/feedback/12/34?k=abc',
        // Batch A's pages.
        '/discover/events?when=this_week',
        '/discover/clubs',
        '/discover/threads',
        '/topics',
      ]) {
        expect(authRedirect(_signedOut, location), isNull, reason: location);
      }
    });

    test('signed out, sign-in and onboarding stay open', () {
      expect(authRedirect(_signedOut, '/auth/onboarding'), isNull);
      expect(
          authRedirect(_signedOut, '/auth/onboarding?from=%2Fprofile'), isNull);
      expect(authRedirect(_signedOut, '/auth/verify-email'), isNull);
      expect(authRedirect(_signedOut, '/onboarding/details'), isNull);
    });

    test('signed in, the app is open', () {
      expect(authRedirect(_signedIn, '/'), isNull);
      expect(authRedirect(_signedIn, '/events/12'), isNull);
      expect(authRedirect(_signedIn, '/profile/settings'), isNull);
      expect(authRedirect(_signedIn, '/auth/onboarding'), '/auth/profile-check');
      // Signed in on sign-in with a way back: the profile check takes an
      // existing account straight there.
      expect(authRedirect(_signedIn, '/auth/onboarding?from=%2Fprofile'),
          '/auth/profile-check?from=%2Fprofile');
      // Never anywhere outside the app.
      expect(
          authRedirect(_signedIn,
              '/auth/onboarding?from=${Uri.encodeComponent('https://evil.example/x')}'),
          '/auth/profile-check');
    });

    test('a link that opened the app, signed out: a public one opens over '
        'home instead of sign-in', () {
      expect(
          authRedirect(_signedOut, '/auth/onboarding',
              launchLink: '/events/hack-night-04'),
          '/');
    });

    test('a link that opened the app, signed out: a private one asks for '
        'sign-in, then opens', () {
      expect(
          authRedirect(_signedOut, '/auth/onboarding',
              launchLink: '/profile/notifications'),
          '/auth/onboarding?from=%2Fprofile%2Fnotifications');
      // A sign-in already returning somewhere is left alone.
      expect(
          authRedirect(_signedOut, '/auth/onboarding?from=%2Fprofile',
              launchLink: '/events/12'),
          isNull);
    });
  });

  group('overHome', () {
    final rootKey = GlobalKey<NavigatorState>();

    test('re-roots a feature\'s absolute routes under Home', () {
      final routes = overHome(rootKey, [
        GoRoute(
            path: '/topics/:slug',
            name: 'topicPage',
            builder: (_, __) => const SizedBox()),
      ]);
      final route = routes.single as GoRoute;
      expect(route.path, 'topics/:slug');
      expect(route.name, 'topicPage');
      expect(route.parentNavigatorKey, same(rootKey));
    });

    test('takes only GoRoutes', () {
      expect(
        () => overHome(rootKey, [
          ShellRoute(
              builder: (_, __, child) => child,
              routes: [GoRoute(path: '/x', builder: (_, __) => const SizedBox())]),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('routerProvider', () {
    late _FakeAuth auth;

    ProviderContainer containerWith(AuthState initial) {
      auth = _FakeAuth(initial);
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) => auth),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      return container;
    }

    test('is one router for the session, not a new one per auth change', () {
      // It used to watch the auth state and rebuild -- back at the splash
      // screen -- on every change, so signing in threw away the profile
      // check's own navigation and a new account skipped onboarding.
      final container = containerWith(const AuthState());
      final router = container.read(routerProvider);

      auth.set(_signedOut);
      auth.set(_signedIn);
      auth.set(_signedIn.copyWith(isLoading: true));

      expect(container.read(routerProvider), same(router));
    });

    test('a cold start opens on the splash screen', () {
      final router = containerWith(const AuthState()).read(routerProvider);

      expect(router.routeInformationProvider.value.uri.path, '/splash');
    });

    test('a scope that starts after a sign-out opens on sign-in', () {
      final router = containerWith(const AuthState(
        isInitialized: true,
        endedBecause: SessionEndReason.expired,
      )).read(routerProvider);

      expect(
          router.routeInformationProvider.value.uri.path, '/auth/onboarding');
    });

    test('the current root navigator is the one notifications use', () {
      final router = containerWith(const AuthState()).read(routerProvider);

      expect(router.routerDelegate.navigatorKey, same(rootNavigatorKey));
    });

    test('/events/explore is Explore, not an event with the id "explore"',
        () {
      final router = containerWith(_signedIn).read(routerProvider);

      String? nameOf(String path) =>
          router.configuration.findMatch(Uri.parse(path)).last.route.name;

      expect(nameOf('/events/explore'), AppRoutes.exploreEvents);
      expect(nameOf('/events/12'), AppRoutes.eventDetail);
      expect(nameOf('/clubs/explore'), AppRoutes.exploreClubs);
    });

    group('the website\'s addresses', () {
      late GoRouter router;
      setUp(() => router = containerWith(_signedOut).read(routerProvider));

      RouteMatchList matchOf(String location) =>
          router.configuration.findMatch(Uri.parse(location));
      String? nameOf(String location) => matchOf(location).last.route.name;

      test('an event and a club open by slug as well as by id', () {
        expect(nameOf('/events/hack-night-04'), AppRoutes.eventDetail);
        expect(nameOf('/events/123'), AppRoutes.eventDetail);
        expect(matchOf('/events/hack-night-04').pathParameters['eventId'],
            'hack-night-04');
        expect(nameOf('/clubs/circuit-society'), AppRoutes.clubDetail);
        expect(nameOf('/clubs/42'), AppRoutes.clubDetail);
        expect(nameOf('/events/hack-night-04/register'),
            AppRoutes.eventRegister);
      });

      test('a post, a ticket and a certificate open by their ids', () {
        expect(nameOf('/threads/7d0f3c2a-1111-4c4c-9a9a-000000000001'),
            AppRoutes.threadDetail);
        expect(nameOf('/tickets/abc-123'), AppRoutes.ticket);
        expect(nameOf('/certificates/abc-123'), AppRoutes.certificateLink);
      });

      test('the public pages sit over Home, so Back leads into the app', () {
        for (final location in [
          '/events/hack-night-04',
          '/clubs/circuit-society',
          '/threads/abc',
          '/tickets/abc-123',
          '/certificates/abc-123',
          '/events/explore',
        ]) {
          final match = matchOf(location);
          final shell = match.matches.first as ShellRouteMatch;
          expect(shell.matches.first.route,
              isA<GoRoute>().having((r) => r.path, 'path', '/'),
              reason: location);
        }
        // My events stays under its own tab.
        final success = matchOf('/events/registration-success');
        expect((success.matches.first as ShellRouteMatch).matches.first.route,
            isA<GoRoute>().having((r) => r.path, 'path', '/events'));
      });

      test('nonsense matches nothing (the friendly page answers)', () {
        expect(matchOf('/events/x/y/z').isError, isTrue);
        expect(matchOf('/a/b/c').isError, isTrue);
      });
    });
  });
}
