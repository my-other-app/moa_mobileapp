// The ticket as the club designed it, kept on the phone: shown at once and
// offline, revalidated by its ETag, gone when revoked or at sign-out, and
// fetched ahead of the event.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/ticket_images.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/auth_fakes.dart';

/// A 1 x 1 PNG.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

/// The ticket image endpoint: a PNG with an ETag, a 304 for a matching
/// If-None-Match, or no connection at all.
class _Renderer implements HttpClientAdapter {
  bool offline = false;
  int? status;
  String? etag = '"v1"';
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
        error: const SocketException('offline'),
      );
    }
    final refused = status;
    if (refused != null) {
      return ResponseBody.fromString('{"message":"no"}', refused, headers: {
        'content-type': ['application/json'],
      });
    }
    final tag = etag;
    if (tag != null && options.headers['If-None-Match'] == tag) {
      return ResponseBody(const Stream.empty(), 304, headers: {
        'etag': [tag],
      });
    }
    return ResponseBody(Stream.value(_png), 200, headers: {
      'content-type': ['image/png'],
      if (tag != null) 'etag': [tag],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// [TicketImages] without the disk, for the screen.
class _Images extends TicketImages {
  _Images({this.kept, this.answer});

  Uint8List? kept;
  Future<({Uint8List bytes, bool current})> Function()? answer;
  final forgotten = <String>[];
  int fetches = 0;

  @override
  Future<Uint8List?> saved(String code) async => kept;

  @override
  Future<({Uint8List bytes, bool current})> fetch(String code) {
    fetches++;
    return answer?.call() ?? Completer<({Uint8List bytes, bool current})>().future;
  }

  @override
  Future<void> forget(String code) async {
    forgotten.add(code);
    kept = null;
  }
}

class _FakeImageCache extends Fake implements BaseCacheManager {
  @override
  Future<void> emptyCache() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TicketImages, on the disk', () {
    late Directory dir;
    late _Renderer renderer;
    late NetworkStatus status;
    late TicketImages images;
    late DocumentCache documents;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({'access_token': 'a'});
      ApiCache.instance =
          ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
      dir = await Directory.systemTemp.createTemp('ticket_images');
      renderer = _Renderer();
      status = NetworkStatus(probe: () async => false);
      final dio = buildAppDio(status: status, baseUrl: 'https://api.test')
        ..httpClientAdapter = renderer;
      documents = DocumentCache(dio: dio, root: () async => dir);
      images = TicketImages(cache: documents);
    });

    tearDown(() async {
      status.reportOnline();
      ApiCache.instance = null;
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('kept once fetched, and shown offline', () async {
      expect(await images.saved('MOA-1'), isNull);
      final fresh = await images.fetch('MOA-1');
      expect(fresh.bytes, _png);
      expect(fresh.current, isTrue);
      expect(await images.saved('MOA-1'), _png);

      renderer.offline = true;
      final offline = await images.fetch('MOA-1');
      expect(offline.bytes, _png);
      expect(offline.current, isFalse);
      expect(renderer.requests.last.extra['noRetry'], isTrue,
          reason: 'no second try at the door');
    });

    test('revalidated by its ETag: a 304 keeps the copy', () async {
      await images.fetch('MOA-1');
      final again = await images.fetch('MOA-1');

      expect(renderer.requests.last.headers['If-None-Match'], '"v1"');
      expect(again.bytes, _png);
      expect(again.current, isTrue);
    });

    test('prefetch: a revoked ticket loses its design; a missing one is '
        'fetched; a recent complete one is not asked for again', () async {
      await images.fetch('MOA-REVOKED');
      await images.fetch('MOA-KEPT');
      renderer.requests.clear();

      await images.prefetch(const [
        SavedTicket(
            code: 'MOA-REVOKED', eventId: 1, eventName: 'A', revoked: true),
        SavedTicket(code: 'MOA-KEPT', eventId: 2, eventName: 'B'),
        SavedTicket(code: 'MOA-NEW', eventId: 3, eventName: 'C'),
      ]);

      expect(await images.saved('MOA-REVOKED'), isNull);
      expect(await images.saved('MOA-NEW'), _png);
      expect(
          renderer.requests
              .map((r) => r.path)
              .where((path) => path.endsWith('/image')),
          ['/events/tickets/MOA-NEW/image']);
    });

    test('prefetch keeps the PDF too: Download and Share open offline '
        'without a tap on Download while online', () async {
      await images.prefetch(const [
        SavedTicket(code: 'MOA-1', eventId: 1, eventName: 'A'),
      ]);

      renderer.offline = true;
      // The ticket screen's Download and Share read this file.
      final pdf = await documents.fetch('/events/tickets/MOA-1/pdf',
          name: 'ticket_MOA-1.pdf');
      expect(pdf.current, isFalse);
      expect(await pdf.file.readAsBytes(), isNotEmpty);
    });

    test('a revoked ticket loses its PDF as well as its design', () async {
      await images.prefetch(const [
        SavedTicket(code: 'MOA-1', eventId: 1, eventName: 'A'),
      ]);
      await images.prefetch(const [
        SavedTicket(code: 'MOA-1', eventId: 1, eventName: 'A', revoked: true),
      ]);
      expect(await documents.kept('ticket_MOA-1.pdf'), isNull);
      expect(await documents.kept(TicketImages.nameFor('MOA-1')), isNull);
    });

    test('prefetch: one that came without an ETag is asked for again, but '
        'not on every refresh', () async {
      renderer.etag = null;
      await images.fetch('MOA-1');
      renderer.requests.clear();
      const tickets = [SavedTicket(code: 'MOA-1', eventId: 1, eventName: 'A')];

      Iterable<RequestOptions> designs() =>
          renderer.requests.where((r) => r.path.endsWith('/image'));
      await images.prefetch(tickets);
      expect(designs(), isEmpty, reason: 'within the hour');

      await images.prefetch(tickets,
          now: DateTime.now().add(const Duration(hours: 2)));
      expect(designs(), hasLength(1));
    });

    test('prefetch carries on past a failure', () async {
      renderer.offline = true;
      await images.prefetch(const [
        SavedTicket(code: 'MOA-1', eventId: 1, eventName: 'A'),
        SavedTicket(code: 'MOA-2', eventId: 2, eventName: 'B'),
      ]);
      expect(renderer.requests, hasLength(2));
    });
  });

  test('signing out deletes the kept designs: they are entry passes',
      () async {
    final dir = await Directory.systemTemp.createTemp('ticket_signout');
    addTearDown(() => dir.delete(recursive: true));
    final previousDocuments = DocumentCache.instance;
    final previousApi = ApiCache.instance;
    addTearDown(() {
      DocumentCache.instance = previousDocuments;
      ApiCache.instance = previousApi;
      AppImageCaches.debugOverride();
    });
    final storage = MemoryStorage({
      'access_token': tokenWithSid('s-1'),
      'refresh_token': 'r',
    });
    ApiCache.instance =
        ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
    DocumentCache.instance =
        DocumentCache(root: () async => Directory('${dir.path}/documents'));
    AppImageCaches.debugOverride(
        public: _FakeImageCache(), private: _FakeImageCache());
    final png = File(
        '${dir.path}/documents/${TicketImages.nameFor('MOA-7K3QF-X9PWM')}');
    await png.create(recursive: true);
    await png.writeAsBytes(_png);

    final container = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(storage),
      pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
      sessionRevokerProvider.overrideWithValue(FakeSessionRevoker()),
    ]);
    addTearDown(container.dispose);
    container.read(authStateProvider);
    await Future<void>.delayed(Duration.zero);
    await container.read(authStateProvider.notifier).logout();

    expect(await png.exists(), isFalse);
  });

  group('the ticket screen', () {
    late NetworkStatus status;

    setUp(() => status = NetworkStatus(probe: () async => false));

    Future<void> pump(WidgetTester tester, _Images images,
        {bool revoked = false}) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: TicketViewPage(
          ticketId: 'MOA-1',
          eventName: 'Hack Night',
          networkStatus: status,
          images: images,
          revoked: revoked,
        ),
      ));
      // The glow animates forever: pump, don't settle.
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      status.reportOnline();
    }

    testWidgets('offline, the club\'s design kept on the phone -- not the '
        'drawn card', (tester) async {
      status.reportOffline();
      final images = _Images(kept: _png);
      await pump(tester, images);

      expect(find.byKey(TicketViewPage.renderedKey), findsOneWidget);
      expect(find.byKey(TicketViewPage.qrKeyFor('MOA-1')), findsNothing,
          reason: 'the drawn card is only for a design never fetched');
      expect(find.byKey(TicketViewPage.offlineNoticeKey), findsOneWidget);
      expect(images.fetches, 0, reason: 'nothing asked that cannot answer');
      await finish(tester);
    });

    testWidgets('a slow render: the kept design with a spinner on it',
        (tester) async {
      final images = _Images(kept: _png); // fetch never answers
      await pump(tester, images);

      expect(find.byKey(TicketViewPage.renderedKey), findsOneWidget);
      expect(find.byKey(TicketViewPage.refreshingKey), findsOneWidget);
      expect(find.byKey(TicketViewPage.qrKeyFor('MOA-1')), findsNothing);
      await finish(tester);
    });

    testWidgets('never fetched and offline: the drawn card, its QR made here',
        (tester) async {
      status.reportOffline();
      await pump(tester, _Images());

      expect(find.byKey(TicketViewPage.renderedKey), findsNothing);
      expect(find.byKey(TicketViewPage.qrKeyFor('MOA-1')), findsOneWidget);
      expect(find.byKey(TicketViewPage.offlineNoticeKey), findsOneWidget);
      await finish(tester);
    });

    testWidgets('revoked: no design and no QR, and the kept design is deleted',
        (tester) async {
      final images = _Images(kept: _png);
      await pump(tester, images, revoked: true);

      expect(find.byKey(TicketViewPage.revokedKey), findsOneWidget);
      expect(find.byKey(TicketViewPage.renderedKey), findsNothing);
      expect(find.byKey(TicketViewPage.qrKeyFor('MOA-1')), findsNothing);
      expect(images.forgotten, ['MOA-1']);
      expect(images.fetches, 0);
      await finish(tester);
    });

    testWidgets('a ticket the server no longer serves loses its kept design',
        (tester) async {
      final images = _Images(
        kept: _png,
        answer: () => Future.error(DioException(
          requestOptions: RequestOptions(path: '/events/tickets/MOA-1/image'),
          response: Response(
            requestOptions:
                RequestOptions(path: '/events/tickets/MOA-1/image'),
            statusCode: 404,
          ),
          type: DioExceptionType.badResponse,
        )),
      );
      await pump(tester, images);

      expect(images.forgotten, ['MOA-1']);
      expect(find.byKey(TicketViewPage.renderedKey), findsNothing);
      await finish(tester);
    });
  });
}
