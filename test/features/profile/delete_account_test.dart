import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/services/analytics_service.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/features/profile/presentation/pages/settings_page.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/features/volunteer/data/repositories/volunteer_repository_impl.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:finnet/features/volunteer/domain/repositories/volunteer_repository.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import '../events/events_fakes.dart' show RouteAdapter, useFakeApi;
import '../threads/moderation_fakes.dart';

const _profile = UserProfile(
  id: '42',
  fullName: 'Aarav Menon',
  email: 'aarav@example.com',
  isProfileComplete: true,
);

class _Profiles implements ProfileRepository {
  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(_profile);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _NoVolunteering implements VolunteerRepository {
  @override
  Future<Result<List<VolunteerEvent>>> myEvents() async =>
      Either.right(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// A server that keeps no notification switches: no rows for them.
class _NoPushSettings implements PushSettingsRepository {
  @override
  Future<PushSwitches?> savedSwitches() async => null;

  @override
  Future<Result<PushSwitches?>> switches() async => Either.right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _Choices implements PrivacyChoicesStore {
  @override
  Future<PrivacyChoices> read() async => PrivacyChoices.defaults;

  @override
  Future<void> write(PrivacyChoices choices) async {}
}

class _Control implements CollectionControl {
  @override
  Future<void> applyChoices(PrivacyChoices choices) async {}
}

void main() {
  late RouteAdapter api;
  late MemoryStorage storage;
  late FakeSessionRevoker revoker;
  late FakeSessionCaches caches;
  late ProviderContainer container;

  setUp(() {
    api = useFakeApi();
    storage = MemoryStorage(
        {'access_token': 'access-1', 'refresh_token': 'refresh-1'});
    revoker = FakeSessionRevoker();
    caches = FakeSessionCaches();
  });

  /// Settings, signed in, opened from the Profile tab.
  Future<void> pump(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(800, 3000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Signed in: the stored session, already read.
        authSeedProvider.overrideWithValue(const AuthState(
          accessToken: 'access-1',
          refreshToken: 'refresh-1',
          isInitialized: true,
        )),
        secureStorageServiceProvider.overrideWithValue(storage),
        pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
        sessionRevokerProvider.overrideWithValue(revoker),
        sessionCachesProvider.overrideWithValue(caches),
        navigationIndexProvider.overrideWith((ref) => 3),
        privacyChoicesStoreProvider.overrideWithValue(_Choices()),
        collectionControlProvider.overrideWithValue(_Control()),
        pushSettingsRepositoryProvider.overrideWithValue(_NoPushSettings()),
        profileRepositoryProvider.overrideWithValue(_Profiles()),
        volunteerRepositoryProvider.overrideWithValue(_NoVolunteering()),
        moderationRepositoryProvider
            .overrideWithValue(FakeModerationRepository()),
        linkLauncherProvider.overrideWithValue((uri) async => true),
      ],
      child: const MaterialApp(home: SettingsPage()),
    ));
    await tester.pump();
    await tester.pump();
    container = ProviderScope.containerOf(tester.element(find.byType(SettingsPage)));
    expect(container.read(isAuthenticatedProvider), isTrue);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> askToDelete(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('settings-delete-account')));
    await tester.pumpAndSettle();
  }

  testWidgets('Delete Account asks first, saying it is permanent',
      (tester) async {
    await pump(tester);

    await askToDelete(tester);

    expect(find.text('DELETE YOUR ACCOUNT?'), findsOneWidget);
    expect(find.textContaining('This action is permanent'), findsOneWidget);
    expect(find.text('DELETE'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
    expect(api.requests, isEmpty);
  });

  testWidgets(
      'confirmed: DELETE /user/delete under the API base -- not '
      '/api/v1/api/v1/user/delete, which 404d in 1.0.1 -- then signed out',
      (tester) async {
    api.on('DELETE', '/user/delete', {'message': 'User deleted successfully.'});
    await pump(tester);

    await askToDelete(tester);
    await tester.tap(find.text('DELETE'));
    await settle(tester);

    final sent = api.requests.single;
    expect(sent.method, 'DELETE');
    expect(sent.path, '/user/delete');
    expect(sent.uri.path, endsWith('/api/v1/user/delete'));
    expect(sent.uri.path, isNot(contains('/api/v1/api/v1/')));
    // As the signed-in person: the token goes with it.
    expect(sent.extra['skipAuth'], isFalse);

    // Signed out, as a sign-out does: the session ended on the server, the
    // tokens and everything kept about them gone, the tabs back to Home.
    final auth = container.read(authStateProvider);
    expect(auth.isAuthenticated, isFalse);
    expect(auth.endedBecause, SessionEndReason.signedOut);
    expect(storage.values, isEmpty);
    expect(revoker.revoked, ['access-1']);
    expect(caches.cleared, greaterThanOrEqualTo(1));
    expect(container.read(profileProvider).profile, isNull);
    expect(container.read(navigationIndexProvider), 0);
    expect(find.textContaining('Failed'), findsNothing);
  });

  testWidgets('cancelled: nothing is sent and nothing changes', (tester) async {
    await pump(tester);

    await askToDelete(tester);
    await tester.tap(find.text('CANCEL'));
    await settle(tester);

    expect(find.text('DELETE YOUR ACCOUNT?'), findsNothing);
    expect(api.requests, isEmpty);
    expect(container.read(isAuthenticatedProvider), isTrue);
    expect(storage.values['access_token'], 'access-1');
    expect(container.read(navigationIndexProvider), 3);
  });

  testWidgets(
      'refused by the server: says why, and the person stays signed in',
      (tester) async {
    api.on('DELETE', '/user/delete',
        {'message': 'Could not delete the account right now'},
        status: 503);
    await pump(tester);

    await askToDelete(tester);
    await tester.tap(find.text('DELETE'));
    await settle(tester);

    expect(api.sent('DELETE', '/user/delete'), hasLength(1));
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('ApiException'), findsNothing);
    expect(container.read(isAuthenticatedProvider), isTrue);
    expect(storage.values['access_token'], 'access-1');
    expect(revoker.revoked, isEmpty);
    expect(container.read(navigationIndexProvider), 3);
  });
}
