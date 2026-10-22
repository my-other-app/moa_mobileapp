import 'package:finnet/features/events/domain/networking.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/widgets/networking/people_like_you_card.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'events_fakes.dart';

/// People Like You on the event page: the card while checked in, a word
/// before that, nothing otherwise.

final _now = DateTime(2026, 10, 22, 19, 0);
final _startsLater = _now.add(const Duration(days: 2));
final _startedAnHourAgo = _now.subtract(const Duration(hours: 1));
// A three-hour event that ended two hours ago: its hour after is over too.
final _endedLongAgo = _now.subtract(const Duration(hours: 5));

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Map<String, dynamic> _people(int sharing) => {
      'event_id': 7,
      'event_name': 'Hack Night',
      'window_closes_at': null,
      'visible': true,
      'attendees': [
        for (var i = 0; i < sharing; i++)
          {
            'user_id': 40 + i,
            'name': 'Person $i',
            'shared_interests': [
              {'id': 1, 'name': 'AI'},
            ],
            'match_count': 1,
          },
        {'user_id': 99, 'name': 'Someone', 'match_count': 0},
      ],
    };

/// The card alone, under a router that records where it goes.
Future<List<String>> _pumpCard(
  WidgetTester tester, {
  required RegistrationStatus status,
  required DateTime startsAt,
  bool? networking = true,
}) async {
  final went = <String>[];
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(
        body: PeopleLikeYouCard(
          eventId: 7,
          eventName: 'Hack Night',
          status: status,
          networking: networking,
          startsAt: startsAt,
          durationHours: 3,
          now: () => _now,
        ),
      ),
    ),
    GoRoute(
      path: '/events/:ref/people',
      builder: (_, s) {
        went.add(s.uri.toString());
        return const Scaffold(body: Text('the list'));
      },
    ),
  ]);
  await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
  return went;
}

Finder get _card => find.byKey(PeopleLikeYouCard.openKey);
Finder get _hint => find.byKey(PeopleLikeYouCard.hintKey);

