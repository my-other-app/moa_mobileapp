import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/register_bar_parts.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'event_page_fixtures.dart';
import 'events_fakes.dart';

// An event whose club reviews every registration says how many applied
// ("108 applied": `applied_count`, every registration ever made for it, so
// it never drops), never how many are going or how many seats are left:
// the club decides who gets in. A normal event, and any event from a
// server older than `applied_count`, read exactly as before.

/// `GET /discover/events/7`, its club reviewing registrations when
/// [applied] is given (as the server sends it then).
Map<String, dynamic> _page({
  int? applied,
  bool review = true,
  int going = 1,
  int seatsLeft = 119,
}) {
  final page = discoverEventPage(going: going, seatsLeft: seatsLeft);
  final event = page['event'] as Map<String, dynamic>;
  if (review) event['requires_approval'] = true;
  if (applied != null) event['applied_count'] = applied;
  return page;
}

Future<void> _pumpPage(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
      isAuthenticatedProvider.overrideWithValue(true),
    ],
    child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
  ));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pumpCard(WidgetTester tester, DiscoverEvent event,
    {bool row = false}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: row
            ? DiscoverEventTile(event: event)
            : DiscoverEventCard(event: event),
      ),
    ),
  ));
  await tester.pump();
}

void main() {
  group('reading applied_count', () {
    test('a card keeps it where the club reviews every registration', () {
      DiscoverEvent? card(Map<String, dynamic> extra) =>
          parseEvent({'id': 1, 'name': 'DevFest', 'going': 1, ...extra});
      expect(
          card({'requires_approval': true, 'applied_count': 108})!.appliedCount,
          108);
      expect(
          card({'requires_approval': true, 'applied_count': 0})!.appliedCount,
          0);
      // Anywhere else, or nonsense, or an older server: none.
      expect(card({'applied_count': 108})!.appliedCount, isNull);
      expect(card({'requires_approval': true})!.appliedCount, isNull);
      expect(
          card({'requires_approval': true, 'applied_count': null})!
              .appliedCount,
          isNull);
      expect(
          card({'requires_approval': true, 'applied_count': -2})!.appliedCount,
          isNull);
    });

    test('the event page keeps it, and then has no seats left', () {
      final page = EventPageDetails.fromJson(_page(applied: 108))!;
      expect(page.appliedCount, 108);
      expect(page.going, 1);
      expect(page.seatsLeft, isNull);

      final older = EventPageDetails.fromJson(_page())!;
      expect(older.appliedCount, isNull);
      expect(older.seatsLeft, 119);

      final plain = EventPageDetails.fromJson(_page(review: false))!;
      expect(plain.appliedCount, isNull);
      expect(plain.seatsLeft, 119);
    });
  });

  group('the words', () {
    test('a card says how many applied, else how many are going', () {
      expect(
          peopleLine(const DiscoverEvent(
              id: 1, name: 'x', going: 1, appliedCount: 108)),
          '108 applied');
      expect(peopleLine(const DiscoverEvent(id: 1, name: 'x', appliedCount: 1)),
          '1 applied');
      expect(
          peopleLine(const DiscoverEvent(id: 1, name: 'x', appliedCount: 1200)),
          '1.2k applied');
      expect(
          peopleLine(
              const DiscoverEvent(id: 1, name: 'x', going: 3, appliedCount: 0)),
          isNull);
      expect(peopleLine(const DiscoverEvent(id: 1, name: 'x', going: 34)),
          '34 going');
      expect(peopleLine(const DiscoverEvent(id: 1, name: 'x')), isNull);
    });

    test('the seats line: applied, never the seats left', () {
      expect(
          seatsLine(
              going: 1,
              seatsLeft: 119,
              confirmsEach: true,
              clubName: 'Tinkerhub',
              applied: 108),
          '108 applied');
      expect(seatsLine(going: 0, confirmsEach: true, applied: 1), '1 applied');
      // Nobody yet: the club reviews every registration, no seats.
      expect(
          seatsLine(
              going: 0,
              seatsLeft: 120,
              confirmsEach: true,
              clubName: 'Tinkerhub',
              applied: 0),
          'Tinkerhub reviews every registration');
      // Without applied_count, as before.
      expect(
          seatsLine(
              going: 12,
              seatsLeft: 38,
              confirmsEach: true,
              clubName: 'Tinkerhub'),
          '12 going · 38 seats left');
    });

    test('no "Only 3 seats left" under the button once seats are none', () {
      final now = DateTime(2030, 1, 1);
      final review = registerStateFor(
          now: now, capacity: 120, seatsLeft: null, registrationOpen: true);
      expect(review.kind, RegisterKind.open);
      expect(review.note, isNull);
      final older = registerStateFor(
          now: now, capacity: 120, seatsLeft: 3, registrationOpen: true);
      expect(older.note, 'Only 3 seats left');
    });
  });

  group('the seat meter', () {
    Future<void> meter(WidgetTester tester, SeatsMeter m) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: m)));

    testWidgets('says how many applied, with no bar', (tester) async {
      await meter(
          tester,
          const SeatsMeter(
              going: 1,
              capacity: 120,
              seatsLeft: 119,
              confirmsEach: true,
              clubName: 'Tinkerhub',
              applied: 108));
      expect(find.byKey(SeatsMeter.lineKey), findsOneWidget);
      expect(find.text('108 applied'), findsOneWidget);
      expect(find.byKey(SeatsMeter.meterKey), findsNothing);
      expect(find.textContaining('seats'), findsNothing);
    });

    testWidgets('is as before without it', (tester) async {
      await meter(
          tester, const SeatsMeter(going: 82, capacity: 120, seatsLeft: 38));
      expect(find.byKey(SeatsMeter.meterKey), findsOneWidget);
      expect(find.text('82 going · 38 seats left'), findsOneWidget);
    });
  });

  group('a discover card and row', () {
    testWidgets('say how many applied', (tester) async {
      const event = DiscoverEvent(
          id: 1,
          name: 'DevFest',
          going: 1,
          capacity: 200,
          requiresApproval: true,
          appliedCount: 108);
      await _pumpCard(tester, event);
      expect(find.text('108 applied'), findsOneWidget);
      expect(find.textContaining('going'), findsNothing);
      expect(tester.takeException(), isNull);
      expect(discoverEventLabel(event), contains('108 applied'));

      await _pumpCard(tester, event, row: true);
      expect(find.text('108 applied'), findsOneWidget);
    });

    testWidgets('say how many are going, as before, without it',
        (tester) async {
      await _pumpCard(
          tester,
          const DiscoverEvent(
              id: 1, name: 'DevFest', going: 34, requiresApproval: true));
      expect(find.text('34 going'), findsOneWidget);
      expect(find.textContaining('applied'), findsNothing);
    });
  });

  group('the event page', () {
    testWidgets('says how many applied, with no bar and no seats left',
        (tester) async {
      useFakeApi()
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', _page(applied: 108, seatsLeft: 3));
      await _pumpPage(tester);

      expect(find.byKey(SeatsMeter.lineKey), findsOneWidget);
      expect(find.text('108 applied'), findsOneWidget);
      expect(find.byKey(SeatsMeter.meterKey), findsNothing);
      expect(find.textContaining('seats left'), findsNothing);
      expect(find.textContaining('seat left'), findsNothing);
      // The note by the button stays.
      expect(
          find.text('Tinkerhub reviews every registration and emails tickets '
              'to the people it confirms.'),
          findsWidgets);
    });

    testWidgets('as before from an older server', (tester) async {
      useFakeApi()
        ..on('GET', '/events/info/7', eventInfo())
        ..on('GET', '/discover/events/7', _page(going: 12, seatsLeft: 108));
      await _pumpPage(tester);

      expect(find.text('12 going · 108 seats left'), findsOneWidget);
      expect(find.byKey(SeatsMeter.meterKey), findsOneWidget);
      expect(find.textContaining('applied'), findsNothing);
    });
  });
}
