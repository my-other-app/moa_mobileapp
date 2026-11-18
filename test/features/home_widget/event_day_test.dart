import 'dart:io';

import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/home_widget/data/event_day_platform.dart';
import 'package:finnet/features/home_widget/domain/event_day.dart';
import 'package:finnet/features/home_widget/presentation/event_day_sync.dart';
import 'package:finnet/shared/widgets/settings_row.dart';

import 'widget_fakes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 7:00 on DevFest's day, in India (Sat 28 Nov 2026, 01:30 UTC).
final _morning = DateTime.utc(2026, 11, 28, 1, 30);

/// DevFest: 9:30 to 17:30, India time.
final _devfestStart = DateTime.utc(2026, 11, 28, 4, 0);

SavedTicket _ticket(
  int eventId, {
  DateTime? startsAt,
  double? hours = 8,
  bool revoked = false,
  bool online = false,
  String name = 'DevFest Kochi',
  EventCancellation? cancellation,
}) =>
    SavedTicket(
      code: 'MOA-SECRET-$eventId',
      eventId: eventId,
      eventName: name,
      startsAt: startsAt ?? _devfestStart,
      durationHours: hours,
      venue: 'Le Méridien, Kochi',
      isOnline: online,
      ticketUrl: 'https://myotherapp.in/tickets/MOA-SECRET-$eventId',
      revoked: revoked,
      cancellation: cancellation,
    );

