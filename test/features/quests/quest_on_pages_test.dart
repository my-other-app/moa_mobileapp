import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/quests/domain/quest.dart';
import 'package:finnet/features/quests/presentation/widgets/quest_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';
import 'quest_fixtures.dart';

/// The quest card where the guest meets it: the event page and the ticket.

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Map<String, dynamic> _info({bool registered = true, String? status}) => {
      'id': 1,
      'name': 'DevFest',
      'slug': 'devfest-2026',
      'poster': null,
      'event_datetime': DateTime.now()
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String(),
      'duration': 8,
      'location_name': 'Kochi',
      'has_fee': false,
      'reg_fee': 0,
      'has_prize': false,
      'is_online': false,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'reg_enddate': null,
      'club': {'id': 3, 'name': 'GDG Kochi', 'slug': 'gdg-kochi', 'logo': {}},
      'category': {'id': 1, 'name': 'Tech'},
      'additional_details': const [],
      'rating': 0,
      'total_rating': 0,
      'is_registered': registered,
      'is_attended': false,
      'is_paid': registered ? true : null,
      'ticket_url': registered ? 'https://myotherapp.in/tickets/T-1' : null,
      if (status != null) 'status': status,
    };

Future<void> _pumpEventPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
    ],
    child: const MaterialApp(home: IndividualEventPage(eventId: 1)),
  ));
  await _settle(tester);
}

Finder get _card => find.byKey(QuestCard.cardKey);

void main() {
  group('the event page', () {
    testWidgets('an event that runs a quest: the card', (tester) async {
      useFakeApi()
        ..on('GET', '/events/info/1', _info())
        ..on('GET', '/events/1/quest', questJson());
      await _pumpEventPage(tester);
      await tester.scrollUntilVisible(_card, 300);
      expect(_card, findsOneWidget);
      expect(find.text('DevFest Quest'), findsOneWidget);
    });

    testWidgets('one without (or a server from before quests): as ever',
        (tester) async {
      useFakeApi().on('GET', '/events/info/1', _info());
      await _pumpEventPage(tester);
      expect(_card, findsNothing);
    });

    testWidgets("its info says no quest (§8.5): the card isn't asked for",
        (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/info/1', {
          ..._info(),
          'quest': {'enabled': false, 'can_take_part': false, 'held': false},
        })
        ..on('GET', '/events/1/quest', questJson());
      await _pumpEventPage(tester);
      expect(_card, findsNothing);
      expect(api.sent('GET', '/events/1/quest'), isEmpty);
      // Nor on a pull.
      await tester.fling(
          find.byType(Scrollable).first, const Offset(0, 600), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(api.sent('GET', '/events/1/quest'), isEmpty);
    });

    testWidgets('its info says the quest is on: the card', (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/info/1', {
          ..._info(),
          'quest': {'enabled': true, 'can_take_part': true, 'held': false},
        })
        ..on('GET', '/events/1/quest', questJson());
      await _pumpEventPage(tester);
      await tester.scrollUntilVisible(_card, 300);
      expect(_card, findsOneWidget);
      expect(api.sent('GET', '/events/1/quest'), hasLength(1));
    });

    testWidgets('off, with a reward still held: the paused card',
        (tester) async {
      useFakeApi()
        ..on('GET', '/events/info/1', {
          ..._info(),
          'quest': {'enabled': false, 'can_take_part': false, 'held': true},
        })
        ..on('GET', '/events/1/quest',
            pausedJson([claimJson(variant: 'M', name: 'DevFest T-shirt')]));
      await _pumpEventPage(tester);
      final paused = find.byKey(QuestCard.pausedKey);
      await tester.scrollUntilVisible(paused, 300);
      expect(
          find.text('Your DevFest T-shirt (M) is still held for you — '
              'collect it at Swag desk.'),
          findsOneWidget);
    });

    testWidgets('called off: no quest, whatever it says', (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/info/1',
            {..._info(), 'status': 'cancelled', 'cancel_reason': 'Rain'})
        ..on('GET', '/events/1/quest', questJson());
      await _pumpEventPage(tester);
      expect(_card, findsNothing);
      expect(api.sent('GET', '/events/1/quest'), isEmpty);
    });

    testWidgets('pulled down: the quest is read again', (tester) async {
      final api = useFakeApi()
        ..on('GET', '/events/info/1', _info())
        ..on('GET', '/events/1/quest', questJson());
      await _pumpEventPage(tester);
      final before = api.sent('GET', '/events/1/quest').length;
      await tester.fling(
          find.byType(Scrollable).first, const Offset(0, 600), 1000);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await _settle(tester);
      expect(api.sent('GET', '/events/1/quest').length, greaterThan(before));
    });
  });

  group('the ticket', () {
    Future<void> pumpTicket(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(
          home:
              TicketViewPage(ticketId: 'T-1', eventName: 'DevFest', eventId: 1),
        ),
      ));
      await _settle(tester);
    }

    testWidgets('the guest\'s quest, under the ticket', (tester) async {
      useFakeApi().on('GET', '/events/1/quest', questJson());
      await pumpTicket(tester);
      expect(_card, findsOneWidget);
      expect(find.text('10 more points to unlock Tier 1'), findsOneWidget);
    });

    testWidgets('the times by the quest\'s clock: the event\'s day',
        (tester) async {
      questClock = () => DateTime(2026, 11, 28, 11);
      addTearDown(() => questClock = DateTime.now);
      useFakeApi().on(
          'GET',
          '/events/1/quest',
          questJson(tasks: [
            taskJson('t-in',
                kind: 'checked_in',
                title: 'Check in',
                done: true,
                source: 'auto',
                // 9:30 AM by the phone's clock, in any time zone.
                doneAt: DateTime(2026, 11, 28, 9, 30).toUtc().toIso8601String()),
          ]));
      await pumpTicket(tester);
      // The same day as the quest's clock: the time alone.
      expect(find.text('Done at 9:30 AM'), findsOneWidget);
    });

    testWidgets('no quest: the ticket as ever', (tester) async {
      useFakeApi();
      await pumpTicket(tester);
      expect(_card, findsNothing);
    });

    testWidgets('switched off with the T-shirt held: said under the ticket',
        (tester) async {
      useFakeApi().on('GET', '/events/1/quest',
          pausedJson([claimJson(variant: 'M', name: 'DevFest T-shirt')]));
      await pumpTicket(tester);
      expect(find.byKey(QuestCard.pausedKey), findsOneWidget);
      expect(find.text('Quests are paused.'), findsOneWidget);
    });
  });
}
