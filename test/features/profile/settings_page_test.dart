import 'dart:async';

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
import 'package:finnet/shared/widgets/app_toggle.dart';
import 'package:finnet/shared/widgets/settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart' show useFakeApi;
import '../threads/moderation_fakes.dart';

const _profile = UserProfile(
  id: '42',
  fullName: 'Aarav Menon',
  email: 'aarav@example.com',
  interests: [],
  isProfileComplete: true,
);

class _FakeProfiles implements ProfileRepository {
  _FakeProfiles([this.profile = _profile]);

  final UserProfile profile;

  @override
  Future<Result<UserProfile>> getMyProfile() async => Either.right(profile);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _FakeVolunteering implements VolunteerRepository {
  _FakeVolunteering([this.events = const []]);

  final List<VolunteerEvent> events;

  @override
  Future<Result<List<VolunteerEvent>>> myEvents() async => Either.right(events);

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

/// A server that has not answered yet -- the ~0.3-2 s from India to
/// us-east-1 that the section used to sit out blank.
class _UnansweredPushSettings implements PushSettingsRepository {
  @override
  Future<Result<PushSwitches?>> switches() =>
      Completer<Result<PushSwitches?>>().future;

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
    CollectionControl? control,
    UserProfile profile = _profile,
    List<VolunteerEvent> volunteering = const []}) async {
  final opened = <Uri>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      privacyChoicesStoreProvider
          .overrideWithValue(privacy ?? _MemoryChoices()),
      collectionControlProvider
          .overrideWithValue(control ?? _RecordingControl()),
      pushSettingsRepositoryProvider
          .overrideWithValue(pushSettings ?? _FakePushSettings(null)),
      profileRepositoryProvider.overrideWithValue(_FakeProfiles(profile)),
      volunteerRepositoryProvider
          .overrideWithValue(_FakeVolunteering(volunteering)),
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

/// Whether the switch row [key] is on.
bool on(WidgetTester tester, String key) =>
    tester.widget<SettingsRow>(find.byKey(ValueKey(key))).value!;

/// Tall enough that every row is built at once.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

final _volunteerEvent = VolunteerEvent(
  id: 9,
  slug: 'hack-night',
  name: 'Hack Night',
  clubName: 'Code Club',
  eventDatetime: DateTime(2026, 11, 2),
  hasFee: false,
  regFee: 0,
);

void main() {
  testWidgets('no notification switches the server would ignore',
      (tester) async {
    await _pump(tester);

    expect(find.byKey(const ValueKey('push-switch-clubs')), findsNothing);
    expect(find.text('Event Notification'), findsNothing);
    expect(find.text('Club Updates'), findsNothing);
  });

  testWidgets(
      'Club Updates and Announcements are there before the server answers',
      (tester) async {
    // They used to appear only once GET /notifications/settings came back.
    await _pump(tester, pushSettings: _UnansweredPushSettings());

    expect(find.text('Event Notification'), findsOneWidget);
    expect(find.text('Club Updates'), findsOneWidget);
    expect(find.text('Announcements'), findsOneWidget);
    expect(on(tester, 'push-switch-clubs'), isTrue);
    expect(on(tester, 'push-switch-platform'), isTrue);
  });

  testWidgets('the switches the server keeps, and turning one off',
      (tester) async {
    final settings = _FakePushSettings(
        const PushSwitches(clubs: true, topics: true, platform: false));
    await _pump(tester, pushSettings: settings);

    // The three notification switches, and the two privacy ones: the
    // app's own switch, not Material's.
    expect(find.byType(AppToggle), findsNWidgets(5));
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Event Notification'), findsOneWidget);
    expect(find.text('Club Updates'), findsOneWidget);
    expect(find.text('Announcements'), findsOneWidget);
    expect(on(tester, 'push-switch-clubs'), isTrue);
    expect(on(tester, 'push-switch-platform'), isFalse);

    await _tap(tester, 'push-switch-topics');
    await tester.pump();

    expect(settings.saved, [
      {'clubs': null, 'topics': false, 'platform': null}
    ]);
    expect(on(tester, 'push-switch-topics'), isFalse);
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

    expect(find.text('Contact Support'), findsOneWidget);
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

  group('the Settings design', () {
    testWidgets(
        'every row has its emoji in a circle, and no subtitle or chevron',
        (tester) async {
      _tall(tester);
      await _pump(tester,
          pushSettings: _FakePushSettings(
              const PushSwitches(clubs: true, topics: true, platform: true)),
          profile: _profile.copyWith(emailVerified: false),
          volunteering: [_volunteerEvent]);

      final rows = find.byType(SettingsRow);
      expect(
        [
          for (final e in rows.evaluate()) (e.widget as SettingsRow).label,
        ],
        [
          'Event Notification',
          'Club Updates',
          'Announcements',
          'Usage Analytics',
          'Crash Reports',
          'Verify Email',
          'Volunteer Check-in',
          'Blocked Users',
          'Help Centre',
          'Contact Support',
          'Terms and Conditions',
          'Privacy Policy',
          'Website',
          'Delete Account',
          'Log Out',
        ],
      );
      for (final element in rows.evaluate()) {
        final row = element.widget as SettingsRow;
        final one = find.byWidget(row);
        expect(
            find.descendant(
                of: one,
                matching: find.byKey(const ValueKey('settings-row-emoji'))),
            findsOneWidget,
            reason: row.label);
        // Only the name beside it (and the emoji, when drawn as text): no
        // subtitle.
        final texts = tester
            .widgetList<Text>(
                find.descendant(of: one, matching: find.byType(Text)))
            .map((t) => t.data);
        expect(texts.where((t) => t != row.label && t != row.emoji), isEmpty,
            reason: row.label);
      }
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('Verify Email only for an account that has not verified',
        (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('settings-verify-email')), findsNothing);
    });

    testWidgets('no Volunteer Check-in for someone who is not one',
        (tester) async {
      await _pump(tester);
      expect(find.byKey(const ValueKey('settings-volunteer')), findsNothing);
    });

    testWidgets('Volunteer Check-in for a volunteer', (tester) async {
      await _pump(tester, volunteering: [_volunteerEvent]);
      expect(find.byKey(const ValueKey('settings-volunteer')), findsOneWidget);
    });

    testWidgets('Help Centre opens how MyOtherApp works', (tester) async {
      final opened = await _pump(tester);

      await _tap(tester, 'settings-help');

      expect(opened, [Uri.parse('https://myotherapp.in/about')]);
    });

    testWidgets('Log Out asks first', (tester) async {
      _tall(tester);
      await _pump(tester);

      await _tap(tester, 'settings-log-out');
      await tester.pumpAndSettle();

      expect(find.text('LOG OUT?'), findsOneWidget);
    });

    testWidgets('tapping the row, not only the switch, flips it',
        (tester) async {
      final store = _MemoryChoices();
      await _pump(tester, privacy: store);

      final row = find.byKey(const ValueKey('privacy-switch-crash-reports'));
      await tester.ensureVisible(row);
      await tester.pump();
      await tester
          .tap(find.descendant(of: row, matching: find.text('Crash Reports')));
      await tester.pump();

      expect(on(tester, 'privacy-switch-crash-reports'), isFalse);
      expect(store.written.single.crashReports, isFalse);
    });
  });

  group('privacy', () {
    testWidgets('analytics and crash reports are both on to begin with',
        (tester) async {
      await _pump(tester);

      expect(find.text('Usage Analytics'), findsOneWidget);
      expect(find.text('Crash Reports'), findsOneWidget);
      // What the names do not say, once, under the two.
      expect(find.textContaining('Never your name or email'), findsOneWidget);
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

  group('Show me in People Like You', () {
    const key = 'privacy-switch-people-like-you';
    final shown = _profile.copyWith(networkingVisible: true);

    testWidgets('on for someone who has not turned it off, with its line',
        (tester) async {
      _tall(tester);
      useFakeApi();
      await _pump(tester, profile: shown);

      expect(find.text('Show me in People Like You'), findsOneWidget);
      expect(on(tester, key), isTrue);
      expect(find.textContaining('people who share your interests can find you'),
          findsOneWidget);
      // In the privacy group, after the two the phone keeps.
      expect(tester.getTopLeft(find.text('Show me in People Like You')).dy,
          greaterThan(tester.getTopLeft(find.text('Crash Reports')).dy));
    });

    testWidgets('turned off: shown at once, and the server told',
        (tester) async {
      _tall(tester);
      final api = useFakeApi()
        ..on('PATCH', '/user/preferences', {'networking_visible': false});
      await _pump(tester, profile: shown);

      await _tap(tester, key);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(on(tester, key), isFalse);
      final sent = api.sent('PATCH', '/user/preferences');
      expect(sent, hasLength(1));
      expect(sent.single.data, {'networking_visible': false});
    });

    testWidgets('a change the server refuses goes back, and says why',
        (tester) async {
      _tall(tester);
      useFakeApi().on('PATCH', '/user/preferences', {'message': 'Try later'},
          status: 500);
      await _pump(tester, profile: shown);

      await _tap(tester, key);
      // Off at once, before the server has answered...
      expect(on(tester, key), isFalse);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      // ...and back on when it refuses, with why in red.
      expect(on(tester, key), isTrue);
      final reds = tester
          .widgetList<SettingsCaption>(find.byType(SettingsCaption))
          .where((c) => c.color == Colors.red);
      expect(reds, hasLength(1));
      expect(find.textContaining('people who share your interests can find you'),
          findsNothing);
    });

    testWidgets('no switch from a server without one', (tester) async {
      _tall(tester);
      await _pump(tester);
      expect(find.text('Show me in People Like You'), findsNothing);
    });
  });
}
