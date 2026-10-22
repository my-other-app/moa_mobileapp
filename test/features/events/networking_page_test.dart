import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/networking_page.dart';
import 'package:finnet/features/events/presentation/widgets/networking/networking_visibility_switch.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../threads/moderation_fakes.dart';
import 'events_fakes.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [visible] is the profile's "Show me in People Like You"; null, a
/// profile that does not say.
Future<FakeModerationRepository> _pumpNetworking(WidgetTester tester,
    {bool signedIn = true, bool? visible = true}) async {
  final moderation = FakeModerationRepository();
  final profiles = FakeProfileRepository()
    ..profile = testProfile.copyWith(networkingVisible: visible);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      moderationRepositoryProvider.overrideWithValue(moderation),
      profileRepositoryProvider.overrideWithValue(profiles),
      isAuthenticatedProvider.overrideWithValue(signedIn),
    ],
    child: const MaterialApp(
      home: NetworkingPage(eventId: 7, eventName: 'Hack Night'),
    ),
  ));
  await _settle(tester);
  return moderation;
}

/// When the list closes in these answers: 9:30 PM today, on the phone.
final _closes = DateTime.now().copyWith(hour: 21, minute: 30, second: 0);

Map<String, dynamic> _answer(List<Map<String, dynamic>> attendees,
        {bool visible = true}) =>
    {
      'event_id': 7,
      'event_name': 'Hack Night',
      'window_closes_at': _closes.toUtc().toIso8601String(),
      'visible': visible,
      'total': attendees.length,
      'matches': attendees.where((a) => (a['match_count'] as int) > 0).length,
      'attendees': attendees,
    };

Map<String, dynamic> _person(int id, String name,
        {List<String> shared = const [], String? org}) =>
    {
      'user_id': id,
      'name': name,
      'profile_pic_url': null,
      'organization': org,
      'shared_interests': [
        for (final (i, s) in shared.indexed) {'id': i + 1, 'name': s},
      ],
      'match_count': shared.length,
    };

final _people = _answer([
  _person(41, 'Ravi Kumar', shared: ['AI'], org: 'CET'),
  _person(42, 'Neha'),
]);

