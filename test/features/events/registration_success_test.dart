// "WOOHOO! YOU'RE OFFICIALLY IN!": the screen a registration ends on, which
// moves on by itself into the ticket, in place of itself.

import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/features/auth/presentation/pages/reg_successfull_page.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'events_fakes.dart';

/// A screen the success page is opened over, so where Back leads can be
/// seen.
Future<void> _openOver(WidgetTester tester, RegSuccessfullPage page) async {
  tester.view
    ..physicalSize = const Size(800, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => page)),
          child: const Text('the form'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('the form'));
  // The page's own entrance; not settle: the spinner turns for good.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Past the three seconds and through the ticket's entrance.
Future<void> _waitForTicket(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

const _heading = "WOOHOO! YOU'RE OFFICIALLY IN! 🎉🔥";

/// An auth state set by hand, without the real notifier's storage read.
class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  setUp(useFakeApi);

  testWidgets('says they are in, and that the ticket is on its way',
      (tester) async {
    await _openOver(
        tester, const RegSuccessfullPage(ticketId: 'T-1', eventName: 'Hack'));

    expect(find.text(_heading), findsOneWidget);
    expect(find.text('Hang tight while we whip up your ticket'),
        findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(TicketViewPage), findsNothing);
  });

  testWidgets(
      'after three seconds the ticket takes its place: the event, its date '
      'and the holder', (tester) async {
    await _openOver(
      tester,
      const RegSuccessfullPage(
        ticketId: 'T-1',
        eventName: 'Hack Night',
        eventId: 7,
        eventDateTime: '2030-12-01T10:00:00Z',
        fullName: 'Asha Menon',
      ),
    );
    // Not yet: the screen is read first.
    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(TicketViewPage), findsNothing);
    expect(find.text(_heading), findsOneWidget);

    await _waitForTicket(tester);

    final ticket = tester.widget<TicketViewPage>(find.byType(TicketViewPage));
    expect(ticket.ticketId, 'T-1');
    expect(ticket.eventName, 'Hack Night');
    // In the phone's time: the ticket shows its hour and day.
    expect(ticket.eventDateTime!.toUtc(), DateTime.utc(2030, 12, 1, 10));
    expect(ticket.eventDateTime!.isUtc, isFalse);
    expect(ticket.ticketHolderName, 'Asha Menon');
    expect(find.text(_heading), findsNothing);
  });

  testWidgets('Back from the ticket leads past the success screen, not to it',
      (tester) async {
    await _openOver(tester, const RegSuccessfullPage(ticketId: 'T-1'));
    await _waitForTicket(tester);
    expect(find.byType(TicketViewPage), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('the form'), findsOneWidget);
    expect(find.text(_heading), findsNothing);
    expect(find.byType(TicketViewPage), findsNothing);
  });

  testWidgets(
      'without a name or a readable date, the ticket still opens: "Event", '
      'and no date', (tester) async {
    await _openOver(
      tester,
      const RegSuccessfullPage(ticketId: 'T-1', eventDateTime: 'soon'),
    );
    await _waitForTicket(tester);

    final ticket = tester.widget<TicketViewPage>(find.byType(TicketViewPage));
    expect(ticket.eventName, 'Event');
    expect(ticket.eventDateTime, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'left just before the three seconds -- Back still sliding the screen '
      'away -- it opens nothing afterwards', (tester) async {
    await _openOver(tester, const RegSuccessfullPage(ticketId: 'T-1'));
    // 1 s gone in its entrance; Back at 2.9 s.
    await tester.pump(const Duration(milliseconds: 1900));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('the form'), findsOneWidget);
    expect(find.byType(TicketViewPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      "the app's /events/registration-success hands the form's answer to "
      'the screen', (tester) async {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => _FakeAuth(
          const AuthState(accessToken: 'token', isInitialized: true))),
      routerObserversProvider.overrideWithValue(const []),
    ]);
    addTearDown(container.dispose);
    final router = container.read(routerProvider);
    await tester.pumpWidget(const SizedBox());
    final context = tester.element(find.byType(SizedBox));

    // What the registration form passes, from the server's answer.
    final matches = router.configuration.findMatch(
      Uri.parse('/events/registration-success'),
      extra: const {
        'ticketId': 'T-1',
        'eventName': 'Hack Night',
        'eventId': 7,
        'eventDateTime': '2030-12-01T10:00:00Z',
        'fullName': 'Asha Menon',
      },
    );
    final leaf = matches.matches.last;
    // The shell's match holds the route under My events.
    final match = leaf is ShellRouteMatch ? leaf.matches.last : leaf;
    final route = match.route as GoRoute;
    expect(route.name, AppRoutes.eventRegistrationSuccess);

    final page = route.builder!(
        context, match.buildState(router.configuration, matches));
    expect(
        page,
        isA<RegSuccessfullPage>()
            .having((p) => p.ticketId, 'ticketId', 'T-1')
            .having((p) => p.eventName, 'eventName', 'Hack Night')
            .having((p) => p.eventId, 'eventId', 7)
            .having((p) => p.eventDateTime, 'eventDateTime',
                '2030-12-01T10:00:00Z')
            .having((p) => p.fullName, 'fullName', 'Asha Menon'));
  });
}
