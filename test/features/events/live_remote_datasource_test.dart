import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/events/data/datasources/live_remote_datasource.dart';
import 'package:flutter_test/flutter_test.dart';

class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int status = 200;
  Object body = const <String, dynamic>{};
  String contentType = Headers.jsonContentType;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      body is String ? body as String : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late LiveRemoteDataSource source;

  setUp(() {
    adapter = _Adapter();
    source = LiveRemoteDataSourceImpl(
      Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ErrorInterceptor()),
    );
  });

  group('the poll', () {
    test('is GET /events/{id}/live, read as the room', () async {
      adapter.body = {
        'event': {'id': 7},
        'banner': {'kind': 'room', 'text': 'Demos move to Lab 3B'},
      };

      final feed = await source.fetchRoom(7);

      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/events/7/live');
      expect(feed!.headline, 'Demos move to Lab 3B');
    });

    test('a body that is not the room is null', () async {
      adapter.body = ['not', 'a', 'room'];
      expect(await source.fetchRoom(7), isNull);
    });

    test('a failure is thrown, with its status', () async {
      adapter
        ..status = 404
        ..body = {'message': 'Event not found'};
      Object? error;
      try {
        await source.fetchRoom(7);
      } catch (e) {
        error = e;
      }
      expect(statusCodeOf(error), 404);
    });
  });

  group('the stream', () {
    test('is the room view of /events/{id}/live/stream', () async {
      adapter
        ..contentType = 'text/event-stream'
        ..body = 'retry: 3000\n\n';

      final res = await source.openRoomStream(7);

      final sent = adapter.requests.single;
      expect(sent.path, '/events/7/live/stream');
      expect(sent.queryParameters, {'view': 'room'});
      expect(sent.headers['Accept'], 'text/event-stream');
      expect(sent.headers.containsKey('Last-Event-ID'), isFalse);
      expect(sent.headers.containsKey('X-Live-Key'), isFalse,
          reason: 'the poll sends no browser key either');
      expect(res.isEventStream, isTrue);
      res.close();
    });

    test('resumes from the last id it is given', () async {
      adapter.contentType = 'text/event-stream';
      final res = await source.openRoomStream(7, lastEventId: '1760793812');
      expect(adapter.requests.single.headers['Last-Event-ID'], '1760793812');
      res.close();
    });

    test('today\'s server, without streams: a 404 to read, not thrown',
        () async {
      adapter
        ..status = 404
        ..body = {
          'message': 'The live room is not pushed here; poll it.',
          'error_code': 'LIVE_STREAM_OFF',
        };
      final res = await source.openRoomStream(7);
      expect(res.statusCode, 404);
      expect(res.isEventStream, isFalse);
      res.close();
    });
  });
}
