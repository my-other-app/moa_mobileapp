import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
