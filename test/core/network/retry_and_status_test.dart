import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/network/interceptors/retry_interceptor.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/shared/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Answers by path; a handler that throws a [SocketException] is a request
/// that never reached the server.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.handlers);

  final Map<String, FutureOr<ResponseBody> Function(RequestOptions)> handlers;
  final calls = <String, int>{};

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final key = '${options.method} ${options.path}';
    calls[key] = (calls[key] ?? 0) + 1;
    final handler = handlers[key];
    if (handler == null) return ResponseBody.fromString('{}', 404);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _ok([String body = '{"ok":true}']) => ResponseBody.fromString(
    body, 200,
    headers: {
      'content-type': ['application/json'],
    });

Never _offline(RequestOptions options) =>
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'Failed host lookup',
      error: const SocketException('Failed host lookup'),
    );

({Dio dio, _Adapter adapter, List<Duration> slept, NetworkStatus status})
    _setUp(Map<String, FutureOr<ResponseBody> Function(RequestOptions)> handlers) {
  final slept = <Duration>[];
  final status = NetworkStatus(probe: () async => false);
  final adapter = _Adapter(handlers);
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
    ..httpClientAdapter = adapter;
  dio.interceptors.addAll([
    RetryInterceptor(dio, sleep: (d) async => slept.add(d)),
    NetworkStatusInterceptor(status),
    ErrorInterceptor(),
  ]);
  return (dio: dio, adapter: adapter, slept: slept, status: status);
}

void main() {
  group('RetryInterceptor', () {
    test('a GET that could not connect is sent once more, after a pause',
        () async {
      var attempt = 0;
      final t = _setUp({
        'GET /events/list': (o) => attempt++ == 0 ? _offline(o) : _ok(),
      });

      final response = await t.dio.get('/events/list');

      expect(response.statusCode, 200);
      expect(t.adapter.calls['GET /events/list'], 2);
      expect(t.slept, hasLength(1));
      expect(t.slept.single, greaterThanOrEqualTo(const Duration(milliseconds: 700)));
      expect(t.status.isOffline, isFalse);
    });

    test('only once: a second failure is reported, and the app is offline',
        () async {
      final t = _setUp({'GET /events/list': _offline});

      await expectLater(t.dio.get('/events/list'), throwsA(isA<DioException>()));

      expect(t.adapter.calls['GET /events/list'], 2);
      expect(t.status.isOffline, isTrue);
    });

    test('a POST is never sent twice', () async {
      final t = _setUp({'POST /events/registration/7/register': _offline});

      await expectLater(
        t.dio.post('/events/registration/7/register', data: {'a': 1}),
        throwsA(isA<DioException>()),
      );

      expect(t.adapter.calls['POST /events/registration/7/register'], 1);
      expect(t.slept, isEmpty);
    });

    test('nor a PUT, PATCH or DELETE', () async {
      final t = _setUp({
        'PUT /x': _offline,
        'PATCH /x': _offline,
        'DELETE /x': _offline,
      });

      for (final send in [t.dio.put, t.dio.patch, t.dio.delete]) {
        await expectLater(send('/x'), throwsA(isA<DioException>()));
      }

      expect(t.adapter.calls['PUT /x'], 1);
      expect(t.adapter.calls['PATCH /x'], 1);
      expect(t.adapter.calls['DELETE /x'], 1);
    });

    test('an answer is not retried, whatever its status', () async {
      final t = _setUp({
        'GET /boom': (_) => ResponseBody.fromString('{"message":"x"}', 500,
            headers: {
              'content-type': ['application/json'],
            }),
      });

      await expectLater(t.dio.get('/boom'), throwsA(isA<DioException>()));

      expect(t.adapter.calls['GET /boom'], 1);
      expect(t.status.isOffline, isFalse);
    });

    test('a stream, or a request that asks not to be, is not retried',
        () async {
      final t = _setUp({'GET /live': _offline, 'GET /once': _offline});

      await expectLater(
        t.dio.get('/live', options: Options(responseType: ResponseType.stream)),
        throwsA(isA<DioException>()),
      );
      await expectLater(
        t.dio.get('/once',
            options: Options(extra: {RetryInterceptor.noRetryKey: true})),
        throwsA(isA<DioException>()),
      );

      expect(t.adapter.calls['GET /live'], 1);
      expect(t.adapter.calls['GET /once'], 1);
    });
  });

  group('NetworkStatus', () {
    test('offline on no answer, online again on any answer', () async {
      var online = false;
      final t = _setUp({
        'GET /a': (o) => online ? _ok() : _offline(o),
      });

      await t.dio.get('/a').catchError((Object _) => Response(
          requestOptions: RequestOptions()));
      expect(t.status.isOffline, isTrue);

      online = true;
      await t.dio.get('/a');
      expect(t.status.isOffline, isFalse);
    });

    test('the probe brings it back online without a request', () async {
      var reachable = false;
      final status = NetworkStatus(
        probe: () async => reachable,
        probeEvery: const Duration(milliseconds: 10),
      );
      addTearDown(status.dispose);

      status.reportOffline();
      expect(await status.checkNow(), isFalse);

      reachable = true;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(status.isOffline, isFalse);
    });
  });

  group('OfflineBanner', () {
    testWidgets('shows while offline, and the screen keeps its state',
        (tester) async {
      final status = NetworkStatus(probe: () async => false);
      addTearDown(status.dispose);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => OfflineBanner(status: status, child: child!),
        home: const _Counter(),
      ));

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
      expect(find.text(OfflineBanner.message), findsNothing);

      status.reportOffline();
      await tester.pumpAndSettle();
      expect(find.text(OfflineBanner.message), findsOneWidget);
      expect(find.text('1'), findsOneWidget, reason: 'state kept');

      status.reportOnline();
      await tester.pumpAndSettle();
      expect(find.text(OfflineBanner.message), findsNothing);
      expect(find.text('1'), findsOneWidget, reason: 'state kept');
    });
  });

  group('logApiErrorQuietly', () {
    test('a logger that throws, or fails later, never reaches the request',
        () async {
      final error = DioException(requestOptions: RequestOptions(path: '/x'));

      expect(
        () => logApiErrorQuietly(error, log: (_, __, ___) => throw StateError('no Firebase')),
        returnsNormally,
      );
      logApiErrorQuietly(error,
          log: (_, __, ___) => Future<void>.error(StateError('later')));
      await Future<void>.delayed(Duration.zero);
    });
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int n = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Column(children: [
          Text('$n'),
          ElevatedButton(onPressed: () => setState(() => n++), child: const Text('+')),
        ]),
      );
}
