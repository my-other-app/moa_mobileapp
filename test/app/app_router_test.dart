import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    });

    test('signed out, a protected page leads to sign-in', () {
      // How an ended session reaches the screen: the state changes, the
      // router re-runs this on the page the person is on.
      expect(authRedirect(_signedOut, '/profile/settings'), '/auth/onboarding');
      expect(authRedirect(_signedOut, '/threads/abc'), '/auth/onboarding');
      expect(authRedirect(_signedOut, '/'), '/auth/onboarding');
    });

    test('signed out, sign-in and onboarding stay open', () {
      expect(authRedirect(_signedOut, '/auth/onboarding'), isNull);
      expect(authRedirect(_signedOut, '/auth/verify-email'), isNull);
      expect(authRedirect(_signedOut, '/onboarding/details'), isNull);
    });

    test('signed in, the app is open', () {
      expect(authRedirect(_signedIn, '/'), isNull);
      expect(authRedirect(_signedIn, '/events/12'), isNull);
      expect(authRedirect(_signedIn, '/auth/onboarding'), '/auth/profile-check');
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
  });
}
