import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'events_fakes.dart';

Future<void> _pumpTicket(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(
    home: TicketViewPage(ticketId: 'T-1', eventName: 'Hack Night'),
  ));
  // The glow animates forever: pump, don't settle.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  // The rendered ticket isn't there (404): the drawn card stands in.
  setUp(useFakeApi);

  group('Add to Wallet', () {
    testWidgets('is not offered on Android', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _pumpTicket(tester);

      expect(find.text('Add to Wallet'), findsNothing);
      expect(find.text('Download'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('is offered on iOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _pumpTicket(tester);

      expect(find.text('Add to Wallet'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('Your team, from the ticket', () {
    Future<List<String>> pumpWithEvent(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final went = <String>[];
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const TicketViewPage(
              ticketId: 'T-1', eventName: 'Hack Night', eventId: 7),
        ),
        GoRoute(
          path: '/events/:id/compete',
          builder: (_, s) {
            went.add(s.uri.toString());
            return const Scaffold(body: Text('your team'));
          },
        ),
      ]);
      await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: router)));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return went;
    }

    testWidgets('an event with a competition: the way to the team',
        (tester) async {
      useFakeApi().on('GET', '/events/7/competition/leaderboard',
          {'event_id': 7, 'enabled': true, 'public': false, 'rows': []});
      final went = await pumpWithEvent(tester);

      final team = find.byKey(TicketViewPage.teamKey);
      await tester.ensureVisible(team);
      await tester.pump();
      await tester.tap(team);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(went, ['/events/7/compete']);
    });

    testWidgets('none: nothing', (tester) async {
      useFakeApi().on('GET', '/events/7/competition/leaderboard',
          {'event_id': 7, 'enabled': false, 'public': false, 'rows': []});
      await pumpWithEvent(tester);
      expect(find.byKey(TicketViewPage.teamKey), findsNothing);
    });
  });
}
