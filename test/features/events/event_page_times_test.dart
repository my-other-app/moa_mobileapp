import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'event_page_fixtures.dart';
import 'events_fakes.dart';

// The event page's "Date of Event" and "Time of Event" are the phone's own
// clock and calendar. The API sends `2026-11-28T09:00:00+05:30` for DevFest;
// Dart reads a time with an offset as UTC, and the tile read its hour: 3:30
// AM. Run with TZ=UTC as well as in India: the tiles follow the zone.

/// DevFest's `event_datetime`, as the API sends it.
const _devFest = '2026-11-28T09:00:00+05:30';

/// The machine running the tests keeps India time (`TZ=Asia/Kolkata`).
final _inIndia = DateTime(2026, 11, 28).timeZoneOffset ==
    const Duration(hours: 5, minutes: 30);

Future<void> _pumpPage(WidgetTester tester, String start) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final page = discoverEventPage(capacity: null, seatsLeft: null);
  (page['event'] as Map<String, dynamic>)['starts_at'] = start;
  useFakeApi()
    ..on('GET', '/events/info/7', eventInfo(start: start))
    ..on('GET', '/discover/events/7', page);
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

/// The value under [title] in the page's info grid.
Finder _tile(String title, String value) => find.descendant(
      of: find
          .ancestor(of: find.text(title), matching: find.byType(Column))
          .first,
      matching: find.text(value),
    );

void main() {
  group('the labels', () {
    test('a time of day, on the phone\'s clock', () {
      expect(eventTimeLabel(DateTime(2026, 11, 28, 9)), '9:00 AM');
      expect(eventTimeLabel(DateTime(2026, 11, 28, 0, 5)), '12:05 AM');
      expect(eventTimeLabel(DateTime(2026, 11, 28, 12)), '12:00 PM');
      expect(eventTimeLabel(DateTime(2026, 11, 28, 18, 30)), '6:30 PM');
      // A UTC time is read as the phone would say it, never as UTC.
      final utc = DateTime.utc(2026, 11, 28, 3, 30);
      expect(eventTimeLabel(utc), eventTimeLabel(utc.toLocal()));
    });

    test('a day, on the phone\'s calendar', () {
      expect(eventDateLabel(DateTime(2026, 11, 28, 2)), '28-11-2026');
      final utc = DateTime.utc(2026, 11, 27, 20, 30);
      expect(eventDateLabel(utc), eventDateLabel(utc.toLocal()));
    });

    test('in India: DevFest at 9:00 AM, and 2 AM on its own day', () {
      expect(eventTimeLabel(DateTime.parse(_devFest)), '9:00 AM');
      expect(eventDateLabel(DateTime.parse(_devFest)), '28-11-2026');
      // 20:30 UTC on the 27th.
      final two = DateTime.parse('2026-11-28T02:00:00+05:30');
      expect(eventTimeLabel(two), '2:00 AM');
      expect(eventDateLabel(two), '28-11-2026');
    }, skip: _inIndia ? false : 'reads the clock of a phone in India');

    test('a calendar entry from local times still says the right moment', () {
      final start = DateTime.parse(_devFest).toLocal();
      final entry =
          calendarEntryFor(name: 'DevFest', startsAt: start, durationHours: 8)!;
      expect(googleCalendarUri(entry).queryParameters['dates'],
          '20261128T033000Z/20261128T113000Z');
    });
  });

  group('the event page', () {
    testWidgets('"Time of Event" and "Date of Event" are the phone\'s',
        (tester) async {
      await _pumpPage(tester, _devFest);

      final local = DateTime.utc(2026, 11, 28, 3, 30).toLocal();
      expect(_tile('Time of Event', eventTimeLabel(local)), findsOneWidget);
      expect(_tile('Date of Event', eventDateLabel(local)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('in India, DevFest is at 9:00 AM on 28-11-2026, not 3:30 AM',
        (tester) async {
      await _pumpPage(tester, _devFest);

      expect(_tile('Time of Event', '9:00 AM'), findsOneWidget);
      expect(_tile('Date of Event', '28-11-2026'), findsOneWidget);
      expect(find.text('3:30 AM'), findsNothing);
    }, skip: !_inIndia);

    testWidgets('in India, an event at 2 AM is on its own day', (tester) async {
      await _pumpPage(tester, '2026-11-28T02:00:00+05:30');

      expect(_tile('Time of Event', '2:00 AM'), findsOneWidget);
      expect(_tile('Date of Event', '28-11-2026'), findsOneWidget);
      expect(find.text('27-11-2026'), findsNothing);
    }, skip: !_inIndia);
  });
}
