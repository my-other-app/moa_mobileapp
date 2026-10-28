// A certificate as the club designed it: the server's render, kept on the
// phone under the certificate's id, shown at once and offline -- never the
// app's own drawing when the render can be had -- opened from the event in
// the app rather than on the website, and gone at sign-out.

import 'dart:async';
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
import 'package:finnet/features/profile/data/certificate_documents.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/certificate.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_detail_page.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_list_view.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_preview.dart';
import 'package:finnet/features/profile/presentation/pages/certificates/certificate_render.dart';
import 'package:finnet/features/profile/presentation/utils/certificate_share.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:finnet/shared/widgets/rendered_document_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_fakes.dart';
import '../events/events_fakes.dart';

/// The backend's own render of a demo club's certificate -- Respawn Room's
/// layered design from the clubs dashboard, drawn by the backend's renderer
/// (GET /events/certificates/{id}/image, run locally) and scaled down.
final _render = File('test/fixtures/certificate_render.png').readAsBytesSync();

const _id = 'MOA-9ARSE-J4TEG';

final _certificate = Certificate(
  ticketId: _id,
  eventId: 29,
  eventName: 'Rapid Chess Open and Board Game Night',
  clubName: 'Respawn Room',
  issuedOn: DateTime(2026, 10, 2),
);

