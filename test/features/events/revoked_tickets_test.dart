import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/events/data/datasources/saved_tickets_local_datasource.dart';
import 'package:finnet/features/events/data/repositories/saved_tickets_repository.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/features/events/presentation/pages/upcoming_events_page.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../auth/auth_fakes.dart';
import 'events_fakes.dart';

final _soon = DateTime.now().add(const Duration(days: 3));

Map<String, dynamic> _item(int id, {Object? revoked}) => {
      'id': id,
      'name': 'Event $id',
      'event_datetime': _soon.toUtc().toIso8601String(),
      'duration': 2,
      'location_name': 'CET',
      'has_fee': false,
      'is_paid': true,
      'is_attended': false,
      'ticket_id': 'MOA-AAAAA-BBBB$id',
      'ticket_url': 'https://myotherapp.in/tickets/MOA-AAAAA-BBBB$id',
      'club': {'id': 1, 'name': 'Tinkerhub'},
      if (revoked != _absent) 'ticket_revoked': revoked,
    };

const _absent = Object();

class _ListServer implements HttpClientAdapter {
  Object? body;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      'content-type': ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Future<void> _pump(WidgetTester tester, Widget page,
    {List<Override> overrides = const []}) async {
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      ProviderScope(overrides: overrides, child: MaterialApp(home: page)));
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  group('ticket_revoked in the list', () {
    test('true is a revoked ticket; false, null or missing is not', () {
      expect(SavedTicket.fromRegistration(_item(1, revoked: true))!.revoked,
          isTrue);
      expect(SavedTicket.fromRegistration(_item(1, revoked: false))!.revoked,
          isFalse);
      expect(SavedTicket.fromRegistration(_item(1, revoked: null))!.revoked,
          isFalse);
      expect(SavedTicket.fromRegistration(_item(1))!.revoked, isFalse,
          reason: "today's API has no field");
    });

    test('a revoked ticket is kept as revoked, through storage', () {
      final t = SavedTicket.fromRegistration(_item(1, revoked: true))!;
      expect(SavedTicket.fromJson(jsonDecode(jsonEncode(t.toJson())))!.revoked,
          isTrue);
    });

    test('a saved, usable ticket is marked revoked on the next refresh',
        () async {
      final server = _ListServer();
      final storage = MemoryStorage();
      final repo = SavedTicketsRepository(
        dio: Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
          ..httpClientAdapter = server
          ..interceptors.add(ErrorInterceptor()),
        local: SavedTicketsLocalDataSource(storage),
      );

      server.body = {
        'items': [_item(1, revoked: false), _item(2)]
      };
      await repo.refresh();
      expect((await repo.saved()).where((t) => t.revoked), isEmpty);

      // The organiser revokes ticket 1: it stays in the list, flagged.
      server.body = {
        'items': [_item(1, revoked: true), _item(2)]
      };
      await repo.refresh();
      final saved = await repo.saved();
      expect(saved.map((t) => t.eventId), [1, 2]);
      expect(saved.firstWhere((t) => t.eventId == 1).revoked, isTrue);
      expect(saved.firstWhere((t) => t.eventId == 2).revoked, isFalse);
    });
  });

