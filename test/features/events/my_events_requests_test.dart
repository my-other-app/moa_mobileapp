import 'package:dio/dio.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/registration_requests_api.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/data/ticket_images.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/presentation/pages/no_registered_event_page.dart';
import 'package:finnet/features/events/presentation/pages/upcoming_events_page.dart';
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:finnet/features/events/presentation/widgets/approval/waiting_requests_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';
import 'registration_approval_model_test.dart' show requestBody, payBody;

const _list =
    '/events/list?is_registered=true&is_ended=false&offset=0&limit=10';
const _mine = '/registration-requests/mine';

class _NoTickets extends SavedTicketsRepository {
  _NoTickets()
      : super(dio: Dio(), local: SavedTicketsLocalDataSource(MemoryStorage()));

  @override
  Future<List<SavedTicket>> saved() async => const [];

  @override
  Future<List<SavedTicket>> refresh() async => const [];
}

Map<String, dynamic> _event(int id) => {
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
    };

/// Every kind of request: only the open ones (waiting, or confirmed and
/// waiting for the payment) are listed.
Map<String, dynamic> _requests() => {
      'items': [
        requestBody(id: 'r-pending', token: 'tok_p'),
        requestBody(
            id: 'r-pay', token: 'tok_pay', status: 'approved', pay: payBody())
          ..['event'] = {
            'id': 8,
            'slug': 'design-jam',
            'name': 'Design Jam',
            'club': {'name': 'Figma Club'},
          },
        requestBody(id: 'r-ticket', status: 'approved', ticketId: 'T-1'),
        requestBody(id: 'r-declined', status: 'declined'),
        requestBody(id: 'r-withdrawn', status: 'withdrawn'),
        requestBody(id: 'r-lapsed', status: 'lapsed'),
        requestBody(id: 'r-closed', status: 'closed'),
      ],
    };

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(body: UpcomingEventsPage()),
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
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The server's answers to `mine`, scripted, for the notifier alone.
class _FakeApi extends RegistrationRequestsApi {
  List<RegistrationRequest>? saved;
  final answers = <Object?>[];
  int asked = 0;

  @override
  Future<List<RegistrationRequest>?> savedMine() async => saved;

  @override
  Future<List<RegistrationRequest>?> mine() async {
    asked++;
    final answer = answers.length > 1 ? answers.removeAt(0) : answers.first;
    if (answer is Exception) throw answer;
    return answer as List<RegistrationRequest>?;
  }
}

RegistrationRequest _req(String id,
        {String status = 'pending', int event = 7}) =>
    RegistrationRequest.fromJson(
        requestBody(id: id, token: 'tok_$id', status: status, eventId: event))!;

