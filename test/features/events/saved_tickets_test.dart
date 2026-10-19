import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart';
import 'package:finnet/features/events/presentation/pages/upcoming_events_page.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';

final _now = DateTime(2026, 10, 19, 12);

Map<String, dynamic> _registration(
  int id, {
  String? ticket,
  DateTime? at,
  Object? isPaid = true,
  bool hasFee = false,
  bool attended = false,
}) =>
    {
      'id': id,
      'name': 'Event $id',
      'event_datetime': (at ?? _now.add(const Duration(days: 2)))
          .toUtc()
          .toIso8601String(),
      'duration': 3,
      'location_name': 'CET Main Hall',
      'is_online': false,
      'has_fee': hasFee,
      'is_paid': isPaid,
      'is_attended': attended,
      'ticket_id': ticket ?? 'MOA-7K3QF-X9P$id',
      'ticket_url': 'https://myotherapp.in/tickets/${ticket ?? 'MOA-7K3QF-X9P$id'}',
      'club': {'id': 1, 'name': 'Tinkerhub'},
    };

/// A server for /events/list that can be told to be unreachable.
class _Server implements HttpClientAdapter {
  Object? body;
  bool offline = false;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
        error: const SocketException('offline'),
      );
    }
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

({SavedTicketsRepository repo, _Server server, MemoryStorage storage}) _repo() {
  final server = _Server();
  final storage = MemoryStorage();
  final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
    ..httpClientAdapter = server
    ..interceptors.add(ErrorInterceptor());
  return (
    repo: SavedTicketsRepository(
      dio: dio,
      local: SavedTicketsLocalDataSource(storage),
      now: () => _now,
    ),
    server: server,
    storage: storage,
  );
}