  group('the ticket screen, revoked', () {
    setUp(useFakeApi);

    for (final offline in [false, true]) {
      testWidgets(
          'says so instead of the QR, ${offline ? 'offline' : 'online'}',
          (tester) async {
        final api = useFakeApi();
        final status = NetworkStatus(probe: () async => false);
        if (offline) status.reportOffline();

        await _pump(
          tester,
          TicketViewPage(
            ticketId: 'MOA-AAAAA-BBBB1',
            eventName: 'Hack Night',
            networkStatus: status,
            revoked: true,
          ),
        );

        expect(find.text(TicketViewPage.revokedMessage), findsOneWidget);
        expect(find.byType(QrImageView), findsNothing);
        expect(find.byType(Image), findsNothing,
            reason: 'nor the rendered ticket, which carries a QR');
        expect(find.text('Download'), findsNothing);
        expect(find.text('Add to Wallet'), findsNothing);
        expect(find.byIcon(Icons.share_outlined), findsNothing);
        expect(api.requests, isEmpty, reason: 'nothing to fetch');
        // Its probe timer, stopped inside the test's own clock.
        status.dispose();
      });
    }

    testWidgets('/tickets/{code} knows from the saved ticket', (tester) async {
      final storage = MemoryStorage();
      final local = SavedTicketsLocalDataSource(storage);
      await local.write([SavedTicket.fromRegistration(_item(4, revoked: true))!]);
      final repo = SavedTicketsRepository(dio: Dio(), local: local);

      await _pump(
        tester,
        const SavedTicketPage(code: 'MOA-AAAAA-BBBB4'),
        overrides: [savedTicketsRepositoryProvider.overrideWithValue(repo)],
      );

      expect(find.text(TicketViewPage.revokedMessage), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('a usable saved ticket still shows its QR', (tester) async {
      final storage = MemoryStorage();
      final local = SavedTicketsLocalDataSource(storage);
      await local.write([SavedTicket.fromRegistration(_item(5))!]);
      final repo = SavedTicketsRepository(dio: Dio(), local: local);

      // The rendered ticket is not there (the fake answers 404): the drawn
      // card, with its QR.
      await _pump(
        tester,
        const SavedTicketPage(code: 'MOA-AAAAA-BBBB5'),
        overrides: [savedTicketsRepositoryProvider.overrideWithValue(repo)],
      );

      expect(find.text(TicketViewPage.revokedMessage), findsNothing);
      expect(find.byType(QrImageView), findsOneWidget);
    });
  });

  group('cards', () {
    test('a revoked registration is a revoked card, whatever its payment', () {
      expect(registeredCardStatus(_item(1, revoked: true)),
          EventCardStatus.ticketRevoked);
      expect(
          registeredCardStatus(
              {..._item(1, revoked: true), 'has_fee': true, 'is_paid': false}),
          EventCardStatus.ticketRevoked);
      expect(registeredCardStatus(_item(1, revoked: null)),
          EventCardStatus.registered);
      expect(registeredCardStatus(_item(1)), EventCardStatus.registered);
    });

    testWidgets('the card says revoked and opens the revoked ticket',
        (tester) async {
      final pushed = <(String, Object?)>[];
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              child: EventCard(
                title: 'Hack Night',
                organizer: 'Tinkerhub',
                tags: const ['Tech'],
                onTap: () {},
                orgImage: '',
                eventId: 1,
                clubId: 1,
                clubSlug: 'tinkerhub',
                eventSlug: 'hack-night',
                status: EventCardStatus.ticketRevoked,
                ticketUrl: 'https://myotherapp.in/tickets/MOA-AAAAA-BBBB1',
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/tickets/:code',
          builder: (_, state) {
            pushed.add((state.uri.path, state.extra));
            return const Text('TICKET');
          },
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      expect(find.text('Ticket revoked'), findsOneWidget);
      expect(find.text('VIEW TICKET'), findsNothing);
      await tester.ensureVisible(find.text('TICKET REVOKED'));
      await tester.tap(find.text('TICKET REVOKED'));
      await tester.pumpAndSettle();

      expect(pushed.single.$1, '/tickets/MOA-AAAAA-BBBB1');
      expect(pushed.single.$2, {'revoked': true});
    });

    testWidgets('the Upcoming list shows the revoked state', (tester) async {
      useFakeApi().on(
        'GET',
        '/events/list?is_registered=true&is_ended=false&offset=0&limit=10',
        {
          'items': [_item(1, revoked: true), _item(2, revoked: false)]
        },
      );

      await _pump(tester, const Scaffold(body: UpcomingEventsPage()));

      expect(find.text('TICKET REVOKED'), findsOneWidget);
      expect(find.text('VIEW TICKET'), findsOneWidget);
      expect(find.text('Ticket revoked'), findsOneWidget);
    });

    testWidgets('a saved revoked ticket is not offered as a ticket offline',
        (tester) async {
      final api = useFakeApi();
      api.on('GET',
          '/events/list?is_registered=true&is_ended=false&offset=0&limit=10',
          {'message': 'down'},
          status: 503);
      final local = SavedTicketsLocalDataSource(MemoryStorage());
      await local.write([
        SavedTicket.fromRegistration(_item(1, revoked: true))!,
        SavedTicket.fromRegistration(_item(2))!,
      ]);
      final repo = SavedTicketsRepository(dio: Dio(), local: local);

      await _pump(tester, const Scaffold(body: UpcomingEventsPage()),
          overrides: [savedTicketsRepositoryProvider.overrideWithValue(repo)]);

      expect(find.text('REVOKED'), findsOneWidget);
      expect(find.text('VIEW TICKET'), findsOneWidget);
      expect(find.textContaining('Revoked by the organiser'), findsOneWidget);
    });
  });

  group('documents the server rendered without an image (no ETag)', () {
    late Directory dir;
    late DocumentCache cache;
    late List<RequestOptions> requests;
    late List<ResponseBody Function()> answers;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('final_docs');
      requests = [];
      answers = [];
      final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
        ..httpClientAdapter = _Scripted(requests, answers)
        ..interceptors.add(ErrorInterceptor());
      cache = DocumentCache(dio: dio, root: () async => dir);
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    ResponseBody pdf(String text, {String? etag, int status = 200}) =>
        ResponseBody.fromBytes(utf8.encode(text), status, headers: {
          'content-type': ['application/pdf'],
          if (etag != null) 'etag': [etag],
        });

    const path = '/events/certificates/MOA-1/pdf';

    test('is shown, but fetched in full next time, even with a matching '
        'version', () async {
      answers.addAll([
        () => pdf('missing the logo'),
        () => pdf('complete', etag: '"3-0123456789abcdef01234567"'),
      ]);

      final first = await cache.fetch(path, name: 'c.pdf', version: '3');
      expect(await first.file.readAsString(), 'missing the logo');

      final second = await cache.fetch(path, name: 'c.pdf', version: '3');
      expect(requests, hasLength(2), reason: 'not trusted as final');
      expect(requests.last.headers['If-None-Match'], isNull);
      expect(await second.file.readAsString(), 'complete');
    });

    test('a strong tag goes back verbatim, and a daily date change is a new '
        'download', () async {
      const today = '"2-aaaaaaaaaaaaaaaaaaaaaaaa"';
      const tomorrow = '"2-bbbbbbbbbbbbbbbbbbbbbbbb"';
      answers.addAll([
        () => pdf('dated today', etag: today),
        () => ResponseBody.fromBytes(const [], 304, headers: {
              'etag': [today],
            }),
        () => pdf('dated tomorrow', etag: tomorrow),
      ]);

      await cache.fetch(path, name: 'c.pdf');
      final same = await cache.fetch(path, name: 'c.pdf');
      expect(requests[1].headers['If-None-Match'], today);
      expect(await same.file.readAsString(), 'dated today');

      final next = await cache.fetch(path, name: 'c.pdf');
      expect(requests[2].headers['If-None-Match'], today);
      expect(await next.file.readAsString(), 'dated tomorrow');
    });

    test('a rendered picture without a tag is due again at once', () async {
      final inner = _FakeFileService();
      final service = DocumentImageFileService(inner);
      const certificate =
          'https://api.test/api/v1/events/certificates/MOA-1/image';

      inner.next = _Response(eTag: null);
      final unfinished = await service.get(certificate);
      expect(unfinished.validTill.isAfter(DateTime.now()), isFalse);

      inner.next = _Response(eTag: '"3-0123456789abcdef01234567"');
      final complete = await service.get(certificate);
      expect(complete.validTill, inner.next!.validTill);

      inner.next = _Response(eTag: null);
      final poster = await service.get('https://cdn.test/clubs/logos/a.png');
      expect(poster.validTill, inner.next!.validTill,
          reason: 'only rendered tickets and certificates');
      expect(isRenderedDocumentImage(
              'https://api.test/api/v1/events/tickets/MOA-1/image'),
          isTrue);
    });
  });
}

class _Scripted implements HttpClientAdapter {
  _Scripted(this.requests, this.answers);

  final List<RequestOptions> requests;
  final List<ResponseBody Function()> answers;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    return answers.removeAt(0)();
  }

  @override
  void close({bool force = false}) {}
}

class _FakeFileService extends FileService {
  _Response? next;

  @override
  Future<FileServiceResponse> get(String url,
          {Map<String, String>? headers}) async =>
      next!;
}

class _Response implements FileServiceResponse {
  _Response({this.eTag});

  @override
  final String? eTag;

  @override
  final DateTime validTill = DateTime.now().add(const Duration(minutes: 5));

  @override
  Stream<List<int>> get content => Stream.value(const [1, 2, 3]);

  @override
  int? get contentLength => 3;

  @override
  int get statusCode => 200;

  @override
  String get fileExtension => '.png';
}
