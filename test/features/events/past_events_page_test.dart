import 'package:dio/dio.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/data/ticket_images.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/presentation/pages/events_page.dart';
import 'package:finnet/features/events/presentation/pages/past_events_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';

const _past = '/events/list?is_registered=true&is_ended=true&offset=0&limit=10';
const _upcoming =
    '/events/list?is_registered=true&is_ended=false&offset=0&limit=10';

Map<String, dynamic> _event(
  int id, {
  String? name,
  bool attended = false,
  bool? hasCertificate,
  String? certificateUrl,
}) =>
    {
      'id': id,
      'name': name ?? 'Event $id',
      'slug': 'event-$id',
      'club': {'id': 3, 'name': 'Tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'is_online': false,
      'has_fee': false,
      'event_datetime': '2020-12-01T10:00:00Z',
      'is_registered': true,
      'is_attended': attended,
      if (hasCertificate != null) 'has_certificate': hasCertificate,
      if (certificateUrl != null) 'certificate_url': certificateUrl,
    };

/// No tickets kept on the phone: the Registered tab's background sync
/// has nothing to do.
class _NoTickets extends SavedTicketsRepository {
  _NoTickets()
      : super(
          dio: Dio(),
          local: SavedTicketsLocalDataSource(MemoryStorage()),
        );

  @override
  Future<List<SavedTicket>> saved() async => const [];

  @override
  Future<List<SavedTicket>> refresh() async => const [];
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [page] inside a router, recording where it goes and with what.
Future<List<(String, Object?)>> _pump(WidgetTester tester, Widget page) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final went = <(String, Object?)>[];
  Widget stub(GoRouterState state) {
    went.add((state.uri.path, state.extra));
    return Scaffold(body: Text('opened ${state.uri.path}'));
  }

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: page)),
    GoRoute(path: '/events/:id', builder: (_, s) => stub(s)),
    GoRoute(path: '/certificates/:id', builder: (_, s) => stub(s)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      savedTicketsRepositoryProvider.overrideWithValue(_NoTickets()),
      ticketImagesProvider.overrideWithValue(MemoryTicketImages()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
  return went;
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('the Past tab', () {
    testWidgets(
        'asks for the registrations that have ended; an attended one offers '
        'its certificate, a missed one its event', (tester) async {
      api.on('GET', _past, {
        'items': [
          _event(1,
              name: 'Hack Night',
              attended: true,
              hasCertificate: true,
              certificateUrl: 'https://myotherapp.in/certificates/T-1'),
          _event(2, name: 'Design Jam'),
        ],
      });
      await _pump(tester, const PastEventsPage());

      expect(api.sent('GET', _past), hasLength(1));
      expect(find.text('Hack Night'), findsOneWidget);
      expect(find.text('Design Jam'), findsOneWidget);
      expect(find.text('Attended'), findsOneWidget);
      expect(find.text('Not Attended'), findsOneWidget);
      expect(find.text('VIEW CERTIFICATE'), findsOneWidget);
      expect(find.text('VIEW EVENT'), findsOneWidget);
      // A past event is not shared from here.
      expect(find.byIcon(Icons.share_outlined), findsNothing);
    });

    testWidgets('VIEW CERTIFICATE opens the certificate inside the app',
        (tester) async {
      api.on('GET', _past, {
        'items': [
          _event(1,
              attended: true,
              hasCertificate: true,
              certificateUrl: 'https://myotherapp.in/certificates/T-1'),
        ],
      });
      final went = await _pump(tester, const PastEventsPage());

      await tester.tap(find.text('VIEW CERTIFICATE'));
      await _settle(tester);

      expect(went.single.$1, '/certificates/T-1');
    });

    testWidgets('VIEW EVENT opens the event, saying it was missed',
        (tester) async {
      api.on('GET', _past, {
        'items': [_event(2)],
      });
      final went = await _pump(tester, const PastEventsPage());

      await tester.tap(find.text('VIEW EVENT'));
      await _settle(tester);

      expect(went.single.$1, '/events/2');
      expect((went.single.$2 as Map)['status'], 'notAttended');
    });

    testWidgets(
        'a certificate without a check-in (a speaker, say) still offers it',
        (tester) async {
      api.on('GET', _past, {
        'items': [
          _event(3,
              hasCertificate: true,
              certificateUrl: 'https://myotherapp.in/certificates/S-3'),
        ],
      });
      await _pump(tester, const PastEventsPage());

      expect(find.text('VIEW CERTIFICATE'), findsOneWidget);
      expect(find.text('Attended'), findsOneWidget);
    });

    testWidgets('with none, says there are no completed events',
        (tester) async {
      api.on('GET', _past, {'items': []});
      await _pump(tester, const PastEventsPage());

      expect(find.text('You are not having any completed events'),
          findsOneWidget);
    });
  });

  testWidgets('My events: REGISTERED first, then PAST at a tap',
      (tester) async {
    api
      ..on('GET', _upcoming, {
        'items': [
          {
            ..._event(5, name: 'Coming Up'),
            'event_datetime': '2030-12-01T10:00:00Z',
            'is_attended': false,
            'ticket_url': 'https://myotherapp.in/tickets/T-5',
            'is_paid': true,
          },
        ],
      })
      ..on('GET', _past, {
        'items': [_event(1, name: 'Hack Night', attended: true)],
      });
    await _pump(tester, const EventsPage());

    expect(find.text('REGISTERED'), findsOneWidget);
    expect(find.text('PAST'), findsOneWidget);
    expect(find.text('Coming Up'), findsOneWidget);
    expect(find.text('VIEW TICKET'), findsOneWidget);

    await tester.tap(find.text('PAST'));
    await tester.pumpAndSettle();

    expect(find.text('Hack Night'), findsOneWidget);
    expect(find.text('Attended'), findsOneWidget);
    expect(api.sent('GET', _past), hasLength(1));
  });
}
