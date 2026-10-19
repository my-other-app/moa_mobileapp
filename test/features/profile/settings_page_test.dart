import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/services/analytics_service.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/profile/domain/repositories/profile_repository.dart';
import 'package:finnet/features/profile/presentation/pages/settings/blocked_users_page.dart';
import 'package:finnet/features/profile/presentation/pages/settings_page.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/features/volunteer/data/repositories/volunteer_repository_impl.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:finnet/features/volunteer/domain/repositories/volunteer_repository.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../threads/moderation_fakes.dart';

const _profile = UserProfile(
  id: '42',
  fullName: 'Aarav Menon',
  email: 'aarav@example.com',
  interests: [],
  isProfileComplete: true,
);

class _FakeProfiles implements ProfileRepository {
  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(_profile);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _FakeVolunteering implements VolunteerRepository {
  @override
  Future<Result<List<VolunteerEvent>>> myEvents() async =>
      Either.right(const []);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// The server's notification switches; null is a server that keeps none.
class _FakePushSettings implements PushSettingsRepository {
  _FakePushSettings(this.kept);

  PushSwitches? kept;
  final saved = <Map<String, bool?>>[];

  @override
  Future<Result<PushSwitches?>> switches() async => Either.right(kept);

  @override
  Future<Result<PushSwitches>> setSwitches(
      {bool? clubs, bool? topics, bool? platform}) async {
    saved.add({'clubs': clubs, 'topics': topics, 'platform': platform});
    kept = kept!.copyWith(clubs: clubs, topics: topics, platform: platform);
    return Either.right(kept!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// The privacy choices, kept in memory.
class _MemoryChoices implements PrivacyChoicesStore {
  _MemoryChoices([this.kept = PrivacyChoices.defaults]);

  PrivacyChoices kept;
  final written = <PrivacyChoices>[];

  @override
  Future<PrivacyChoices> read() async => kept;

  @override
  Future<void> write(PrivacyChoices choices) async {
    written.add(choices);
    kept = choices;
  }
}

/// What the SDKs were told to collect.
class _RecordingControl implements CollectionControl {
  final applied = <PrivacyChoices>[];

  @override
  Future<void> applyChoices(PrivacyChoices choices) async =>
      applied.add(choices);
}

Future<List<Uri>> _pump(WidgetTester tester,
    {bool launches = true,
    PushSettingsRepository? pushSettings,
    PrivacyChoicesStore? privacy,
    CollectionControl? control}) async {
  final opened = <Uri>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      privacyChoicesStoreProvider
          .overrideWithValue(privacy ?? _MemoryChoices()),
      collectionControlProvider
          .overrideWithValue(control ?? _RecordingControl()),
      pushSettingsRepositoryProvider
          .overrideWithValue(pushSettings ?? _FakePushSettings(null)),
      profileRepositoryProvider.overrideWithValue(_FakeProfiles()),
      volunteerRepositoryProvider.overrideWithValue(_FakeVolunteering()),
      moderationRepositoryProvider
          .overrideWithValue(FakeModerationRepository()),
      isAuthenticatedProvider.overrideWithValue(true),
      linkLauncherProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return launches;
      }),
    ],
    child: const MaterialApp(home: SettingsPage()),
  ));
  await tester.pump();
  await tester.pump();
  return opened;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  await tester.ensureVisible(finder);
  // ensureVisible only asks for the scroll; the frame after it lays it out.
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('no notification switches the server would ignore',
      (tester) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('push-switch-clubs')), findsNothing);
    expect(find.text('Event Notification'), findsNothing);
    expect(find.text('Club Updates'), findsNothing);
  });

  testWidgets('the switches the server keeps, and turning one off',
      (tester) async {
    final settings = _FakePushSettings(
        const PushSwitches(clubs: true, topics: true, platform: false));
    await _pump(tester, pushSettings: settings);

    // The three notification switches, and the two privacy ones.
    expect(find.byType(Switch), findsNWidgets(5));
    bool on(String key) =>
        tester.widget<SwitchListTile>(find.byKey(ValueKey(key))).value;
    expect(on('push-switch-clubs'), isTrue);
    expect(on('push-switch-platform'), isFalse);

    await _tap(tester, 'push-switch-topics');
    await tester.pump();

    expect(settings.saved, [
      {'clubs': null, 'topics': false, 'platform': null}
    ]);
    expect(on('push-switch-topics'), isFalse);
  });

  testWidgets('the privacy policy opens on the website', (tester) async {
    final opened = await _pump(tester);

    await _tap(tester, 'settings-privacy');

    expect(opened, [Uri.parse('https://myotherapp.in/privacy')]);
  });

  testWidgets('the terms open on the website', (tester) async {
    final opened = await _pump(tester);

    await _tap(tester, 'settings-terms');

    expect(opened, [Uri.parse('https://myotherapp.in/terms')]);
  });

  testWidgets('support is an email to the team, not a WhatsApp number',
      (tester) async {
    final opened = await _pump(tester);

    expect(find.text('support@myotherapp.in'), findsOneWidget);
    await _tap(tester, 'settings-support');

    expect(opened.single.scheme, 'mailto');
    expect(opened.single.path, 'support@myotherapp.in');
    expect(opened.single.toString(), isNot(contains('wa.me')));
  });

  testWidgets('without a mail app, the address is copied instead',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    await _pump(tester, launches: false);
    await _tap(tester, 'settings-support');
    await tester.pump();

    expect(copied, 'support@myotherapp.in');
    expect(find.text('No email app found. support@myotherapp.in is copied.'),
        findsOneWidget);
  });

  testWidgets('the website opens', (tester) async {
    final opened = await _pump(tester);

    await _tap(tester, 'settings-website');

    expect(opened, [Uri.parse('https://myotherapp.in')]);
  });

  testWidgets('Blocked Users opens the list', (tester) async {
    await _pump(tester);

    await _tap(tester, 'settings-blocked-users');
    await tester.pumpAndSettle();

    expect(find.byType(BlockedUsersPage), findsOneWidget);
  });

  group('privacy', () {
    bool on(WidgetTester tester, String key) =>
        tester.widget<SwitchListTile>(find.byKey(ValueKey(key))).value;

    testWidgets('analytics and crash reports are both on to begin with',
        (tester) async {
      await _pump(tester);

      expect(find.text('Share usage analytics'), findsOneWidget);
      expect(find.text('Send crash reports'), findsOneWidget);
      expect(on(tester, 'privacy-switch-analytics'), isTrue);
      expect(on(tester, 'privacy-switch-crash-reports'), isTrue);
    });

    testWidgets('turning analytics off saves it and stops collection at once',
        (tester) async {
      final store = _MemoryChoices();
      final control = _RecordingControl();
      await _pump(tester, privacy: store, control: control);

      await _tap(tester, 'privacy-switch-analytics');
      await tester.pump();

      const chosen = PrivacyChoices(analytics: false, crashReports: true);
      expect(on(tester, 'privacy-switch-analytics'), isFalse);
      expect(on(tester, 'privacy-switch-crash-reports'), isTrue);
      expect(store.written, [chosen]);
      expect(control.applied, [chosen]);
    });

    testWidgets('crash reports are a switch of their own', (tester) async {
      final store = _MemoryChoices();
      final control = _RecordingControl();
      await _pump(tester, privacy: store, control: control);

      await _tap(tester, 'privacy-switch-crash-reports');
      await tester.pump();

      const chosen = PrivacyChoices(analytics: true, crashReports: false);
      expect(on(tester, 'privacy-switch-analytics'), isTrue);
      expect(on(tester, 'privacy-switch-crash-reports'), isFalse);
      expect(store.written, [chosen]);
      expect(control.applied, [chosen]);
    });

    testWidgets('a choice made earlier is what the switches show',
        (tester) async {
      await _pump(tester,
          privacy: _MemoryChoices(
              const PrivacyChoices(analytics: false, crashReports: false)));

      expect(on(tester, 'privacy-switch-analytics'), isFalse);
      expect(on(tester, 'privacy-switch-crash-reports'), isFalse);
    });
  });
}
