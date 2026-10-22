import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Serves a PDF whose bytes and ETag a test controls.
class _PdfServer implements HttpClientAdapter {
  String content = 'PDF v1';
  String? etag;
  bool offline = false;

  /// The server took the request and said nothing in time.
  bool slow = false;

  /// What the gateway answers instead of the server (a 502 while it
  /// restarts), when set.
  int? gateway;
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
    if (gateway != null) {
      return ResponseBody.fromString('<html>Bad Gateway</html>', gateway!,
          headers: {
            'content-type': ['text/html'],
          });
    }
    if (etag != null && options.headers['If-None-Match'] == etag) {
      return ResponseBody.fromBytes(const [], 304, headers: {
        'etag': [etag!],
      });
    }
    return ResponseBody.fromBytes(utf8.encode(content), 200, headers: {
      'content-type': ['application/pdf'],
      if (etag != null) 'etag': [etag!],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Directory dir;
  late _PdfServer server;
  late DocumentCache cache;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('documents_test');
    server = _PdfServer();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test/api/v1'))
      ..httpClientAdapter = server
      ..interceptors.add(ErrorInterceptor());
    cache = DocumentCache(dio: dio, root: () async => Directory('${dir.path}/d'));
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  const certificate = '/events/certificates/MOA-1/pdf';
  const ticket = '/events/tickets/MOA-1/pdf';

  test('a certificate is kept and reused while its ETag holds', () async {
    server.etag = '"d1"';

    final first = await cache.fetch(certificate, name: 'certificate_MOA-1.pdf');
    expect(first.current, isTrue);
    expect(await first.file.readAsString(), 'PDF v1');
    expect(server.requests.last.headers['If-None-Match'], isNull);

    final modified = await first.file.lastModified();
    final second = await cache.fetch(certificate, name: 'certificate_MOA-1.pdf');
    expect(server.requests.last.headers['If-None-Match'], '"d1"');
    expect(second.current, isTrue);
    expect(second.file.path, first.file.path);
    expect(await second.file.readAsString(), 'PDF v1');
    expect(await second.file.lastModified(), modified, reason: 'not rewritten');
  });

  test('a redesign or a corrected name is downloaded again, never served '
      'stale', () async {
    server.etag = '"d1"';
    await cache.fetch(certificate, name: 'certificate_MOA-1.pdf');

    server
      ..etag = '"d2"'
      ..content = 'PDF v2 (new design)';
    final again = await cache.fetch(certificate, name: 'certificate_MOA-1.pdf');

    expect(again.current, isTrue);
    expect(await again.file.readAsString(), 'PDF v2 (new design)');
  });

  test('a ticket without validators is fetched in full each time online',
      () async {
    await cache.fetch(ticket, name: 'ticket_MOA-1.pdf');
    server.content = 'PDF with the new name';

    final again = await cache.fetch(ticket, name: 'ticket_MOA-1.pdf');

    expect(server.requests.last.headers['If-None-Match'], isNull);
    expect(await again.file.readAsString(), 'PDF with the new name');
  });

  test('offline, the kept copy, marked not current', () async {
    await cache.fetch(ticket, name: 'ticket_MOA-1.pdf');
    server.offline = true;

    final kept = await cache.fetch(ticket, name: 'ticket_MOA-1.pdf');

    expect(kept.current, isFalse);
    expect(await kept.file.readAsString(), 'PDF v1');
  });

  test('a timeout, or the gateway answering for a server that is down, '
      'hands back the kept copy too', () async {
    // The owner's report: "not cached". A ticket's PDF failed to open on a
    // slow signal and during every deploy (the API is a 502 for a minute),
    // though a copy was on the phone: only a refused connection used it.
    await cache.fetch(ticket, name: 'ticket_MOA-1.pdf');

    server.slow = true;
    final slow = await cache.fetch(ticket, name: 'ticket_MOA-1.pdf');
    expect(slow.current, isFalse);
    expect(await slow.file.readAsString(), 'PDF v1');

    server
      ..slow = false
      ..gateway = 502;
    final down = await cache.fetch(ticket, name: 'ticket_MOA-1.pdf');
    expect(down.current, isFalse);
    expect(await down.file.readAsString(), 'PDF v1');
  });

  test('a refusal is an answer: passed on, not covered by the kept copy',
      () async {
    await cache.fetch(ticket, name: 'ticket_MOA-1.pdf');
    server.gateway = 403;
    await expectLater(cache.fetch(ticket, name: 'ticket_MOA-1.pdf'),
        throwsA(isA<DioException>()));
  });

  test('kept for good: nothing deletes a copy for its age, and the cap '
      'takes the least recently saved first', () async {
    final old = await cache.fetch(certificate, name: 'certificate_OLD.pdf');
    await old.file.setLastModified(
        DateTime.now().subtract(const Duration(days: 400)));
    server.content = 'a newer, larger document';
    await cache.fetch(certificate, name: 'certificate_NEW.pdf');

    // Under the cap, a year-old certificate stays, and opens offline.
    await cache.trim(budget: 1024);
    server.offline = true;
    expect((await cache.fetch(certificate, name: 'certificate_OLD.pdf')).current,
        isFalse);

    // Over it, the oldest goes -- with its validators -- and no more.
    await cache.trim(budget: 'a newer, larger document'.length);
    expect(await cache.kept('certificate_OLD.pdf'), isNull);
    expect(await File('${old.file.path}.meta.json').exists(), isFalse);
    expect(await cache.kept('certificate_NEW.pdf'), isNotNull);
  });

  test('offline with nothing kept is an error', () async {
    server.offline = true;
    await expectLater(cache.fetch(ticket, name: 'ticket_MOA-1.pdf'),
        throwsA(isA<DioException>()));
  });

  test('a version from the API that matches skips the network', () async {
    // A final copy: it came with its tag.
    server.etag = '"3-0123456789abcdef01234567"';
    await cache.fetch(certificate, name: 'c.pdf', version: '3');
    final count = server.requests.length;

    final again = await cache.fetch(certificate, name: 'c.pdf', version: '3');
    expect(again.current, isTrue);
    expect(server.requests.length, count);

    server
      ..content = 'v4'
      ..etag = '"4-0123456789abcdef01234567"';
    final newer = await cache.fetch(certificate, name: 'c.pdf', version: '4');
    expect(await newer.file.readAsString(), 'v4');
  });

  test('a name is made safe for the file system', () {
    expect(DocumentCache.safeName('ticket_MOA-1/../x?.pdf'),
        'ticket_MOA-1_.._x_.pdf');
  });

  test('clear deletes every kept document', () async {
    final kept = await cache.fetch(ticket, name: 'ticket_MOA-1.pdf');
    await cache.clear();
    expect(await kept.file.exists(), isFalse);
  });
}