/// The certificate endpoints: the render and the PDF with ETags (a 304 for
/// a matching If-None-Match), a refusal, a timeout, or no connection.
class _Server implements HttpClientAdapter {
  bool offline = false;
  bool slow = false;
  int? status;
  String imageTag = '"render-v1"';
  Uint8List image = _render;
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
    if (slow) {
      throw DioException.receiveTimeout(
        timeout: const Duration(seconds: 30),
        requestOptions: options,
      );
    }
    final refused = status;
    if (refused != null) {
      return ResponseBody.fromString(
          '{"message":"This certificate was revoked."}', refused,
          headers: {
            'content-type': ['application/json'],
          });
    }
    final isImage = options.path.endsWith('/image');
    final tag = isImage ? imageTag : '"pdf-v1"';
    if (options.headers['If-None-Match'] == tag) {
      return ResponseBody(const Stream.empty(), 304, headers: {
        'etag': [tag],
      });
    }
    return ResponseBody(
      Stream.value(isImage ? image : Uint8List.fromList('%PDF-1.4'.codeUnits)),
      200,
      headers: {
        'content-type': [isImage ? 'image/png' : 'application/pdf'],
        'etag': [tag],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// [CertificateDocuments] without the disk, for the screens (a widget
/// test's clock is fake): kept bytes, and a scripted answer from the
/// server that keeps what it returns, as the real one does.
class _Documents extends CertificateDocuments {
  _Documents({this.kept, this.answer});

  Uint8List? kept;
  Future<({Uint8List bytes, bool current})> Function()? answer;
  final forgotten = <String>[];
  final pdfsKept = <String>[];
  int fetches = 0;

  @override
  Future<Uint8List?> savedImage(String ticketId) async => kept;

  @override
  Future<({Uint8List bytes, bool current})> fetchImage(String ticketId) async {
    fetches++;
    final reply = answer;
    if (reply == null) {
      return Completer<({Uint8List bytes, bool current})>().future;
    }
    final result = await reply();
    kept = result.bytes;
    return result;
  }

  @override
  Future<void> keepPdf(String ticketId, {DateTime? now}) async =>
      pdfsKept.add(ticketId);

  /// The kept PDF, when a test gives one.
  SavedDocument? keptPdf;

  @override
  Future<SavedDocument> pdf(String ticketId) async =>
      keptPdf ?? (throw _noConnection());

  @override
  Future<void> forget(String ticketId) async {
    forgotten.add(ticketId);
    kept = null;
  }
}

DioException _refusal(int status) {
  final options = RequestOptions(path: CertificateDocuments.imagePathFor(_id));
  return DioException.badResponse(
    statusCode: status,
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status),
  );
}

DioException _noConnection() => DioException.connectionError(
      requestOptions:
          RequestOptions(path: CertificateDocuments.imagePathFor(_id)),
      reason: 'offline',
      error: const SocketException('offline'),
    );

class _FakeImageCache extends Fake implements BaseCacheManager {
  @override
  Future<void> emptyCache() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('kept on the phone', () {
    late Directory dir;
    late _Server server;
    late NetworkStatus status;
    late CertificateDocuments documents;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({'access_token': 'a'});
      ApiCache.instance =
          ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
      dir = await Directory.systemTemp.createTemp('certificate_documents');
      server = _Server();
      status = NetworkStatus(probe: () async => false);
      final dio = buildAppDio(status: status, baseUrl: 'https://api.test')
        ..httpClientAdapter = server;
      documents = CertificateDocuments(
        cache: DocumentCache(dio: dio, root: () async => dir),
      );
    });

    tearDown(() async {
      status.reportOnline();
      ApiCache.instance = null;
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    test('opened online once, the render opens with no connection', () async {
      final online = await documents.fetchImage(_id);
      expect(online.current, isTrue);
      expect(online.bytes, _render);

      server.offline = true;
      expect(await documents.savedImage(_id), _render);
      final offline = await documents.fetchImage(_id);
      expect(offline.current, isFalse);
      expect(offline.bytes, _render);
    });

    test('a timeout or a gateway error hands back the kept render too',
        () async {
      await documents.fetchImage(_id);
      server.slow = true;
      expect((await documents.fetchImage(_id)).bytes, _render);
      server
        ..slow = false
        ..status = 503;
      expect((await documents.fetchImage(_id)).current, isFalse);
    });

    test("kept under the certificate's id, checked by its ETag: unchanged "
        'is a 304, a redesign replaces it', () async {
      await documents.fetchImage(_id);
      expect(
          await File('${dir.path}/${CertificateDocuments.imageNameFor(_id)}')
              .exists(),
          isTrue);
      expect(CertificateDocuments.imageNameFor(_id),
          'certificate_MOA-9ARSE-J4TEG.png',
          reason: 'named by the id, never by an address');

      final again = await documents.fetchImage(_id);
      expect(server.requests.last.headers['If-None-Match'], '"render-v1"');
      expect(again.bytes, _render);

      server
        ..imageTag = '"render-v2"'
        ..image = Uint8List.fromList([..._render.take(64), 1, 2, 3]);
      final redesigned = await documents.fetchImage(_id);
      expect(redesigned.current, isTrue);
      expect(redesigned.bytes, server.image);
    });

    test('the list keeps each render and PDF ahead of time; a refused one is '
        'forgotten', () async {
      final kept = <String>[];
      await documents.prefetch([_certificate], onKept: kept.add);
      expect(kept, [_id]);
      expect(
          server.requests.map((r) => r.path),
          containsAll([
            CertificateDocuments.imagePathFor(_id),
            CertificateDocuments.pdfPathFor(_id),
          ]));

      // Never opened, and now offline: both open.
      server.offline = true;
      expect(await documents.savedImage(_id), _render);
      expect((await documents.pdf(_id)).current, isFalse);

      // Fresh: the next list does not ask again.
      server
        ..offline = false
        ..requests.clear();
      await documents.prefetch([_certificate]);
      expect(server.requests, isEmpty);

      // Revoked: the server refuses it, and nothing of it stays.
      server.status = 403;
      await documents.prefetch([_certificate],
          now: DateTime.now().add(const Duration(days: 1)));
      expect(await documents.savedImage(_id), isNull);
    });
  });

  group('the certificate screen', () {
    late NetworkStatus status;

    setUp(() {
      useFakeApi();
      status = NetworkStatus(probe: () async => false);
    });

    Future<void> pump(WidgetTester tester, _Documents documents) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          certificateDocumentsProvider.overrideWithValue(documents),
          networkStatusProvider.overrideWithValue(status),
        ],
        child: MaterialApp(
          home: CertificateDetailPage(certificate: _certificate),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Uint8List? shownBytes(WidgetTester tester) {
      final found = find.byType(RenderedDocumentImage);
      if (found.evaluate().isEmpty) return null;
      final image = tester.widget<RenderedDocumentImage>(found).image;
      return image is MemoryImage ? image.bytes : null;
    }

    testWidgets("shows the club's own render -- the backend's -- not the "
        "app's drawing", (tester) async {
      final documents = _Documents(
          answer: () async => (bytes: _render, current: true));
      await pump(tester, documents);

      expect(shownBytes(tester), _render);
      expect(find.byType(CertificatePreview), findsNothing);
      expect(find.byKey(CertificateRender.fallbackNoticeKey), findsNothing);
      // The PDF too, for Download and Share later with no network.
      expect(documents.pdfsKept, [_id]);

      // And it is drawn: at the render's own shape.
      await tester.runAsync(() async {
        await precacheImage(MemoryImage(_render),
            tester.element(find.byType(RenderedDocumentImage)));
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pump();
      await tester.pump();
      expect(find.byKey(RenderedDocumentImage.imageKey), findsOneWidget);
    });

    testWidgets('opened online once, it opens offline: the kept render and a '
        'note, and nothing asked that cannot answer', (tester) async {
      final documents = _Documents(
          answer: () async => (bytes: _render, current: true));
      await pump(tester, documents);
      expect(shownBytes(tester), _render);
      await tester.pumpWidget(const SizedBox());

      status.reportOffline();
      documents.fetches = 0;
      await pump(tester, documents);

      expect(shownBytes(tester), _render);
      expect(find.byKey(CertificateRender.offlineNoticeKey), findsOneWidget);
      expect(find.byType(CertificatePreview), findsNothing);
      expect(documents.fetches, 0);
      await tester.pumpWidget(const SizedBox());
      status.reportOnline();
    });

    testWidgets('kept, and the server gives no answer: still the kept render',
        (tester) async {
      final documents = _Documents(
          kept: _render, answer: () async => throw _noConnection());
      await pump(tester, documents);

      expect(shownBytes(tester), _render);
      expect(find.byKey(CertificateRender.offlineNoticeKey), findsOneWidget);
      expect(find.byType(CertificatePreview), findsNothing);
    });

    testWidgets("never saved and offline: the app's drawing, marked as a "
        'preview', (tester) async {
      status.reportOffline();
      await pump(tester, _Documents());

      expect(find.byType(CertificatePreview), findsOneWidget);
      expect(find.text(CertificateRender.offlinePreviewNotice), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      status.reportOnline();
    });

    testWidgets("Share sends the certificate's own PDF -- the club's design "
        '-- with its link and number', (tester) async {
      final shared = <(String, String?)>[];
      final documents = _Documents(kept: _render)
        ..keptPdf = SavedDocument(
            file: File('/kept/certificate_$_id.pdf'), current: false);
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      status.reportOffline();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          certificateDocumentsProvider.overrideWithValue(documents),
          networkStatusProvider.overrideWithValue(status),
          certificateSharerProvider.overrideWithValue(
              (text, {subject, origin, pdfPath}) async {
            shared.add((text, pdfPath));
          }),
        ],
        child: MaterialApp(
          home: CertificateDetailPage(certificate: _certificate),
        ),
      ));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('certificate-share')));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(shared.single.$2, '/kept/certificate_$_id.pdf');
      expect(shared.single.$1, contains('CERT-9ARSE-J4TEG'));
      await tester.pumpWidget(const SizedBox());
      status.reportOnline();
    });

    testWidgets('revoked: neither the render nor a drawing, and the kept copy '
        'is deleted', (tester) async {
      final documents =
          _Documents(kept: _render, answer: () async => throw _refusal(403));
      await pump(tester, documents);

      expect(find.byKey(CertificateRender.refusedKey), findsOneWidget);
      expect(shownBytes(tester), isNull);
      expect(find.byType(CertificatePreview), findsNothing);
      expect(documents.forgotten, [_id]);
    });
  });

