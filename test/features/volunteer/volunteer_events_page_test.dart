import 'dart:async';

import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/volunteer/data/repositories/volunteer_repository_impl.dart';
import 'package:finnet/features/volunteer/presentation/pages/volunteer_events_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'volunteer_fakes.dart';

/// "My volunteer events", from Settings: the events the person checks
/// people in at, each opening the scanner for that event.
void main() {
  late List<(String, Object?)> opened;

  Future<void> pump(WidgetTester tester, FakeVolunteerRepository volunteer) async {
    // Wide: the test font draws every glyph as wide as it is tall, and the
    // card's tag row (date, fee, places) would overflow a phone's width.
    tester.view
      ..physicalSize = const Size(800, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    opened = [];
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const VolunteerEventsPage()),
      GoRoute(
        path: '/volunteer/scanner/:eventId',
        builder: (_, state) {
          opened.add((state.uri.toString(), state.extra));
          return const Scaffold(body: Text('the scanner'));
        },
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [volunteerRepositoryProvider.overrideWithValue(volunteer)],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pump();
  }

  testWidgets('asks for the events once, with a spinner until they come',
      (tester) async {
    final volunteer = FakeVolunteerRepository(events: [volunteerEvent()])
      ..hold = Completer<void>();
    await pump(tester, volunteer);

    expect(find.text('MY VOLUNTEER EVENTS'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(volunteer.calls, ['myEvents']);

    volunteer.hold!.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Hack Night 04'), findsOneWidget);
    expect(volunteer.calls, ['myEvents']);
  });

  testWidgets('each event: its name, club, date, fee and places, and SCAN',
      (tester) async {
    await pump(
      tester,
      FakeVolunteerRepository(events: [
        volunteerEvent(),
        volunteerEvent(
          id: 9,
          name: 'Design Jam',
          club: 'Pixel Club',
          hasFee: false,
          maxParticipants: null,
        ),
      ]),
    );
    await tester.pump();

    expect(find.text('Hack Night 04'), findsOneWidget);
    expect(find.text('Makers'), findsOneWidget);
    expect(find.text('Paid Event'), findsOneWidget);
    expect(find.text('120 spots'), findsOneWidget);
    expect(find.text('Oct 11, 2026'), findsNWidgets(2));

    expect(find.text('Design Jam'), findsOneWidget);
    expect(find.text('Pixel Club'), findsOneWidget);
    expect(find.text('Free Event'), findsOneWidget);
    // No limit, no count.
    expect(find.textContaining('spots'), findsOneWidget);

    expect(find.text('SCAN'), findsNWidgets(2));
  });

  testWidgets('tapping an event opens the scanner for that event',
      (tester) async {
    await pump(
      tester,
      FakeVolunteerRepository(events: [
        volunteerEvent(),
        volunteerEvent(id: 9, name: 'Design Jam', club: 'Pixel Club'),
      ]),
    );
    await tester.pump();

    await tester.tap(find.text('Design Jam'));
    await tester.pumpAndSettle();

    expect(find.text('the scanner'), findsOneWidget);
    expect(opened.single.$1, '/volunteer/scanner/9');
    expect(opened.single.$2, {'eventName': 'Design Jam', 'clubName': 'Pixel Club'});
  });

  testWidgets('none yet: says so, with nothing to tap', (tester) async {
    await pump(tester, FakeVolunteerRepository());
    await tester.pump();

    expect(find.text('No Volunteer Events'), findsOneWidget);
    expect(
        find.text(
            "You haven't been assigned as a volunteer for any events yet."),
        findsOneWidget);
    expect(find.text('SCAN'), findsNothing);
  });

  testWidgets("a failure shows the server's reason, and Retry asks again",
      (tester) async {
    final volunteer = FakeVolunteerRepository(
      failure: const NetworkFailure(message: 'No internet connection'),
    );
    await pump(tester, volunteer);
    await tester.pump();

    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    volunteer
      ..failure = null
      ..events = [volunteerEvent()];
    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(volunteer.calls, ['myEvents', 'myEvents']);
    expect(find.text('No internet connection'), findsNothing);
    expect(find.text('Hack Night 04'), findsOneWidget);
  });
}
