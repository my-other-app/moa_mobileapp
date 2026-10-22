import 'package:dio/dio.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/data/ticket_images.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/presentation/pages/upcoming_events_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';

/// The saved tickets, counting how often they are brought up to date.
class _Tickets extends SavedTicketsRepository {
  _Tickets()
      : super(
          dio: Dio(),
          local: SavedTicketsLocalDataSource(MemoryStorage()),
        );

  int refreshes = 0;

  @override
  Future<List<SavedTicket>> saved() async => const [];

  @override
  Future<List<SavedTicket>> refresh() async {
    refreshes++;
    return const [];
  }
}

Future<void> _pumpPage(WidgetTester tester, _Tickets tickets) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      savedTicketsRepositoryProvider.overrideWithValue(tickets),
      ticketImagesProvider.overrideWithValue(MemoryTicketImages()),
    ],
    child: const MaterialApp(home: Scaffold(body: UpcomingEventsPage())),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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
    await _pumpPage(tester, _Tickets());

    expect(find.text('FINISH PAYMENT'), findsOneWidget);
    expect(find.text('Payment due'), findsOneWidget);
    expect(find.text('VIEW TICKET'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
    expect(find.text('Unknown Organizer'), findsOneWidget);
  });

  testWidgets(
      'the list from the server saves its tickets for the door, in the '
      'background', (tester) async {
    // A registration made since the app started was on this list but not
    // on the phone: offline at the door it opened as "Your ticket", with
    // no date, no place and no design.
    useFakeApi().on(
      'GET',
      '/events/list?is_registered=true&is_ended=false&offset=0&limit=10',
      {
        'items': [_event(2, isPaid: true, club: {'id': 3, 'name': 'Tinkerhub'})],
      },
    );
    final tickets = _Tickets();
    await _pumpPage(tester, tickets);

    expect(find.text('VIEW TICKET'), findsOneWidget);
    expect(tickets.refreshes, 1);
  });
}
