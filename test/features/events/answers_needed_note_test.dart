// "2 details needed · Add them" (missing-answers-contract.md §2.4, §3 App
// 2): wherever a ticket or a registration is, from the server's
// `answers_needed`, opening the person's link in the app -- and nothing at
// all from a server that doesn't send it.

import 'package:dio/dio.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/data/ticket_images.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/missing_answers.dart';
import 'package:finnet/features/events/presentation/pages/registration_request_page.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart';
import 'package:finnet/features/events/presentation/pages/upcoming_events_page.dart';
import 'package:finnet/features/events/presentation/widgets/answers_needed_note.dart';
import 'package:finnet/features/events/presentation/widgets/approval/waiting_requests_section.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';
import 'registration_approval_model_test.dart' show requestBody;

const _list =
    '/events/list?is_registered=true&is_ended=false&offset=0&limit=10';
const _mine = '/registration-requests/mine';
const _link = 'https://myotherapp.in/answers/12/reg-1?k=abc.def';
const _flag = {'count': 2, 'url': _link, 'deadline': '2030-11-28T12:30:00Z'};

class _NoTickets extends SavedTicketsRepository {
  _NoTickets()
      : super(dio: Dio(), local: SavedTicketsLocalDataSource(MemoryStorage()));

  @override
  Future<List<SavedTicket>> saved() async => const [];

  @override
  Future<List<SavedTicket>> refresh() async => const [];
}

Map<String, dynamic> _event(int id, {Object? answersNeeded}) => {
      'id': id,
      'name': 'Event $id',
      'slug': 'event-$id',
      'club': {'id': 3, 'name': 'Tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'is_online': false,
      'has_fee': false,
      'event_datetime': '2030-12-01T10:00:00Z',
      'ticket_url': 'https://myotherapp.in/tickets/T-$id',
      'is_paid': true,
      if (answersNeeded != null) 'answers_needed': answersNeeded,
    };

late GoRouter _router;

Future<void> _pump(WidgetTester tester, Widget home,
    {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  _router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: home)),
    GoRoute(
      path: '/answers/:eventId/:ref',
      builder: (_, state) => Scaffold(
          body: Text('details ${state.pathParameters['eventId']} '
              '${state.pathParameters['ref']} '
              '${state.uri.queryParameters['k']}')),
    ),
    GoRoute(
      path: '/requests/:token',
      builder: (_, state) =>
          Scaffold(body: Text('Request ${state.pathParameters['token']}')),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      savedTicketsRepositoryProvider.overrideWithValue(_NoTickets()),
      ticketImagesProvider.overrideWithValue(MemoryTicketImages()),
      ...overrides,
    ],
    child: MaterialApp.router(routerConfig: _router),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _openNote(WidgetTester tester, [Finder? note]) async {
  final target = note ?? find.byKey(AnswersNeededNote.noteKey);
  await tester.ensureVisible(target.first);
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('My events', () {
    testWidgets(
        'a registration the club asked more of says so, and opens the '
        'details in the app; back, the list is read again', (tester) async {
      api
        ..on('GET', _list, {
          'items': [
            _event(12, answersNeeded: _flag),
            _event(13),
          ]
        })
        ..on('GET', _mine, {'items': []});
      await _pump(tester, const UpcomingEventsPage());

      // Only on the card it is about.
      expect(find.byKey(AnswersNeededNote.noteKey), findsOneWidget);
      expect(find.text('2 details needed · Add them'), findsOneWidget);
      expect(find.textContaining('By '), findsOneWidget);
      final reads = api.sent('GET', _list).length;

      await _openNote(tester);
      expect(find.text('details 12 reg-1 abc.def'), findsOneWidget);

      _router.pop();
      await tester.pumpAndSettle();
      expect(api.sent('GET', _list).length, reads + 1);
    });

    testWidgets('an older server: no note anywhere', (tester) async {
      api
        ..on('GET', _list, {
          'items': [_event(12), _event(13)]
        })
        ..on('GET', _mine, {'items': []});
      await _pump(tester, const UpcomingEventsPage());
      expect(find.byKey(AnswersNeededNote.noteKey), findsNothing);
    });

    testWidgets('a registration under review the club asked more of',
        (tester) async {
      api
        ..on('GET', _list, {'items': []})
        ..on('GET', _mine, {
          'items': [
            requestBody(id: 'r-1', token: 'tok_1')..['answers_needed'] = _flag,
            requestBody(id: 'r-2', token: 'tok_2', eventId: 8),
          ]
        });
      await _pump(tester, const UpcomingEventsPage());

      expect(find.byKey(WaitingRequestsSection.sectionKey), findsOneWidget);
      expect(find.byKey(const ValueKey('request-answers-r-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('request-answers-r-2')), findsNothing);

      await _openNote(
          tester, find.byKey(const ValueKey('request-answers-r-1')));
      expect(find.text('details 12 reg-1 abc.def'), findsOneWidget);
    });
  });

  group('the card', () {
    EventCard card(EventCardStatus status) => EventCard(
          title: 'Hack Night',
          organizer: 'Tinkerhub',
          tags: const [],
          onTap: () {},
          orgImage: '',
          eventId: 12,
          clubId: 3,
          clubSlug: 'tinkerhub',
          eventSlug: 'hack-night',
          status: status,
          answersNeeded: AnswersNeeded.fromJson(_flag),
        );

    for (final (status, shows) in [
      (EventCardStatus.registered, true),
      (EventCardStatus.awaitingPayment, true),
      // Not theirs, revoked, or over: never.
      (EventCardStatus.none, false),
      (EventCardStatus.ticketRevoked, false),
      (EventCardStatus.notAttended, false),
    ]) {
      testWidgets('${status.name}: ${shows ? 'the note' : 'no note'}',
          (tester) async {
        await _pump(tester, SingleChildScrollView(child: card(status)));
        expect(find.byKey(AnswersNeededNote.noteKey),
            shows ? findsOneWidget : findsNothing);
      });
    }
  });

  testWidgets('the ticket says so above itself, by its own details',
      (tester) async {
    api.on('GET', '/events/tickets/MOA-AAAAA-BBBB7',
        {'ticket_revoked': false, 'answers_needed': _flag});
    await _pump(tester, const SavedTicketPage(code: 'MOA-AAAAA-BBBB7'));

    expect(find.byKey(AnswersNeededNote.noteKey), findsOneWidget);
    await _openNote(tester);
    expect(find.text('details 12 reg-1 abc.def'), findsOneWidget);
  });

  testWidgets('a ticket whose details ask nothing has no note', (tester) async {
    api.on('GET', '/events/tickets/MOA-AAAAA-BBBB8', {'ticket_revoked': false});
    await _pump(tester, const SavedTicketPage(code: 'MOA-AAAAA-BBBB8'));
    expect(find.byKey(AnswersNeededNote.noteKey), findsNothing);
  });

  testWidgets('a registration under review\'s own page says so too',
      (tester) async {
    api.on('GET', '/registration-requests/tok_1',
        requestBody()..['answers_needed'] = _flag);
    await _pump(tester, const RegistrationRequestPage(token: 'tok_1'));

    expect(find.byKey(AnswersNeededNote.noteKey), findsOneWidget);
    await _openNote(tester);
    expect(find.text('details 12 reg-1 abc.def'), findsOneWidget);
  });
}