void main() {
  group('the moment, by status and time', () {
    NetworkingMoment at(RegistrationStatus status, DateTime start,
            {bool? networking = true, bool revoked = false}) =>
        networkingMomentFor(
          status: status,
          networking: networking,
          startsAt: start,
          durationHours: 3,
          now: _now,
          revoked: revoked,
        );

    test('not registered, or not paid yet: nothing', () {
      expect(at(RegistrationStatus.none, _startedAnHourAgo),
          NetworkingMoment.none);
      expect(at(RegistrationStatus.awaitingPayment, _startedAnHourAgo),
          NetworkingMoment.none);
    });

    test('registered: a word before, check in during, nothing after', () {
      expect(at(RegistrationStatus.registered, _startsLater),
          NetworkingMoment.beforeEvent);
      expect(at(RegistrationStatus.registered, _startedAnHourAgo),
          NetworkingMoment.checkInNow);
      expect(at(RegistrationStatus.registered, _endedLongAgo),
          NetworkingMoment.none);
    });

    test('checked in: open until an hour after the end', () {
      expect(at(RegistrationStatus.attended, _startedAnHourAgo),
          NetworkingMoment.open);
      // Ended an hour ago less a minute: still its hour after.
      final justEnded = _now.subtract(const Duration(hours: 3, minutes: 59));
      expect(at(RegistrationStatus.attended, justEnded), NetworkingMoment.open);
      expect(at(RegistrationStatus.attended, _endedLongAgo),
          NetworkingMoment.none);
    });

    test("an event without it, or a revoked ticket: nothing", () {
      expect(
          at(RegistrationStatus.attended, _startedAnHourAgo, networking: false),
          NetworkingMoment.none);
      expect(at(RegistrationStatus.attended, _startedAnHourAgo, revoked: true),
          NetworkingMoment.none);
    });

    test('a server that does not say: the list for someone in, no promises',
        () {
      expect(
          at(RegistrationStatus.attended, _startedAnHourAgo, networking: null),
          NetworkingMoment.open);
      expect(at(RegistrationStatus.registered, _startsLater, networking: null),
          NetworkingMoment.none);
    });

    test('no length: closed, as the server keeps it', () {
      expect(networkingClosesAt(_startedAnHourAgo, null), isNull);
      expect(networkingClosesAt(_startedAnHourAgo, 0), isNull);
      expect(networkingClosesAt(_startedAnHourAgo, 2.5),
          _startedAnHourAgo.add(const Duration(hours: 3, minutes: 30)));
    });
  });

  group('the card', () {
    testWidgets('not registered: nothing', (tester) async {
      useFakeApi();
      await _pumpCard(tester,
          status: RegistrationStatus.none, startsAt: _startedAnHourAgo);
      expect(_card, findsNothing);
      expect(_hint, findsNothing);
    });

    testWidgets('registered, before the event: check in on the day',
        (tester) async {
      final api = useFakeApi();
      await _pumpCard(tester,
          status: RegistrationStatus.registered, startsAt: _startsLater);
      expect(find.text('On the day, check in to see who shares your interests.'),
          findsOneWidget);
      expect(_card, findsNothing);
      // Nothing asked of the server for a word.
      expect(api.requests, isEmpty);
    });

    testWidgets('registered, during it, not checked in: check in at the door',
        (tester) async {
      useFakeApi();
      await _pumpCard(tester,
          status: RegistrationStatus.registered, startsAt: _startedAnHourAgo);
      expect(
          find.text(
              'Check in at the door to meet people who share your interests.'),
          findsOneWidget);
      expect(_card, findsNothing);
    });

    testWidgets('checked in and on: how many share, and the way in',
        (tester) async {
      useFakeApi().on('GET', '/events/7/networking', _people(4));
      final went = await _pumpCard(tester,
          status: RegistrationStatus.attended, startsAt: _startedAnHourAgo);

      expect(find.text('People like you'), findsOneWidget);
      expect(find.text('4 people here share your interests'), findsOneWidget);
      await tester.tap(_card);
      await _settle(tester);
      expect(went, ['/events/7/people']);
      expect(find.text('the list'), findsOneWidget);
    });

    testWidgets('checked in, nobody sharing yet: it says so', (tester) async {
      useFakeApi().on('GET', '/events/7/networking', _people(0));
      await _pumpCard(tester,
          status: RegistrationStatus.attended, startsAt: _startedAnHourAgo);
      expect(
          find.text('No one here shares your interests yet'), findsOneWidget);
    });

    testWidgets('after it closes: nothing, checked in or not', (tester) async {
      final api = useFakeApi();
      await _pumpCard(tester,
          status: RegistrationStatus.attended, startsAt: _endedLongAgo);
      expect(_card, findsNothing);
      expect(_hint, findsNothing);
      await _pumpCard(tester,
          status: RegistrationStatus.registered, startsAt: _endedLongAgo);
      expect(_card, findsNothing);
      expect(_hint, findsNothing);
      expect(api.requests, isEmpty);
    });

    testWidgets('the event turns out not to have it: no dead end',
        (tester) async {
      useFakeApi().on(
          'GET',
          '/events/7/networking',
          {
            'message': "Networking isn't available for this event.",
            'error_code': 'NETWORKING_UNAVAILABLE',
          },
          status: 403);
      await _pumpCard(tester,
          status: RegistrationStatus.attended,
          startsAt: _startedAnHourAgo,
          networking: null);
      expect(_card, findsNothing);
    });
  });

  group('on the event page', () {
    Map<String, dynamic> info(
            {required bool registered,
            bool attended = false,
            required DateTime start,
            bool? networking = true}) =>
        {
          'id': 7,
          'name': 'Hack Night',
          'slug': 'hack-night',
          'poster': null,
          'event_datetime': start.toUtc().toIso8601String(),
          'duration': 3,
          'location_name': 'CET',
          'has_fee': false,
          'reg_fee': 0,
          'has_prize': false,
          'is_online': false,
          'reg_startdate': '2020-01-01T00:00:00Z',
          'reg_enddate': null,
          'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub', 'logo': {}},
          'category': {'id': 1, 'name': 'Tech'},
          'additional_details': const [],
          'rating': 0,
          'total_rating': 0,
          'is_registered': registered,
          'is_attended': attended,
          'is_paid': registered ? true : null,
          'ticket_url': registered ? 'https://myotherapp.in/tickets/T-1' : null,
          if (registered) 'networking': networking,
        };

    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
        ],
        child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
      ));
      await _settle(tester);
    }

    testWidgets('checked in and on: the card, near the top', (tester) async {
      final now = DateTime.now();
      useFakeApi()
        ..on(
            'GET',
            '/events/info/7',
            info(
                registered: true,
                attended: true,
                start: now.subtract(const Duration(hours: 1))))
        ..on('GET', '/events/7/networking', _people(2));
      await pumpPage(tester);

      expect(_card, findsOneWidget);
      expect(find.text('2 people here share your interests'), findsOneWidget);
      // Above the event's details, not under the congratulations.
      expect(tester.getTopLeft(_card).dy,
          lessThan(tester.getTopLeft(find.text('Date of Event')).dy));
      // The old button is gone.
      expect(find.text('Discover attendees who share your interests'),
          findsNothing);
    });

    testWidgets('registered for one coming up: the word for the day',
        (tester) async {
      useFakeApi().on(
          'GET',
          '/events/info/7',
          info(
              registered: true,
              start: DateTime.now().add(const Duration(days: 3))));
      await pumpPage(tester);

      expect(_hint, findsOneWidget);
      expect(_card, findsNothing);
    });

    testWidgets('an event without it says nothing about it', (tester) async {
      useFakeApi().on(
          'GET',
          '/events/info/7',
          info(
              registered: true,
              start: DateTime.now().add(const Duration(days: 3)),
              networking: false));
      await pumpPage(tester);

      expect(_hint, findsNothing);
      expect(_card, findsNothing);
    });

    testWidgets('not registered: nothing', (tester) async {
      useFakeApi().on(
          'GET',
          '/events/info/7',
          info(
              registered: false,
              start: DateTime.now().subtract(const Duration(hours: 1))));
      await pumpPage(tester);

      expect(_hint, findsNothing);
      expect(_card, findsNothing);
    });
  });
}
