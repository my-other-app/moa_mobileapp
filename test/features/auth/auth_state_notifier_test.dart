import 'package:finnet/core/auth/session_events.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'auth_fakes.dart';

void main() {
  late MemoryStorage storage;
  late FakePushRegistration push;
  late FakeSessionRevoker revoker;

  ProviderContainer containerWith({AuthState? seed}) {
    final container = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(storage),
      pushRegistrationProvider.overrideWithValue(push),
      sessionRevokerProvider.overrideWithValue(revoker),
      if (seed != null) authSeedProvider.overrideWithValue(seed),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  /// Let the notifier finish reading storage.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    storage = MemoryStorage();
    push = FakePushRegistration();
    revoker = FakeSessionRevoker();
  });

  group('start-up', () {
    test('a stored session is restored, and registered for push without a prompt',
        () async {
      storage.values.addAll({'access_token': 'a', 'refresh_token': 'r'});
      final container = containerWith();
      container.read(authStateProvider);
      await settle();

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isTrue);
      expect(state.isInitialized, isTrue);
      expect(push.calls, ['restored']);
    });

    test('a seeded scope does not read storage', () async {
      storage.values.addAll({'access_token': 'stale'});
      final container = containerWith(
        seed: const AuthState(
          isInitialized: true,
          endedBecause: SessionEndReason.expired,
        ),
      );
      container.read(authStateProvider);
      await settle();

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.endedBecause, SessionEndReason.expired);
      expect(push.calls, isEmpty);
    });
  });

  test('signing in asks for push permission -- then, not at start-up',
      () async {
    final container = containerWith();
    await settle();

    await container
        .read(authStateProvider.notifier)
        .setAuthenticated(accessToken: 'a', refreshToken: 'r');

    expect(push.calls, ['signedIn']);
    expect(storage.values['access_token'], 'a');
  });

  group('logout', () {
    test('asks the server first, while the tokens are still stored', () async {
      // The revoke used to run after the refresh token was cleared, so an
      // expired access token could not be refreshed and it failed silently.
      final token = tokenWithSid('s-1');
      storage.values.addAll({'access_token': token, 'refresh_token': 'r'});
      final seenByServerCalls = <Map<String, String>>[];
      push.onServerUnregister =
          () async => seenByServerCalls.add({...storage.values});
      revoker.during = () async => seenByServerCalls.add({...storage.values});
      final container = containerWith();
      container.read(authStateProvider);
      await settle();

      await container.read(authStateProvider.notifier).logout();

      // FCM token off the server, then the session, then the token itself.
      expect(push.calls, ['restored', 'serverUnregistered', 'signedOut']);
      expect(revoker.revoked, [token]);
      // Through the normal path, so the interceptor can refresh once.
      expect(revoker.stored, [true]);
      expect(seenByServerCalls, [
        {'access_token': token, 'refresh_token': 'r'},
        {'access_token': token, 'refresh_token': 'r'},
      ]);
      // Then everything is cleared.
      expect(storage.values, isEmpty);
      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.isInitialized, isTrue);
      expect(state.endedBecause, SessionEndReason.signedOut);
      // Nothing to say on the sign-in screen: they chose this.
      expect(sessionEndNotice(state.endedBecause), isNull);
    });

    test('waits on the server no longer than the cap', () async {
      storage.values.addAll({'access_token': 'a', 'refresh_token': 'r'});
      revoker.during = () => Future<void>.delayed(const Duration(days: 1));
      final container = ProviderContainer(overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        pushRegistrationProvider.overrideWithValue(push),
        sessionRevokerProvider.overrideWithValue(revoker),
        signOutServerTimeoutProvider
            .overrideWithValue(const Duration(milliseconds: 50)),
      ]);
      addTearDown(container.dispose);
      container.read(authStateProvider);
      await settle();

      await container
          .read(authStateProvider.notifier)
          .logout()
          .timeout(const Duration(seconds: 2));

      expect(storage.values, isEmpty);
      expect(push.calls.last, 'signedOut');
      expect(container.read(authStateProvider).isAuthenticated, isFalse);
    });

    test('is still a sign-out when the refresh it set off is refused',
        () async {
      // An expired access token is refreshed on the way out; if the session
      // is already dead the interceptor reports it as expired. The person
      // chose to sign out, and is not told their session ended.
      storage.values.addAll({'access_token': 'a', 'refresh_token': 'r'});
      revoker.during = () async {
        SessionEvents.reportRevoked(SessionEndReason.expired);
        await settle();
      };
      final container = containerWith();
      container.read(authStateProvider);
      await settle();

      await container.read(authStateProvider.notifier).logout();
      await settle();

      expect(container.read(authStateProvider).endedBecause,
          SessionEndReason.signedOut);
    });

    test('with no stored session, asks the server nothing', () async {
      final container = containerWith();
      container.read(authStateProvider);
      await settle();

      await container.read(authStateProvider.notifier).logout();

      expect(push.calls, ['signedOut']);
      expect(revoker.revoked, isEmpty);
    });
  });

  group('when the server ends the session', () {
    test('the auth state finds out, and why', () async {
      storage.values.addAll({'access_token': 'a', 'refresh_token': 'r'});
      final container = containerWith();
      container.read(authStateProvider);
      await settle();

      // What AuthInterceptor reports after a refused refresh.
      SessionEvents.reportRevoked(SessionEndReason.expired);
      await settle();
      await settle();

      final state = container.read(authStateProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.endedBecause, SessionEndReason.expired);
      expect(sessionEndNotice(state.endedBecause),
          'Your session has ended. Please sign in again.');
      expect(push.calls.last, 'signedOut');
      // Nothing to end on the server: it ended it.
      expect(revoker.revoked, isEmpty);
    });

    test('a suspension says so', () async {
      storage.values.addAll({'access_token': 'a', 'refresh_token': 'r'});
      final container = containerWith();
      container.read(authStateProvider);
      await settle();

      SessionEvents.reportRevoked(SessionEndReason.suspended);
      await settle();
      await settle();

      expect(
        sessionEndNotice(container.read(authStateProvider).endedBecause),
        contains('suspended'),
      );
    });

    test('nobody signed in, nothing happens', () async {
      final container = containerWith();
      container.read(authStateProvider);
      await settle();

      SessionEvents.reportRevoked(SessionEndReason.expired);
      await settle();

      expect(container.read(authStateProvider).endedBecause, isNull);
      expect(push.calls, isEmpty);
    });
  });

  test('the notice is shown once', () async {
    final container = containerWith(
      seed: const AuthState(
        isInitialized: true,
        endedBecause: SessionEndReason.expired,
      ),
    );

    container.read(authStateProvider.notifier).acknowledgeSessionEnd();

    expect(container.read(authStateProvider).endedBecause, isNull);
  });
}