void main() {
  group('My events: "Waiting for confirmation"', () {
    testWidgets('lists the open requests above the registrations',
        (tester) async {
      useFakeApi()
        ..on('GET', _list, {
          'items': [_event(1)]
        })
        ..on('GET', _mine, _requests());
      await _pump(tester);

      expect(find.byKey(WaitingRequestsSection.sectionKey), findsOneWidget);
      expect(find.text(WaitingRequestsSection.title), findsOneWidget);
      expect(
          find.byKey(const ValueKey('request-tile-r-pending')), findsOneWidget);
      expect(find.text('Waiting for Tinkerhub to confirm'), findsOneWidget);
      expect(find.byKey(const ValueKey('request-tile-r-pay')), findsOneWidget);
      expect(find.textContaining('Figma Club confirmed your place · finish by'),
          findsOneWidget);
      expect(find.textContaining('₹'), findsNothing,
          reason: 'no price in the list (an iPhone shows none for online)');
      for (final settled in [
        'r-ticket',
        'r-declined',
        'r-withdrawn',
        'r-lapsed',
        'r-closed'
      ]) {
        expect(find.byKey(ValueKey('request-tile-$settled')), findsNothing,
            reason: settled);
      }
      // The registration is still there, under them.
      expect(find.text('Event 1'), findsOneWidget);
      final sectionTop =
          tester.getTopLeft(find.byKey(WaitingRequestsSection.sectionKey)).dy;
      expect(sectionTop, lessThan(tester.getTopLeft(find.text('Event 1')).dy));
    });

    testWidgets('a request opens its status screen', (tester) async {
      useFakeApi()
        ..on('GET', _list, {
          'items': [_event(1)]
        })
        ..on('GET', _mine, _requests());
      await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('request-tile-r-pay')));
      await tester.pumpAndSettle();
      expect(find.text('Request tok_pay'), findsOneWidget);
    });

    testWidgets('no registrations yet, but a request waiting: the request',
        (tester) async {
      useFakeApi()
        ..on('GET', _list, {'items': []})
        ..on('GET', _mine, {
          'items': [requestBody(id: 'r-pending', token: 'tok_p')]
        });
      await _pump(tester);

      expect(find.byKey(WaitingRequestsSection.sectionKey), findsOneWidget);
      expect(find.byType(NoRegisteredEventPage), findsNothing);
    });

    testWidgets('an older server (404): nothing of it, the list as it was',
        (tester) async {
      final api = useFakeApi()
        ..on('GET', _list, {
          'items': [_event(1)]
        });
      await _pump(tester);

      expect(api.sent('GET', _mine), hasLength(1));
      expect(find.byKey(WaitingRequestsSection.sectionKey), findsNothing);
      expect(find.text('Event 1'), findsOneWidget);
    });

    testWidgets('an older server and no registrations: the empty page',
        (tester) async {
      useFakeApi().on('GET', _list, {'items': []});
      await _pump(tester);
      expect(find.byType(NoRegisteredEventPage), findsOneWidget);
    });

    testWidgets('nothing open: no section', (tester) async {
      useFakeApi()
        ..on('GET', _list, {
          'items': [_event(1)]
        })
        ..on('GET', _mine, {
          'items': [requestBody(status: 'declined')]
        });
      await _pump(tester);
      expect(find.byKey(WaitingRequestsSection.sectionKey), findsNothing);
    });

    test('mine is asked with the session, and saved like My events', () async {
      final api = useFakeApi()..on('GET', _mine, _requests());
      await RegistrationRequestsApi().mine();
      final sent = api.sent('GET', _mine).single;
      expect(sent.extra['skipAuth'], isFalse);
      expect(CachePolicy.of(sent), CachePolicy.personalKept);
    });
  });

  group('the requests, kept like the rest of My events', () {
    test('the phone\'s copy at once, then the server\'s', () async {
      final api = _FakeApi()
        ..saved = [_req('old')]
        ..answers.add([_req('new'), _req('gone', status: 'declined')]);
      final notifier = MyRegistrationRequestsNotifier(api);
      final seen = <List<String>>[];
      notifier.addListener((s) => seen.add([for (final r in s.open) r.id]),
          fireImmediately: false);

      await notifier.refresh();

      expect(seen.first, ['old']);
      expect(seen.last, ['new']);
      expect(notifier.state.loaded, isTrue);
      expect(notifier.state.supported, isTrue);
    });

    test('offline: the phone\'s copy stays', () async {
      final api = _FakeApi()
        ..saved = [_req('old')]
        ..answers.add(const ApiException(
            message: 'offline', type: ApiExceptionType.network));
      final notifier = MyRegistrationRequestsNotifier(api);
      await notifier.refresh();
      expect(notifier.state.open.map((r) => r.id), ['old']);
    });

    test('a 404 hides it all, even a copy saved before', () async {
      final api = _FakeApi()
        ..saved = [_req('old')]
        ..answers.add(null);
      final notifier = MyRegistrationRequestsNotifier(api);
      await notifier.refresh();
      expect(notifier.state.supported, isFalse);
      expect(notifier.state.open, isEmpty);
      // And what the phone learns after doesn't bring it back.
      notifier.remember(_req('sent'));
      expect(notifier.state.open, isEmpty);
    });

    test('one read at a time; a recent answer isn\'t asked again', () async {
      var now = DateTime(2026, 10, 26, 9);
      final api = _FakeApi()..answers.add([_req('a')]);
      final notifier = MyRegistrationRequestsNotifier(api, now: () => now);

      await Future.wait([notifier.refresh(), notifier.refresh()]);
      expect(api.asked, 1);
      await notifier.refreshIfOlderThan(const Duration(seconds: 30));
      expect(api.asked, 1);
      now = now.add(const Duration(minutes: 1));
      await notifier.refreshIfOlderThan(const Duration(seconds: 30));
      expect(api.asked, 2);
    });

    test('a request learned here shows at once, and replaces its old copy',
        () async {
      final api = _FakeApi()..answers.add([_req('a')]);
      final notifier = MyRegistrationRequestsNotifier(api);
      await notifier.refresh();

      notifier.remember(_req('b', event: 9));
      expect(notifier.state.open.map((r) => r.id), ['b', 'a']);
      expect(notifier.state.openFor(9)!.id, 'b');

      notifier.remember(RegistrationRequest(
          id: 'a', status: RequestStatus.withdrawn, token: 'tok_a'));
      expect(notifier.state.open.map((r) => r.id), ['b']);
      expect(notifier.state.items.firstWhere((r) => r.id == 'a').event!.name,
          'Hack Night',
          reason: 'what the answer left out is kept');
    });
  });
}
