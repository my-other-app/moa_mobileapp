import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/registration_countdown.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

/// A clock the test moves.
class _Clock {
  _Clock(this.time);
  DateTime time;
  DateTime now() => time;
  void advance(Duration by) => time = time.add(by);
}

const _countdown = ValueKey('registration-countdown');

String _shown(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(_countdown)).data!;

void main() {
  group('the countdown line', () {
    final now = DateTime(2030, 11, 1, 9);

    test('days, then hours, minutes and seconds, two digits each', () {
      expect(
        registrationCountdownText(
            now.add(const Duration(days: 2, hours: 4, minutes: 5, seconds: 6)),
            now),
        'Registration closes in 2 days 04 hrs 05 mins 06 secs',
      );
      expect(
        registrationCountdownText(
            now.add(const Duration(days: 1, minutes: 30)), now),
        'Registration closes in 1 day 00 hrs 30 mins 00 secs',
      );
      expect(
        registrationCountdownText(
            now.add(const Duration(hours: 3, seconds: 9)), now),
        'Registration closes in 03 hrs 00 mins 09 secs',
      );
      expect(registrationCountdownText(now, now), 'Registration Closed');
      expect(
        registrationCountdownText(
            now.subtract(const Duration(minutes: 1)), now),
        'Registration Closed',
      );
    });
  });

  group('RegistrationCountdown', () {
    testWidgets('shows the time left at once, then ticks every second',
        (tester) async {
      final clock = _Clock(DateTime(2030, 11, 1, 9));
      await tester.pumpWidget(MaterialApp(
        home: RegistrationCountdown(
          closesAt: clock.time.add(const Duration(hours: 1, seconds: 3)),
          onClosed: () {},
          now: clock.now,
        ),
      ));

      // Not an empty box for the first second.
      expect(_shown(tester), 'Registration closes in 01 hrs 00 mins 03 secs');

      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(_shown(tester), 'Registration closes in 01 hrs 00 mins 02 secs');
    });

    testWidgets(
        'only the line rebuilds as it ticks: what holds it is built once',
        (tester) async {
      final clock = _Clock(DateTime(2030, 11, 1, 9));
      var pageBuilds = 0;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          pageBuilds++;
          return Column(children: [
            const Text('Hack Night'),
            RegistrationCountdown(
              closesAt: clock.time.add(const Duration(minutes: 10)),
              onClosed: () {},
              now: clock.now,
            ),
          ]);
        }),
      ));
      expect(pageBuilds, 1);

      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));
      }

      expect(_shown(tester), 'Registration closes in 00 hrs 09 mins 55 secs');
      expect(pageBuilds, 1, reason: 'the page is not rebuilt every second');
    });

    testWidgets(
        'at the deadline it says closed, tells the page once, and stops',
        (tester) async {
      final clock = _Clock(DateTime(2030, 11, 1, 9));
      var closed = 0;
      await tester.pumpWidget(MaterialApp(
        home: RegistrationCountdown(
          closesAt: clock.time.add(const Duration(seconds: 2)),
          onClosed: () => closed++,
          now: clock.now,
        ),
      ));

      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(closed, 0);
      clock.advance(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(_shown(tester), 'Registration Closed');
      expect(closed, 1);

      clock.advance(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      expect(closed, 1, reason: 'the timer stopped');
    });

    testWidgets('a deadline already passed tells the page after the frame',
        (tester) async {
      final clock = _Clock(DateTime(2030, 11, 1, 9));
      var closed = 0;
      await tester.pumpWidget(MaterialApp(
        home: RegistrationCountdown(
          closesAt: clock.time.subtract(const Duration(seconds: 1)),
          onClosed: () => closed++,
          now: clock.now,
        ),
      ));
      await tester.pump();

      expect(_shown(tester), 'Registration Closed');
      expect(closed, 1);
      await tester.pump(const Duration(seconds: 5));
      expect(closed, 1);
    });

    testWidgets('taken off the screen, it stops ticking', (tester) async {
      final clock = _Clock(DateTime(2030, 11, 1, 9));
      var closed = 0;
      await tester.pumpWidget(MaterialApp(
        home: RegistrationCountdown(
          closesAt: clock.time.add(const Duration(seconds: 2)),
          onClosed: () => closed++,
          now: clock.now,
        ),
      ));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      clock.advance(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 5));

      expect(closed, 0);
      expect(tester.takeException(), isNull);
    });
  });

  group('on the event page', () {
    Map<String, dynamic> info(DateTime regEnd) => {
          'id': 7,
          'name': 'Hack Night',
          'slug': 'hack-night',
          'event_datetime': '2030-12-01T10:00:00Z',
          'duration': 2.5,
          'location_name': 'CET',
          'has_fee': false,
          'reg_fee': 0,
          'has_prize': false,
          'is_online': false,
          'reg_startdate': '2020-01-01T00:00:00Z',
          'reg_enddate': regEnd.toUtc().toIso8601String(),
          'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub'},
          'category': {'id': 1, 'name': 'Tech'},
          'additional_details': <dynamic>[],
          'is_registered': false,
          'is_attended': false,
        };

    Future<void> pumpPage(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1080, 2400)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
        ],
        child: const MaterialApp(home: IndividualEventPage(eventId: 7)),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('open registration shows the countdown over REGISTER NOW',
        (tester) async {
      useFakeApi().on('GET', '/events/info/7',
          info(DateTime.now().add(const Duration(days: 3, hours: 2))));
      await pumpPage(tester);

      expect(_shown(tester), startsWith('Registration closes in 3 days 0'));
      expect(find.widgetWithText(FilledButton, 'REGISTER NOW'), findsOneWidget);
    });

    testWidgets(
        'when the deadline passes on the page, the button closes and the '
        'countdown goes', (tester) async {
      // The page's clock is the real one: a deadline a moment away.
      useFakeApi().on('GET', '/events/info/7',
          info(DateTime.now().add(const Duration(seconds: 2))));
      await pumpPage(tester);
      expect(find.byKey(_countdown), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'REGISTER NOW'), findsOneWidget);

      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 2500)));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.byKey(_countdown), findsNothing);
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'REGISTRATION CLOSED'));
      expect(button.onPressed, isNull);
    });

    testWidgets('a deadline already passed shows no countdown', (tester) async {
      useFakeApi().on('GET', '/events/info/7',
          info(DateTime.now().subtract(const Duration(hours: 1))));
      await pumpPage(tester);

      expect(find.byKey(_countdown), findsNothing);
      expect(find.widgetWithText(FilledButton, 'REGISTRATION CLOSED'),
          findsOneWidget);
    });
  });
}
