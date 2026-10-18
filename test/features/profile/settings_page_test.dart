import 'package:finnet/core/error/either.dart';
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

Future<List<Uri>> _pump(WidgetTester tester,
    {bool launches = true, PushSettingsRepository? pushSettings}) async {
  final opened = <Uri>[];
  await tester.pumpWidget(ProviderScope(
    overrides: [
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
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets('no notification switches the server would ignore',
      (tester) async {
    await _pump(tester);

    expect(find.byType(Switch), findsNothing);
    expect(find.text('Event Notification'), findsNothing);
    expect(find.text('Club Updates'), findsNothing);
  });

  testWidgets('the switches the server keeps, and turning one off',
      (tester) async {
    final settings = _FakePushSettings(
        const PushSwitches(clubs: true, topics: true, platform: false));
    await _pump(tester, pushSettings: settings);

    expect(find.byType(Switch), findsNWidgets(3));
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
}
