import 'package:finnet/features/events/presentation/pages/upcoming_events_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

Map<String, dynamic> _event(int id, {required Object? isPaid, Object? club}) =>
    {
      'id': id,
      'name': 'Event $id',
      'slug': 'event-$id',
      'club': club,
      'category': {'id': 1, 'name': 'Tech'},
      'is_online': false,
      'has_fee': true,
      'duration': null,
      'event_datetime': '2030-12-01T10:00:00Z',
      'ticket_url': 'https://myotherapp.in/tickets/T-$id',
      'is_paid': isPaid,
    };

void main() {
  testWidgets(
      'an unpaid registration offers the payment; a paid one its ticket; '
      'an event without a club or a length still draws', (tester) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    useFakeApi().on(
      'GET',
      '/events/list?is_registered=true&is_ended=false&offset=0&limit=10',
      {
        'items': [
          _event(1, isPaid: false, club: null),
          _event(2, isPaid: true, club: {'id': 3, 'name': 'Tinkerhub'}),
        ],
      },
    );
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: UpcomingEventsPage())));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('FINISH PAYMENT'), findsOneWidget);
    expect(find.text('Payment due'), findsOneWidget);
    expect(find.text('VIEW TICKET'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
    expect(find.text('Unknown Organizer'), findsOneWidget);
  });
}