void main() {
  group('the list', () {
    testWidgets('who shares your interests first, then who else is here',
        (tester) async {
      useFakeApi().on(
          'GET',
          '/events/7/networking',
          _answer([
            _person(41, 'Ravi Kumar', shared: ['AI', 'Robotics'], org: 'CET'),
            _person(43, 'Bina', shared: ['AI']),
            _person(42, 'Neha'),
          ]));
      await _pumpNetworking(tester);

      expect(find.text('Hack Night'), findsOneWidget);
      expect(find.text('Open until 9:30 PM'), findsOneWidget);
      expect(find.text('2 people share your interests'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('CET'), findsOneWidget);
      expect(find.text('Also here'), findsOneWidget);
      expect(find.text('Neha'), findsOneWidget);
      // Shared interests as the app's chips, chosen.
      final chips = tester.widgetList<InterestChip>(find.byType(InterestChip));
      expect([for (final c in chips) c.label], ['AI', 'Robotics', 'AI']);
      expect(chips.every((c) => c.plain && c.selected), isTrue);
      // In order: the most shared first.
      expect(tester.getTopLeft(find.text('Ravi Kumar')).dy,
          lessThan(tester.getTopLeft(find.text('Bina')).dy));
      expect(tester.getTopLeft(find.text('Bina')).dy,
          lessThan(tester.getTopLeft(find.text('Neha')).dy));
    });

    testWidgets('nobody sharing yet: it says so, and who else is here',
        (tester) async {
      useFakeApi()
          .on('GET', '/events/7/networking', _answer([_person(42, 'Neha')]));
      await _pumpNetworking(tester);

      expect(find.text('No one else here shares your interests yet.'),
          findsOneWidget);
      expect(find.text('Check back as more people arrive.'), findsOneWidget);
      expect(find.text('Also here'), findsOneWidget);
      expect(find.text('Neha'), findsOneWidget);
    });

    testWidgets('nobody here at all: the same words, nothing else',
        (tester) async {
      useFakeApi().on('GET', '/events/7/networking', _answer(const []));
      await _pumpNetworking(tester);

      expect(find.byKey(const ValueKey('networking-empty')), findsOneWidget);
      expect(find.text('Also here'), findsNothing);
    });

    testWidgets('pull to refresh brings in who arrived since', (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/7/networking', _answer(const []))
        ..on('GET', '/events/7/networking',
            _answer([_person(44, 'Arjun', shared: ['Music'])]));
      await _pumpNetworking(tester);
      expect(find.byKey(const ValueKey('networking-empty')), findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      await tester.pump(const Duration(seconds: 1));

      expect(api.sent('GET', '/events/7/networking'), hasLength(2));
      expect(find.text('Arjun'), findsOneWidget);
      expect(find.text('1 person shares your interests'), findsOneWidget);
    });
  });

  group('when the list is not there', () {
    testWidgets('a plan without networking says so, with nothing to retry',
        (tester) async {
      // What the audit saw: "ApiException: You do not have permission…
      // (forbidden, code: 403)".
      useFakeApi().on(
          'GET',
          '/events/7/networking',
          {
            'message': 'You do not have permission to access this resource.',
            'error_code': 'NETWORKING_UNAVAILABLE',
          },
          status: 403);
      await _pumpNetworking(tester);

      expect(find.text("This event doesn't have People Like You"),
          findsOneWidget);
      expect(find.textContaining('ApiException'), findsNothing);
      expect(find.textContaining('permission'), findsNothing);
      expect(find.text('Try again'), findsNothing);
      // Not a dead end: the event is a tap away.
      expect(find.text('Open the event'), findsOneWidget);
    });

    testWidgets('not checked in: check in first, then look again',
        (tester) async {
      final api = useFakeApi()
        ..on(
            'GET',
            '/events/7/networking',
            {
              'message':
                  'You must be checked in to this event to use networking.',
              'error_code': 'NETWORKING_NOT_CHECKED_IN',
            },
            status: 403)
        ..on('GET', '/events/7/networking', _people);
      await _pumpNetworking(tester);

      expect(find.text('Check in first'), findsOneWidget);
      expect(find.textContaining('checked in at the door'), findsOneWidget);
      await tester.tap(find.text('I’ve checked in'));
      await _settle(tester);

      expect(api.sent('GET', '/events/7/networking'), hasLength(2));
      expect(find.text('Ravi Kumar'), findsOneWidget);
    });

    testWidgets('closed: it says when it is open, and offers the event',
        (tester) async {
      useFakeApi().on(
          'GET',
          '/events/7/networking',
          {
            'message': 'Networking window has closed.',
            'error_code': 'NETWORKING_CLOSED',
          },
          status: 403);
      await _pumpNetworking(tester);

      expect(find.text('People Like You has closed'), findsOneWidget);
      expect(find.textContaining('an hour after it ends'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(find.text('Open the event'), findsOneWidget);
    });

    testWidgets('anything else can be retried', (tester) async {
      useFakeApi()
          .on('GET', '/events/7/networking', {'message': 'Oops'}, status: 503);
      await _pumpNetworking(tester);

      expect(find.textContaining('ApiException'), findsNothing);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('Show me in People Like You, at the top', () {
    testWidgets('visible, and turned off on the spot', (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/7/networking', _people)
        ..on('PATCH', '/user/preferences', {'networking_visible': false});
      await _pumpNetworking(tester);

      expect(find.text('You’re visible to others here'), findsOneWidget);
      await tester.tap(find.byKey(NetworkingVisibilityBanner.switchKey));
      await _settle(tester);

      expect(find.text('You’re hidden from others here'), findsOneWidget);
      expect(find.text('Nobody here sees you. You can still look.'),
          findsOneWidget);
      final sent = api.sent('PATCH', '/user/preferences');
      expect(sent, hasLength(1));
      expect(sent.single.data, {'networking_visible': false});
      // Still looking: the list stays.
      expect(find.text('Ravi Kumar'), findsOneWidget);
    });

    testWidgets('a change the server refuses goes back, and says so',
        (tester) async {
      useFakeApi()
        ..on('GET', '/events/7/networking', _people)
        ..on('PATCH', '/user/preferences', {'message': 'Try later'},
            status: 500);
      await _pumpNetworking(tester);

      await tester.tap(find.byKey(NetworkingVisibilityBanner.switchKey));
      // Off at once, before the server has answered.
      await tester.pump();
      expect(find.text('You’re hidden from others here'), findsOneWidget);
      await _settle(tester);

      expect(find.text('You’re visible to others here'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('the list saying hidden is what the switch shows',
        (tester) async {
      useFakeApi().on('GET', '/events/7/networking',
          _answer([_person(41, 'Ravi Kumar', shared: ['AI'])], visible: false));
      await _pumpNetworking(tester, visible: null);

      expect(find.text('You’re hidden from others here'), findsOneWidget);
    });
  });

  group('report and block, on each person', () {
    testWidgets('report a person: the reason, then the thanks',
        (tester) async {
      useFakeApi().on('GET', '/events/7/networking', _people);
      final moderation = await _pumpNetworking(tester);

      await tester.tap(find.byKey(const ValueKey('person-menu-41')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      expect(find.text('REPORT PERSON'), findsOneWidget);

      await tester.tap(find.text('Spam or scam'));
      await tester.pump();
      await tester.tap(find.text('SEND REPORT'));
      await tester.pumpAndSettle();

      expect(moderation.calls, ['report']);
      expect(moderation.lastTarget, ReportTarget.user(41));
      expect(moderation.lastReason, ReportReason.spam);
      expect(find.text('Thanks — our team will review this.'), findsOneWidget);
    });

    testWidgets('block a person: asked first, then gone from the list',
        (tester) async {
      useFakeApi().on('GET', '/events/7/networking', _people);
      final moderation = await _pumpNetworking(tester);
      expect(find.text('Ravi Kumar'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('person-menu-41')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      expect(find.text('BLOCK RAVI KUMAR?'), findsOneWidget);

      await tester.tap(find.text('BLOCK'));
      await tester.pumpAndSettle();

      expect(moderation.calls, ['block:41']);
      expect(find.text('Ravi Kumar'), findsNothing);
      expect(find.text('Neha'), findsOneWidget);
      expect(find.text('Ravi Kumar is blocked.'), findsOneWidget);
    });

    testWidgets('changing their mind blocks no one', (tester) async {
      useFakeApi().on('GET', '/events/7/networking', _people);
      final moderation = await _pumpNetworking(tester);

      await tester.tap(find.byKey(const ValueKey('person-menu-42')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(moderation.calls, isEmpty);
      expect(find.text('Neha'), findsOneWidget);
    });
  });

  test('when it closes, in the phone’s time', () {
    final now = DateTime(2026, 10, 22, 18);
    expect(openUntil(DateTime(2026, 10, 22, 21, 30), now: now), '9:30 PM');
    expect(openUntil(DateTime(2026, 10, 24, 0, 30), now: now), 'Sat 12:30 AM');
  });
}