  testWidgets(
      "the list's thumbnail is the kept render, or a plain slot -- never the "
      "app's drawing", (tester) async {
    Future<void> pump(_Documents documents) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [certificateDocumentsProvider.overrideWithValue(documents)],
        child: const MaterialApp(
          home: SizedBox(
              width: 74, height: 48, child: CertificateThumbnail(ticketId: _id)),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    await pump(_Documents());
    expect(find.byKey(CertificateThumbnail.blankKey), findsOneWidget);
    expect(find.byType(CertificatePreview), findsNothing);

    await pump(_Documents(kept: _render));
    final image = tester.widget<Image>(find.byKey(CertificateThumbnail.renderedKey));
    expect((image.image as ResizeImage).imageProvider, isA<MemoryImage>());
    expect(
        ((image.image as ResizeImage).imageProvider as MemoryImage).bytes,
        _render);
  });

  testWidgets(
      'VIEW CERTIFICATE opens the certificate in the app, not the website',
      (tester) async {
    // The event's card used to open https://myotherapp.in/certificates/...,
    // which draws one stand-in design for every club and keeps nothing.
    final opened = <String>[];
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => Scaffold(
          body: SingleChildScrollView(
            child: EventCard(
              title: 'Rapid Chess Open',
              organizer: 'Respawn Room',
              categoryId: 2,
              categoryName: 'Gaming',
              startsAt: DateTime.utc(2026, 10, 2, 11, 30),
              tags: const ['Gaming'],
              onTap: () {},
              orgImage: '',
              eventId: 29,
              clubId: 1,
              clubSlug: 'respawn-room',
              eventSlug: 'rapid-chess-open',
              status: EventCardStatus.attended,
              certificateUrl: 'https://myotherapp.in/certificates/$_id',
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/certificates/:id',
        builder: (_, state) {
          opened.add(state.pathParameters['id']!);
          return const Scaffold(body: Text('the certificate, in the app'));
        },
      ),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    // Under the card's 4:5 poster, below the test screen's fold.
    await tester.ensureVisible(find.text('VIEW CERTIFICATE'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('VIEW CERTIFICATE'));
    await tester.pumpAndSettle();

    expect(opened, [_id]);
    expect(find.text('the certificate, in the app'), findsOneWidget);
  });

  test("a certificate's address gives its id; anything else none", () {
    expect(certificateIdFromUrl('https://myotherapp.in/certificates/$_id'), _id);
    expect(certificateIdFromUrl('/api/v1/events/certificates/$_id'), _id);
    expect(certificateIdFromUrl('/api/v1/events/certificates/$_id/pdf'), _id);
    expect(
        certificateIdFromUrl('https://myotherapp.in/certificates/$_id?x=1'), _id);
    expect(certificateIdFromUrl('https://myotherapp.in/tickets/$_id'), isNull);
    expect(certificateIdFromUrl(null), isNull);
    expect(certificateRoute(_id), '/certificates/$_id');
  });

  test("signing out deletes the kept certificates and the pins: they are the "
      "person's", () async {
    final dir = await Directory.systemTemp.createTemp('certificate_signout');
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
      'pinned_certificate_ticket_ids': _id,
    });
    ApiCache.instance =
        ApiCache(shared: MemoryCacheStore(), personal: MemoryCacheStore());
    DocumentCache.instance =
        DocumentCache(root: () async => Directory('${dir.path}/documents'));
    AppImageCaches.debugOverride(
        public: _FakeImageCache(), private: _FakeImageCache());
    final render = File(
        '${dir.path}/documents/${CertificateDocuments.imageNameFor(_id)}');
    await render.create(recursive: true);
    await render.writeAsBytes(_render);

    final container = ProviderContainer(overrides: [
      secureStorageServiceProvider.overrideWithValue(storage),
      pushRegistrationProvider.overrideWithValue(FakePushRegistration()),
      sessionRevokerProvider.overrideWithValue(FakeSessionRevoker()),
    ]);
    addTearDown(container.dispose);
    container.read(authStateProvider);
    await Future<void>.delayed(Duration.zero);
    await container.read(authStateProvider.notifier).logout();

    expect(await render.exists(), isFalse);
    expect(storage.values.containsKey('pinned_certificate_ticket_ids'), isFalse);
  });
}