void main() {
  group('ticketCodeFromUrl', () {
    test('reads the code from either address, or takes a bare code', () {
      expect(ticketCodeFromUrl('https://myotherapp.in/tickets/MOA-7K3QF-X9PWM'),
          'MOA-7K3QF-X9PWM');
      expect(ticketCodeFromUrl('/api/v1/events/tickets/MOA-7K3QF-X9PWM'),
          'MOA-7K3QF-X9PWM');
      expect(ticketCodeFromUrl('https://myotherapp.in/tickets/MOA-1?x=1#y'),
          'MOA-1');
      expect(ticketCodeFromUrl('MOA-7K3QF-X9PWM'), 'MOA-7K3QF-X9PWM');
      expect(ticketCodeFromUrl(''), isNull);
      expect(ticketCodeFromUrl(null), isNull);
    });
  });

  group('SavedTicket.fromRegistration', () {
    test('a paid or free registration is a ticket, with what the door needs',
        () {
      final t = SavedTicket.fromRegistration(_registration(7))!;
      expect(t.code, 'MOA-7K3QF-X9P7');
      expect(t.eventId, 7);
      expect(t.eventName, 'Event 7');
      expect(t.venue, 'CET Main Hall');
      expect(t.startsAt, _now.add(const Duration(days: 2)));
      expect(t.status, RegistrationStatus.registered);
      // Round trip through storage.
      final back = SavedTicket.fromJson(jsonDecode(jsonEncode(t.toJson())))!;
      expect(back.code, t.code);
      expect(back.startsAt, t.startsAt);
      expect(back.venue, t.venue);
    });

    test('an unpaid registration for a paid event is not a ticket', () {
      expect(
          SavedTicket.fromRegistration(
              _registration(7, isPaid: false, hasFee: true)),
          isNull);
      // A free event's registration is sent with is_paid false too.
      expect(
          SavedTicket.fromRegistration(
              _registration(7, isPaid: false, hasFee: false)),
          isNotNull);
    });

    test('no ticket code, no ticket', () {
      expect(
          SavedTicket.fromRegistration(
              {..._registration(7), 'ticket_id': null, 'ticket_url': null}),
          isNull);
    });

    test('checked in is kept, marked attended', () {
      expect(SavedTicket.fromRegistration(_registration(7, attended: true))!
          .status, RegistrationStatus.attended);
    });
  });

  group('SavedTicketsRepository', () {
    test('a refresh keeps exactly what the server lists, encrypted', () async {
      final t = _repo();
      t.server.body = {
        'items': [_registration(1), _registration(2)]
      };

      final first = await t.repo.refresh();
      expect(first.map((x) => x.eventId), [1, 2]);
      expect(t.storage.values.keys, [SavedTicketsLocalDataSource.key]);

      // Registration 2 was cancelled and refunded: the server no longer
      // lists it, and the phone forgets it.
      t.server.body = {
        'items': [_registration(1)]
      };
      await t.repo.refresh();
      expect((await t.repo.saved()).map((x) => x.eventId), [1]);
    });

    test('offline, a refresh fails and the saved tickets stay', () async {
      final t = _repo();
      t.server.body = {
        'items': [_registration(1)]
      };
      await t.repo.refresh();

      t.server.offline = true;
      await expectLater(t.repo.refresh(), throwsA(isA<DioException>()));
      expect((await t.repo.saved()).map((x) => x.eventId), [1]);
    });

    test('an event that is over is dropped; soonest first', () async {
      final t = _repo();
      t.server.body = {
        'items': [
          _registration(1, at: _now.add(const Duration(days: 9))),
          _registration(2, at: _now.subtract(const Duration(days: 2))),
          _registration(3, at: _now.add(const Duration(hours: 1))),
          // Started an hour ago, runs three: still on.
          _registration(4, at: _now.subtract(const Duration(hours: 1))),
        ]
      };

      final tickets = await t.repo.refresh();
      expect(tickets.map((x) => x.eventId), [4, 3, 1]);
    });

    test('a body without a list does not wipe the saved tickets', () async {
      final t = _repo();
      t.server.body = {
        'items': [_registration(1)]
      };
      await t.repo.refresh();

      t.server.body = {'message': 'odd'};
      await expectLater(t.repo.refresh(), throwsA(isA<FormatException>()));
      expect(await t.repo.saved(), hasLength(1));
    });
  });

  group('the ticket with no network', () {
    late NetworkStatus offline;

    setUp(() {
      useFakeApi();
      offline = NetworkStatus(probe: () async => false)..reportOffline();
    });
    tearDown(() => offline.dispose());

    Future<void> pumpTicket(WidgetTester tester, Widget page,
        {List<Override> overrides = const []}) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: overrides,
        child: MaterialApp(home: page),
      ));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    testWidgets('opens at once, its QR made on the phone from the code',
        (tester) async {
      final api = useFakeApi();
      await pumpTicket(
        tester,
        TicketViewPage(
          ticketId: 'MOA-7K3QF-X9PWM',
          eventName: 'Hack Night',
          networkStatus: offline,
        ),
      );

      expect(find.byKey(TicketViewPage.offlineNoticeKey), findsOneWidget);
      expect(find.text(TicketViewPage.offlineNotice), findsOneWidget);
      expect(find.byKey(TicketViewPage.qrKeyFor('MOA-7K3QF-X9PWM')),
          findsOneWidget);
      expect(find.text('MOA-7K3QF-X9PWM'), findsWidgets);
      // Nothing was asked of the network.
      expect(api.requests, isEmpty);
    });

    testWidgets('a rendered ticket that cannot be fetched (no connection) '
        'falls back to the saved ticket and says so', (tester) async {
      final server = _Server()..offline = true;
      APIService.instance.dio.httpClientAdapter = server;
      final online = NetworkStatus(probe: () async => false);
      addTearDown(online.dispose);

      await pumpTicket(
        tester,
        TicketViewPage(
          ticketId: 'MOA-7K3QF-X9PWM',
          eventName: 'Hack Night',
          networkStatus: online,
        ),
      );

      expect(server.calls, 1, reason: 'asked once, not retried');
      expect(find.text(TicketViewPage.offlineNotice), findsOneWidget);
      expect(find.byKey(TicketViewPage.qrKeyFor('MOA-7K3QF-X9PWM')),
          findsOneWidget);
    });

    testWidgets('a code the QR encodes is the plain ticket code',
        (tester) async {
      await pumpTicket(
        tester,
        TicketViewPage(
          ticketId: 'MOA-7K3QF-X9PWM',
          eventName: 'Hack Night',
          networkStatus: offline,
        ),
      );
      expect(find.byKey(TicketViewPage.qrKeyFor('MOA-7K3QF-X9PWM')),
          findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('/tickets/{code} finds the saved ticket by its code',
        (tester) async {
      final storage = MemoryStorage();
      final local = SavedTicketsLocalDataSource(storage);
      await local.write([
        SavedTicket.fromRegistration(_registration(5, ticket: 'MOA-AAAAA-BBBBB'))!,
      ]);
      final repo = SavedTicketsRepository(
        dio: Dio(),
        local: local,
        now: () => DateTime.now().subtract(const Duration(days: 400)),
      );

      await pumpTicket(
        tester,
        const SavedTicketPage(code: 'MOA-AAAAA-BBBBB'),
        overrides: [
          savedTicketsRepositoryProvider.overrideWithValue(repo),
        ],
      );

      expect(find.text('EVENT 5'), findsOneWidget);
      expect(find.text('CET Main Hall'), findsOneWidget);
    });
  });

  testWidgets(
      'the upcoming list with nothing saved and no network shows the saved '
      'tickets instead of an error', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // The list cannot be had: the fake answers 503 for anything.
    final api = useFakeApi();
    api.on('GET',
        '/events/list?is_registered=true&is_ended=false&offset=0&limit=10',
        {'message': 'down'},
        status: 503);
    final storage = MemoryStorage();
    final local = SavedTicketsLocalDataSource(storage);
    await local.write([SavedTicket.fromRegistration(_registration(9))!]);
    final repo = SavedTicketsRepository(
      dio: Dio(),
      local: local,
      now: () => DateTime.now().subtract(const Duration(days: 400)),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [savedTicketsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: UpcomingEventsPage())),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text(SavedTicketsFallback.notice), findsOneWidget);
    expect(find.text('Event 9'), findsOneWidget);
    expect(find.text('VIEW TICKET'), findsOneWidget);
  });

  group('SavedTicketsNotifier', () {
    test('starts from the saved tickets; a failed refresh keeps them',
        () async {
      final t = _repo();
      t.server.body = {
        'items': [_registration(1)]
      };
      await t.repo.refresh();
      t.server.offline = true;

      final notifier = SavedTicketsNotifier(t.repo, now: () => _now);
      addTearDown(notifier.dispose);
      await notifier.loaded;
      expect(notifier.state.map((x) => x.eventId), [1]);

      await notifier.refresh();
      expect(notifier.state.map((x) => x.eventId), [1]);
      expect(notifier.byCode('MOA-7K3QF-X9P1')?.eventId, 1);
    });

    test('refreshes at most once while one is running', () async {
      final t = _repo();
      t.server.body = {'items': []};
      final notifier = SavedTicketsNotifier(t.repo, now: () => _now);
      addTearDown(notifier.dispose);

      await Future.wait([notifier.refresh(), notifier.refresh()]);
      expect(t.server.calls, 1);

      await notifier.refreshIfOlderThan(const Duration(minutes: 10));
      expect(t.server.calls, 1, reason: 'just refreshed');
    });
  });
}