void main() {
  group('EventDayCard', () {
    test('from a ticket: name, venue, start, end, and the ticket\'s page', () {
      final card = EventDayCard.of(_ticket(7))!;
      expect(card.eventId, 7);
      expect(card.name, 'DevFest Kochi');
      expect(card.place, 'Le Méridien, Kochi');
      expect(card.startsAt, _devfestStart);
      expect(card.endsAt, _devfestStart.add(const Duration(hours: 8)));
      expect(card.link, 'https://myotherapp.in/events/7/ticket');
      expect(appLocationForLink(Uri.parse(card.link)), '/events/7/ticket');
    });

    test('online: "Online"; no length: four hours', () {
      final card = EventDayCard.of(_ticket(7, online: true, hours: null))!;
      expect(card.place, 'Online');
      expect(card.endsAt, _devfestStart.add(eventDayDefaultLength));
    });

    test('no card for a ticket revoked, an event called off or undated', () {
      expect(EventDayCard.of(_ticket(7, revoked: true)), isNull);
      expect(
          EventDayCard.of(_ticket(7,
              cancellation: const EventCancellation(reason: 'Rain'))),
          isNull);
      expect(
          EventDayCard.of(const SavedTicket(
              code: 'X', eventId: 7, eventName: 'TBA')),
          isNull);
    });

    test('due from eight hours before the start until the end', () {
      final card = EventDayCard.of(_ticket(7))!;
      final lead = _devfestStart.subtract(eventDayLead);
      expect(card.isDueAt(lead.subtract(const Duration(minutes: 1))), isFalse);
      expect(card.isDueAt(lead), isTrue);
      expect(card.isDueAt(_devfestStart.add(const Duration(hours: 3))), isTrue);
      expect(card.isDueAt(card.endsAt), isFalse);
    });

    test('what the phone is given: never the code, its QR or its link', () {
      final map = EventDayCard.of(_ticket(7))!.toChannel();
      expect(map.keys.toSet(), {
        'event_id',
        'name',
        'place',
        'starts_at',
        'ends_at',
        'time',
        'date',
        'link',
      });
      expect(map['time'], '9:30 am');
      expect(map['date'], 'Sat, 28 Nov');
      expect(map['starts_at'], _devfestStart.millisecondsSinceEpoch);
      expect('$map', isNot(contains('MOA-SECRET')));
      expect('$map', isNot(contains('/tickets/')));
    });
  });

  group('which card', () {
    test('due: soonest first, one per event', () {
      final later = _devfestStart.add(const Duration(hours: 5));
      final due = eventDayCardsDue([
        _ticket(9, startsAt: later, name: 'After party'),
        _ticket(7),
        _ticket(7),
        _ticket(8, startsAt: DateTime.utc(2026, 12, 5)),
      ], _morning);
      expect([for (final c in due) c.eventId], [7, 9]);
    });

    test('the ticket opened wins; else the card up; else the next not shown',
        () {
      final due = eventDayCardsDue(
          [_ticket(7), _ticket(9, startsAt: _devfestStart.add(const Duration(hours: 2)))],
          _morning);
      expect(eventDayCardToShow(due: due)?.eventId, 7);
      expect(eventDayCardToShow(due: due, opened: 9)?.eventId, 9);
      expect(eventDayCardToShow(due: due, showing: 9)?.eventId, 9);
      expect(eventDayCardToShow(due: due, shownBefore: {7})?.eventId, 9);
      expect(eventDayCardToShow(due: due, shownBefore: {7, 9}), isNull);
      expect(
          eventDayCardToShow(due: due, shownBefore: {7, 9}, opened: 7)?.eventId,
          7);
      expect(eventDayCardToShow(due: const []), isNull);
    });
  });

  group('EventDayCards', () {
    late FakeEventDayPlatform phone;
    late MemoryEventDayStore store;
    late DateTime now;
    late EventDayCards cards;

    setUp(() {
      phone = FakeEventDayPlatform();
      store = MemoryEventDayStore();
      now = _morning;
      cards = EventDayCards(phone, store, now: () => now);
    });

    test('on the day: the card goes up, once', () async {
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      expect(phone.calls, ['start 7']);
      expect(phone.up, 7);
      expect(store.saved.shown.keys, [7]);

      // Opening the app again: brought up to date, not put up again.
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      expect(phone.calls, ['start 7', 'update 7']);
    });

    test('the day before: nothing', () async {
      now = _devfestStart.subtract(const Duration(hours: 20));
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      expect(phone.calls, isEmpty);
    });

    test('put away by the person: not put back by opening the app', () async {
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      phone.putAway();
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      expect(phone.calls, ['start 7']);
    });

    test('opening the ticket puts it back', () async {
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      phone.putAway();
      await cards.sync(signedIn: true, tickets: [_ticket(7)], opened: 7);
      expect(phone.calls, ['start 7', 'start 7']);
      expect(phone.up, 7);
    });

    test('opening a ticket whose day hasn\'t come puts nothing up', () async {
      final next = _ticket(8, startsAt: DateTime.utc(2026, 12, 5));
      await cards.sync(signedIn: true, tickets: [next], opened: 8);
      expect(phone.calls, isEmpty);
    });

    test('after the start: brought up to date (it says it is on)', () async {
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      now = _devfestStart.add(const Duration(minutes: 10));
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      expect(phone.calls.last, 'update 7');
    });

    test('after the end: it goes', () async {
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      now = _devfestStart.add(const Duration(hours: 8, minutes: 1));
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      expect(phone.calls.last, 'end');
      expect(phone.up, isNull);
    });

    test('the ticket revoked: it goes', () async {
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      await cards.sync(signedIn: true, tickets: [_ticket(7, revoked: true)]);
      expect(phone.calls.last, 'end');
    });

    test('one at a time: opening the other ticket moves the card', () async {
      final party = _ticket(9,
          startsAt: _devfestStart.add(const Duration(hours: 9)),
          name: 'After party');
      now = _devfestStart.add(const Duration(hours: 2));
      await cards.sync(signedIn: true, tickets: [_ticket(7), party]);
      expect(phone.up, 7);
      await cards.sync(signedIn: true, tickets: [_ticket(7), party], opened: 9);
      expect(phone.up, 9);
      expect(phone.calls, ['start 7', 'start 9']);
    });

    test('turned off: it goes at once, and nothing goes up', () async {
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      await cards.setOn(false);
      expect(phone.calls.last, 'end');
      expect(store.saved.on, isFalse);

      await cards.sync(signedIn: true, tickets: [_ticket(7)], opened: 7);
      expect(phone.up, isNull);
      expect(phone.calls.where((c) => c.startsWith('start')), hasLength(1));
    });

    test('signed out: it goes', () async {
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      await cards.sync(signedIn: false, tickets: [_ticket(7)]);
      expect(phone.calls.last, 'end');
    });

    test('forget (sign-out): it goes, the events are forgotten, the switch stays',
        () async {
      await cards.setOn(true);
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      await cards.forget();
      expect(phone.up, isNull);
      expect(store.saved.shown, isEmpty);
      expect(store.saved.on, isTrue);
    });

    test('the phone refuses (Live Activities or notifications off): tried '
        'again next time', () async {
      phone.allowed = false;
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      expect(store.saved.shown, isEmpty);
      phone.allowed = true;
      await cards.sync(signedIn: true, tickets: [_ticket(7)]);
      expect(phone.up, 7);
    });

    test('events over a day ago are forgotten', () async {
      store.saved = const EventDayChoices(shown: {3: 1000});
      await cards.sync(signedIn: true, tickets: const []);
      expect(store.saved.shown, isEmpty);
    });
  });

  group('FileEventDayStore', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('event_day'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('on by default; what is written is read back', () async {
      final store = FileEventDayStore(directory: () async => dir);
      expect(await store.read(), EventDayChoices.defaults);
      expect((await store.read()).on, isTrue);
      await store.write(const EventDayChoices(on: false, shown: {7: 99}));
      final again = FileEventDayStore(directory: () async => dir);
      expect(await again.read(), const EventDayChoices(on: false, shown: {7: 99}));
    });

    test('a broken file: the defaults', () async {
      File('${dir.path}/${FileEventDayStore.fileName}')
          .writeAsStringSync('{not json');
      final store = FileEventDayStore(directory: () async => dir);
      expect(await store.read(), EventDayChoices.defaults);
    });
  });

  group('in the app', () {
    late FakeEventDayPlatform phone;
    late MemoryEventDayStore store;
    late _Tickets tickets;
    late ProviderContainer container;

    Future<void> run(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> pump(WidgetTester tester, Widget child,
        {List<SavedTicket> saved = const [], bool canShow = true}) async {
      phone = FakeEventDayPlatform()..canShow = canShow;
      store = MemoryEventDayStore();
      tickets = _Tickets(saved);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          eventDayCardsProvider.overrideWith(
              (ref) => EventDayCards(phone, store, now: () => _morning)),
          eventDayPlatformProvider.overrideWithValue(phone),
          savedTicketsProvider.overrideWith((ref) => tickets),
          isAuthenticatedProvider.overrideWith((ref) => true),
        ],
        child: MaterialApp(home: Scaffold(body: child)),
      ));
      container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
      await run(tester);
    }

    testWidgets('the app opening on the day puts the card up',
        (tester) async {
      await pump(tester, const EventDaySyncScope(child: Text('tabs')),
          saved: [_ticket(7)]);
      expect(phone.up, 7);
    });

    testWidgets('a ticket bought on the day: its card goes up', (tester) async {
      await pump(tester, const EventDaySyncScope(child: Text('tabs')));
      expect(phone.up, isNull);
      tickets.set([_ticket(7)]);
      await run(tester);
      expect(phone.up, 7);
    });

    testWidgets('opening the ticket puts a card put away back up',
        (tester) async {
      final ticketOpen = ValueNotifier(false);
      await pump(
          tester,
          ValueListenableBuilder<bool>(
            valueListenable: ticketOpen,
            builder: (_, open, __) => Column(children: [
              const EventDaySyncScope(child: Text('tabs')),
              if (open) const EventDayOnOpen(eventId: 7, child: Text('ticket')),
            ]),
          ),
          saved: [_ticket(7)]);
      expect(phone.up, 7);
      phone.putAway();
      ticketOpen.value = true;
      await run(tester);
      expect(phone.up, 7);
      expect(phone.calls.where((c) => c == 'start 7'), hasLength(2));
    });

    testWidgets('Settings: on by default; off takes the card down',
        (tester) async {
      await pump(tester, const EventDayRow(), saved: [_ticket(7)]);
      await container.read(eventDayCardsProvider).sync(
          signedIn: true, tickets: [_ticket(7)]);
      await run(tester);
      expect(find.text('Event-day card on the lock screen'), findsOneWidget);
      expect(find.textContaining('never shows the ticket’s code'),
          findsOneWidget);
      final row = find.byKey(EventDayRow.rowKey);
      bool on() => tester.widget<SettingsRow>(row).value!;
      expect(on(), isTrue);
      expect(phone.up, 7);

      await tester.tap(row);
      await run(tester);
      expect(on(), isFalse);
      expect(phone.up, isNull);
      expect(store.saved.on, isFalse);

      // On again: the day's card goes back up.
      await tester.tap(row);
      await run(tester);
      expect(on(), isTrue);
      expect(phone.up, 7);
    });

    testWidgets('Settings: no row where the phone can\'t show the card',
        (tester) async {
      await pump(tester, const EventDayRow(), canShow: false);
      expect(find.byKey(EventDayRow.rowKey), findsNothing);
    });
  });
}

class _Repo implements SavedTicketsRepository {
  _Repo(this.tickets);

  final List<SavedTicket> tickets;

  @override
  Future<List<SavedTicket>> saved() async => tickets;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _Tickets extends SavedTicketsNotifier {
  _Tickets(List<SavedTicket> tickets) : super(_Repo(tickets));

  @override
  Future<void> refresh() async {}

  @override
  Future<void> refreshIfOlderThan(Duration age) async {}

  void set(List<SavedTicket> tickets) => state = tickets;
}
