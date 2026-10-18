import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/network/sse/sse_transport.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers every request with [answer], keeping what was asked.
class _Adapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  late ResponseBody Function() answer;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return answer();
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, int status,
        {Map<String, List<String>>? also}) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...?also,
    });

void main() {
  late _Adapter adapter;
  late Dio dio;
  late List<DioException> reported;
  late DioSseTransport transport;

  setUp(() {
    adapter = _Adapter();
    reported = [];
    // As the app's Dio: its 30 s receive timeout, and interceptors that
    // would log or refresh on an error.
    dio = Dio(BaseOptions(
      baseUrl: 'https://example.test/api/v1',
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
    ))
      ..httpClientAdapter = adapter
      ..interceptors.addAll([
        ErrorInterceptor(),
        InterceptorsWrapper(onError: (e, handler) {
          reported.add(e);
          handler.next(e);
        }),
      ]);
    transport = DioSseTransport(dio);
  });

  test('asks for an event stream, with the caller\'s headers and query',
      () async {
    adapter.answer =
        () => ResponseBody.fromString('retry: 3000\n\n', 200, headers: {
              Headers.contentTypeHeader: ['text/event-stream; charset=utf-8'],
            });

    final res = await transport.open('/events/7/live/stream',
        query: {'view': 'room'}, headers: {'Last-Event-ID': '42'});

    final sent = adapter.requests.single;
    expect(sent.uri.toString(),
        'https://example.test/api/v1/events/7/live/stream?view=room');
    expect(sent.headers['Accept'], 'text/event-stream');
    expect(sent.headers['Cache-Control'], 'no-cache');
    expect(sent.headers['Last-Event-ID'], '42');
    expect(sent.responseType, ResponseType.stream);
    expect(sent.receiveTimeout, Duration.zero,
        reason: 'Dio\'s 30 s between reads would cut a stream between pings');
    expect(res.isEventStream, isTrue);
    expect(utf8.decode(await res.body.expand((c) => c).toList()),
        'retry: 3000\n\n');
  });

  test('a 404 is an answer to read, not an error to report', () async {
    adapter.answer = () => _json({
          'message': 'The live room is not pushed here; poll it.',
          'error_code': 'LIVE_STREAM_OFF',
        }, 404);

    final res = await transport.open('/events/7/live/stream');

    expect(res.statusCode, 404);
    expect(res.isEventStream, isFalse);
    expect(await res.readErrorCode(), 'LIVE_STREAM_OFF');
    expect(reported, isEmpty, reason: 'no analytics error, no token refresh');
  });

  test('a 503 gives its error code and Retry-After', () async {
    adapter.answer = () => _json({'error_code': 'LIVE_STREAM_FULL'}, 503,
        also: {
          'retry-after': ['60'],
        });

    final res = await transport.open('/events/7/live/stream');

    expect(res.statusCode, 503);
    expect(res.retryAfter, const Duration(seconds: 60));
    expect(await res.readErrorCode(), 'LIVE_STREAM_FULL');
  });

  test('a 2xx that is not a stream is not taken for one', () async {
    adapter.answer = () => _json({'event': {}}, 200);
    final res = await transport.open('/events/7/live/stream');
    expect(res.isSuccess, isTrue);
    expect(res.isEventStream, isFalse);
    res.close();
  });

  test('no answer at all is thrown', () async {
    final failing = Dio()
      ..httpClientAdapter = _ThrowingAdapter()
      ..interceptors.add(ErrorInterceptor());
    expect(DioSseTransport(failing).open('/events/7/live/stream'),
        throwsA(isA<DioException>()));
  });

  test('closing, or the abort completing, ends the body', () async {
    for (final viaAbort in [false, true]) {
      final body = StreamController<Uint8List>();
      adapter.answer = () => ResponseBody(body.stream, 200, headers: {
            Headers.contentTypeHeader: ['text/event-stream'],
          });
      final abort = Completer<void>();

      final res =
          await transport.open('/events/7/live/stream', abort: abort.future);
      final ended = Completer<void>();
      res.body.listen((_) {},
          onError: (_) {}, onDone: ended.complete, cancelOnError: false);
      body.add(Uint8List.fromList(utf8.encode('event: ping\n\n')));

      if (viaAbort) {
        abort.complete();
      } else {
        res.close();
      }
      await ended.future.timeout(const Duration(seconds: 2));
      await body.close();
    }
  });
}

class _ThrowingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      throw DioException.connectionError(
          requestOptions: options, reason: 'offline');

  @override
  void close({bool force = false}) {}
}
