import 'dart:convert';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/data/ticket_images.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/features/events/presentation/pages/upcoming_events_page.dart';
import 'package:finnet/features/events/presentation/providers/event_cancellation_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:finnet/features/events/presentation/widgets/ticketing/cancelled_notice.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';

const _list =
    '/events/list?is_registered=true&is_ended=false&offset=0&limit=10';

Map<String, dynamic> _row(int id, {bool paid = true}) => {
      'id': id,
      'name': 'Event $id',
      'slug': 'event-$id',
      'club': {'id': 3, 'name': 'Tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'is_online': false,
      'has_fee': true,
      'duration': 2,
      'event_datetime': '2030-12-01T10:00:00Z',
      'ticket_id': 'T-$id',
      'ticket_url': 'https://myotherapp.in/tickets/T-$id',
      'is_paid': paid,
    };

Map<String, dynamic> _cancelledPage(int id, String reason) => {
      'event': {
        'id': id,
        'status': 'cancelled',
        'registration_open': false,
        'cancellation': {'reason': reason},
      },
    };

/// The saved tickets, in memory, read through the fake API.
SavedTicketsRepository _tickets([Map<String, String>? stored]) =>
    SavedTicketsRepository(
      dio: APIService.instance.dio,
      local: SavedTicketsLocalDataSource(MemoryStorage(stored)),
    );

Future<void> _pumpFrames(WidgetTester tester, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late RouteAdapter api;

  setUp(() {
    api = useFakeApi();
    EventCancellationLookups.instance.clear();
  });

  group('the ticket', () {
    testWidgets('a cancelled event: no QR, the reason and the refund',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: TicketViewPage(
          ticketId: 'T-1',
          eventName: 'Hack Night',
          cancellation: EventCancellation(reason: 'The venue flooded.'),
          paid: true,
        ),
      ));
      await _pumpFrames(tester, 4);

      expect(find.byKey(CancelledNotice.noticeKey), findsOneWidget);
      expect(find.text('The organisers said: The venue flooded.'),
          findsOneWidget);
      expect(find.text(EventCancellation.refundDetail), findsOneWidget);
      expect(find.byKey(TicketViewPage.qrKeyFor('T-1')), findsNothing);
      expect(find.text('Download'), findsNothing);
      expect(api.sent('GET', TicketImages.pathFor('T-1')), isEmpty,
          reason: 'nothing to fetch for a door that won\'t open');
    });

    testWidgets('the ticket type shows with the ticket', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: TicketViewPage(
            ticketId: 'T-1', eventName: 'Hack Night', ticketType: 'VIP'),
      ));
      await _pumpFrames(tester, 4);
      // The rendered design is missing (404): the drawn card names it.
      expect(find.text('VIP'), findsOneWidget);
    });

    testWidgets(
        'from the saved tickets: its type, and whether the event was called off',
        (tester) async {
      api.on('GET', '/discover/events/7', _cancelledPage(7, 'Speaker unwell.'));
      const saved = SavedTicket(
        code: 'T-7',
        eventId: 7,
        eventName: 'Hack Night',
        ticketType: 'Early bird',
        paid: true,
      );
      final repo = _tickets({
        SavedTicketsLocalDataSource.key: jsonEncode([saved.toJson()]),
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          savedTicketsRepositoryProvider.overrideWithValue(repo),
          ticketImagesProvider.overrideWithValue(MemoryTicketImages()),
        ],
        child: const MaterialApp(home: SavedTicketPage(code: 'T-7')),
      ));
      await _pumpFrames(tester);

      final page = tester.widget<TicketViewPage>(find.byType(TicketViewPage));
      expect(page.ticketType, 'Early bird');
      expect(page.paid, isTrue);
      expect(page.cancellation?.reason, 'Speaker unwell.');
      expect(find.text(EventCancellation.refundDetail), findsOneWidget);
    });
  });

  group('the saved tickets keep a ticket type the list does not say', () {
    test('told after registering, kept through a refresh', () async {
      api.on('GET', '/events/list', {
        'items': [_row(1)],
      });
      final repo = _tickets();
      final notifier = SavedTicketsNotifier(repo);
      addTearDown(notifier.dispose);
      await notifier.loaded;

      notifier.rememberTicketType('T-1', 'VIP');
      await notifier.refresh();

      expect(notifier.byCode('T-1')?.ticketType, 'VIP');
      // Kept on the phone too.
      expect((await repo.saved()).single.ticketType, 'VIP');

      // Refreshed again, by a notifier that was never told: still there.
      final later = SavedTicketsNotifier(repo);
      addTearDown(later.dispose);
      await later.loaded;
      await later.refresh();
      expect(later.byCode('T-1')?.ticketType, 'VIP');
    });
  });

  group('My events', () {
    Future<void> pumpPage(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          savedTicketsRepositoryProvider.overrideWithValue(_tickets()),
          ticketImagesProvider.overrideWithValue(MemoryTicketImages()),
        ],
        child: const MaterialApp(home: Scaffold(body: UpcomingEventsPage())),
      ));
      await _pumpFrames(tester);
    }

    testWidgets(
        'a cancelled event says so, with the reason and the refund; the '
        'others are as they were', (tester) async {
      api
        ..on('GET', _list, {
          'items': [_row(1), _row(2)],
        })
        ..on('GET', '/discover/events/event-1',
            _cancelledPage(1, 'The venue flooded.'))
        ..on('GET', '/discover/events/event-2', {
          'event': {'id': 2, 'status': 'upcoming'},
        });
      await pumpPage(tester);

      expect(find.byKey(EventCard.cancelledBadgeKey), findsOneWidget);
      expect(find.text('The venue flooded.'), findsOneWidget);
      expect(find.text(EventCancellation.refundNote), findsOneWidget);
      expect(find.text('VIEW TICKET'), findsOneWidget, reason: 'event 2');
      expect(find.byKey(const ValueKey('event-cancelled-view')), findsOneWidget);
    });

    testWidgets("the row's own word needs no lookup", (tester) async {
      api.on('GET', _list, {
        'items': [
          {
            ..._row(3, paid: false),
            'has_fee': false,
            'status': 'cancelled',
            'cancellation': {'reason': 'Rain.'},
          },
        ],
      });
      await pumpPage(tester);

      expect(find.text('Rain.'), findsOneWidget);
      expect(find.text(EventCancellation.refundNote), findsNothing,
          reason: 'a free ticket has nothing to refund');
      expect(api.sent('GET', '/discover/events/event-3'), isEmpty);
    });
  });
}
