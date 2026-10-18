import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:finnet/common/models/events/live_model.dart';
import 'package:finnet/core/network/sse/sse_transport.dart';
import 'package:finnet/features/events/data/live/live_stream_client.dart';
import 'package:flutter_test/flutter_test.dart';

/// One open of the stream, answered by the test.
class _Conn {
  _Conn(this.lastEventId, Future<void> abort, {this.ignoresAbort = false}) {
    abort.then((_) => _closedByClient());
  }

  final String? lastEventId;

  /// A transport whose open is not cut short by the abort: its answer can
  /// still arrive after the client has let go.
  final bool ignoresAbort;
  final _answer = Completer<SseResponse>();
  StreamController<List<int>>? _body;
  bool closedByClient = false;
  bool endedByServer = false;

  /// The client closed the response it was given.
  bool responseClosed = false;

  /// Open, as far as the client is concerned: not yet let go of, not ended.
  bool get live => !closedByClient && !endedByServer;

  void _closedByClient() {
    if (closedByClient) return;
    closedByClient = true;
    if (!_answer.isCompleted && !ignoresAbort) {
      _answer.completeError(StateError('cancelled'));
    }
    _body?.close();
  }

  void accept() {
    _body = StreamController<List<int>>();
    _answer.complete(SseResponse(
      statusCode: 200,
      headers: {
        'content-type': ['text/event-stream; charset=utf-8'],
      },
      body: _body!.stream,
      onClose: () {
        responseClosed = true;
        _closedByClient();
      },
    ));
  }

  void refuse(int status,
      {Object? body, Map<String, List<String>> headers = const {}}) {
    _answer.complete(SseResponse(
      statusCode: status,
      headers: {
        'content-type': ['application/json'],
        ...headers,
      },
      body: Stream.value(utf8.encode(jsonEncode(body ?? {}))),
    ));
  }

  void fail() => _answer.completeError(StateError('no network'));

  void send(String text) => _body!.add(utf8.encode(text));

  void snapshot(String banner, {required String id, String status = 'live'}) =>
      send('id: $id\nevent: snapshot\n'
          'data: ${jsonEncode(_room(banner, status: status))}\n\n');

  void ping() => send('event: ping\ndata: {"t":1760793827345}\n\n');

  void end() {
    endedByServer = true;
    _body!.close();
  }
}

class _Server {
  final conns = <_Conn>[];
  bool ignoreAborts = false;

  Future<SseResponse> open({
    String? lastEventId,
    required Future<void> abort,
  }) {
    final conn = _Conn(lastEventId, abort, ignoresAbort: ignoreAborts);
    conns.add(conn);
    return conn._answer.future;
  }

  _Conn get last => conns.last;

  int get live => conns.where((c) => c.live).length;
}

class _Jitter implements Random {
  _Jitter([this.value = 0]);

  double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}

Map<String, dynamic> _room(String banner, {String status = 'live'}) => {
      'event': {'id': 7, 'name': 'Hack Night', 'status': status},
      'banner': {'kind': 'room', 'text': banner},
      'poll': null,
      'questions': <dynamic>[],
      'quiz': {'live': false, 'title': null},
    };

const _fullBody = {
  'message': 'Too many live streams here; poll for now.',
  'error_code': 'LIVE_STREAM_FULL',
};

void main() {
  late _Server server;
  late List<String> shown;
  late int polls;
  late String pollBanner;
  late String pollStatus;
  Object? pollError;
  Completer<void>? pollGate;

  LiveStreamClient<LiveFeed> client({double jitter = 0}) =>
      LiveStreamClient<LiveFeed>(
        open: server.open,
        poll: () async {
          polls++;
          if (pollGate != null) await pollGate!.future;
          if (pollError != null) throw pollError!;
          return LiveFeed.tryParse(_room(pollBanner, status: pollStatus));
        },
        parse: LiveFeed.tryParse,
        onData: (feed) => shown.add(feed.headline),
        shouldStream: (feed) => feed.isEventLive,
        random: _Jitter(jitter),
      );

  /// Started on a live event: the page's fetch has come back, and the
  /// stream is being opened.
  LiveStreamClient<LiveFeed> started(FakeAsync async, {double jitter = 0}) {
    final live = client(jitter: jitter)..start();
    async.flushMicrotasks();
    expect(polls, 1);
    expect(server.conns, hasLength(1));
    return live;
  }

  setUp(() {
    server = _Server();
    shown = [];
    polls = 0;
    pollBanner = 'From the poll';
    pollStatus = 'live';
    pollError = null;
    pollGate = null;
  });

  group('only while the event is live', () {
    test('not live: the one fetch, as before, and no stream', () {
      fakeAsync((async) {
        pollStatus = 'published';
        final live = client()..start();
        async.flushMicrotasks();
        expect(polls, 1);
        expect(shown, ['From the poll']);
        expect(server.conns, isEmpty);
        expect(live.mode, LiveMode.notLive);

        async.elapse(const Duration(hours: 3));
        expect(polls, 1);
        expect(server.conns, isEmpty);
        expect(async.pendingTimers, isEmpty);
        live.close();
      });
    });

    test('ended: the one fetch, and no stream', () {
      fakeAsync((async) {
        pollStatus = 'closed';
        final live = client()..start();
        async.flushMicrotasks();
        expect(server.conns, isEmpty);
        expect(live.mode, LiveMode.notLive);
        live.close();
      });
    });

    test('live: the fetch first, then the stream', () {
      fakeAsync((async) {
        final live = started(async);
        expect(server.last.lastEventId, isNull);
        expect(live.mode, LiveMode.connecting);
        expect(shown, ['From the poll']);
        live.close();
      });
    });

    test('goes live while the page is open: the reload\'s fetch opens it', () {
      fakeAsync((async) {
        pollStatus = 'published';
        final live = client()..start();
        async.flushMicrotasks();
        expect(server.conns, isEmpty);

        pollStatus = 'live';
        live.refresh();
        async.flushMicrotasks();
        expect(polls, 2);
        expect(server.conns, hasLength(1));
        expect(live.mode, LiveMode.connecting);
        live.close();
      });
    });

    test('a snapshot saying the event has ended closes the stream', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('Demos', id: '1')
          ..snapshot('Thanks for coming', id: '2', status: 'closed');
        async.flushMicrotasks();
        expect(shown.last, 'Thanks for coming');
        expect(server.conns.single.closedByClient, isTrue);
        expect(live.mode, LiveMode.notLive);

        async.elapse(const Duration(hours: 1));
        expect(server.conns, hasLength(1), reason: 'not reopened');
        expect(polls, 1, reason: 'nothing fetched on a timer');
        expect(async.pendingTimers, isEmpty);

        // A reload fetches, as it always has; still over, so no stream.
        pollStatus = 'closed';
        live.refresh();
        async.flushMicrotasks();
        expect(polls, 2);
        expect(server.conns, hasLength(1));
        live.close();
      });
    });

    test('a fetch that fails opens nothing, and shows nothing', () {
      fakeAsync((async) {
        pollError = StateError('offline');
        final live = client()..start();
        async.flushMicrotasks();
        expect(server.conns, isEmpty);
        expect(shown, isEmpty);
        live.close();
      });
    });
  });

  group('the stream', () {
    test('a snapshot is the poll\'s body, read with the poll\'s parser', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..send('retry: 3000\n\n');
        async.flushMicrotasks();
        expect(live.mode, LiveMode.connecting,
            reason: 'retry: alone is not a frame that proves the stream');

        server.last.snapshot('Demos move to Lab 3B', id: '11');
        async.flushMicrotasks();
        expect(shown, ['From the poll', 'Demos move to Lab 3B']);
        expect(live.mode, LiveMode.streaming);
        expect(live.lastEventId, '11');

        server.last.snapshot('Doors close at 9', id: '12');
        async.flushMicrotasks();
        expect(shown.last, 'Doors close at 9');
        expect(polls, 1, reason: 'the stream replaces the fetch');
        live.close();
      });
    });

    test('a snapshot it cannot read is skipped; the stream stays', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..send('id: 5\nevent: snapshot\ndata: {"banner": \n\n');
        async.flushMicrotasks();
        expect(shown, ['From the poll']);
        expect(live.mode, LiveMode.streaming);
        expect(server.live, 1);
        live.close();
      });
    });

    test(
        'the server ending a stream: reopened after its retry, with the last '
        'snapshot\'s id (a ping leaves it)', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..send('retry: 4000\n\n')
          ..snapshot('Demos', id: '11')
          ..ping()
          ..end();
        async.flushMicrotasks();
        expect(live.mode, LiveMode.reconnecting);
        expect(live.lastEventId, '11');

        async.elapse(const Duration(milliseconds: 3999));
        expect(server.conns, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(server.conns, hasLength(2));
        expect(server.last.lastEventId, '11');

        // Nothing changed since 11: the server sends a ping, not a snapshot.
        server.last
          ..accept()
          ..ping();
        async.flushMicrotasks();
        expect(live.mode, LiveMode.streaming);
        expect(shown, ['From the poll', 'Demos']);
        expect(polls, 1);
        live.close();
      });
    });

    test('the reconnect delay gets 0-100 % jitter on top', () {
      fakeAsync((async) {
        final live = started(async, jitter: 0.5);
        server.last
          ..accept()
          ..send('retry: 2000\n\n')
          ..ping()
          ..end();
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 2999));
        expect(server.conns, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(server.conns, hasLength(2));
        live.close();
      });
    });

    test('45 s without a frame: dropped and reopened', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('Demos', id: '11');
        async.flushMicrotasks();

        async.elapse(const Duration(seconds: 44));
        expect(server.conns.single.live, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(server.conns.single.closedByClient, isTrue);
        expect(live.mode, LiveMode.reconnecting);

        async.elapse(LiveStreamClient.defaultRetry);
        expect(server.conns, hasLength(2));
        expect(server.last.lastEventId, '11');
        live.close();
      });
    });

    test('pings every 15 s keep a stream open', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('Demos', id: '11');
        for (var i = 0; i < 20; i++) {
          async.elapse(const Duration(seconds: 15));
          server.last.ping();
          async.flushMicrotasks();
        }
        expect(server.conns, hasLength(1));
        expect(server.last.live, isTrue);
        live.close();
      });
    });

    test('no snapshot or ping 20 s after opening: a failed attempt', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..send('retry: 3000\n\n');
        async.elapse(const Duration(seconds: 19));
        expect(server.last.live, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(server.conns.single.closedByClient, isTrue);
        expect(live.mode, LiveMode.reconnecting);
        expect(polls, 1, reason: 'the page shows the fetch already');
        live.close();
      });
    });

    test('an open that hangs is given up on after 20 s too', () {
      fakeAsync((async) {
        final live = started(async);
        async.elapse(const Duration(seconds: 20));
        expect(server.conns.single.closedByClient, isTrue);
        expect(live.mode, LiveMode.reconnecting);
        live.close();
      });
    });

    test('a newer stream wins over a fetch answered late', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('A', id: '1')
          ..end();
        async.elapse(LiveStreamClient.defaultRetry);
        pollGate = Completer<void>();
        server.last.fail(); // after the stream: one fetch goes out, slow
        async.flushMicrotasks();
        expect(polls, 2);

        async.elapse(LiveStreamClient.defaultRetry);
        server.last
          ..accept()
          ..snapshot('From the stream', id: '3');
        async.flushMicrotasks();

        pollGate!.complete();
        async.flushMicrotasks();
        expect(shown.last, 'From the stream');
        live.close();
      });
    });
  });

  group('falling back: one fetch, never a timer', () {
    for (final status in [404, 405, 501, 422]) {
      test('$status: the page does what it did before streams', () {
        fakeAsync((async) {
          final live = started(async);
          server.last.refuse(status, body: {
            'message': 'The live room is not pushed here; poll it.',
            'error_code': 'LIVE_STREAM_OFF',
          });
          async.flushMicrotasks();

          // Exactly what the event page always did: the one fetch.
          expect(live.mode, LiveMode.off);
          expect(polls, 1);
          expect(shown, ['From the poll']);
          async.elapse(const Duration(minutes: 9, seconds: 59));
          expect(server.conns, hasLength(1));
          expect(polls, 1, reason: 'nothing on a timer');

          // The stream is asked once more, ten minutes on...
          async.elapse(const Duration(seconds: 1));
          expect(server.conns, hasLength(2));
          server.last.refuse(status);
          async.flushMicrotasks();

          // ... and never again; and still off is no reason to fetch.
          async.elapse(const Duration(hours: 3));
          expect(server.conns, hasLength(2));
          expect(polls, 1);
          expect(async.pendingTimers, isEmpty);
          live.close();
        });
      });
    }

    test('a 2xx that is not a stream is a server without streams', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.refuse(200, body: _room('A poll body'));
        async.flushMicrotasks();
        expect(live.mode, LiveMode.off);
        expect(polls, 1);
        live.close();
      });
    });

    test('streams switched on later are found by the ten-minute retry', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.refuse(404);
        async.elapse(LiveStreamClient.retryWhenOff);
        server.last
          ..accept()
          ..snapshot('Now streamed', id: '1');
        async.flushMicrotasks();
        expect(live.mode, LiveMode.streaming);
        expect(shown, ['From the poll', 'Now streamed']);
        live.close();
      });
    });

    test(
        '503 LIVE_STREAM_FULL: no fetch on a timer; the stream again after '
        'Retry-After', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.refuse(503, body: _fullBody, headers: {
          'retry-after': ['30'],
        });
        async.flushMicrotasks();
        expect(live.mode, LiveMode.polling);
        expect(polls, 1, reason: 'the page shows the fetch already');

        async.elapse(const Duration(seconds: 29));
        expect(polls, 1);
        expect(server.conns, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(server.conns, hasLength(2), reason: 'Retry-After: 30');

        // Still full: the same again, still no fetch.
        server.last.refuse(503, body: _fullBody);
        async.elapse(const Duration(seconds: 60));
        expect(server.conns, hasLength(3));
        expect(polls, 1);

        server.last
          ..accept()
          ..ping();
        async.flushMicrotasks();
        expect(live.mode, LiveMode.streaming);
        live.close();
      });
    });

    test('503 LIVE_STREAM_FULL without Retry-After waits 60 s', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.refuse(503, body: _fullBody);
        async.elapse(const Duration(seconds: 59));
        expect(server.conns, hasLength(1));
        async.elapse(const Duration(seconds: 1));
        expect(server.conns, hasLength(2));
        live.close();
      });
    });

    test('a full server after the stream had been the source: one fetch', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('Demos', id: '1')
          ..end();
        async.elapse(LiveStreamClient.defaultRetry);
        server.last.refuse(503, body: _fullBody);
        async.flushMicrotasks();
        expect(polls, 2, reason: 'what the stream missed, fetched once');
        async.elapse(const Duration(minutes: 30));
        expect(polls, 2, reason: 'and not again, however long it stays full');
        live.close();
      });
    });

    test('429 waits for Retry-After, fetching nothing', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.refuse(429, headers: {
          'retry-after': ['10'],
        });
        async.flushMicrotasks();
        expect(live.mode, LiveMode.polling);
        expect(polls, 1);
        async.elapse(const Duration(seconds: 10));
        expect(server.conns, hasLength(2));
        live.close();
      });
    });

    test('a 503 without LIVE_STREAM_FULL (a gateway) is a failed attempt', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.refuse(503, body: {'message': 'Service Unavailable'});
        async.flushMicrotasks();
        expect(live.mode, LiveMode.reconnecting);
        async.elapse(LiveStreamClient.defaultRetry);
        expect(server.conns, hasLength(2));
        live.close();
      });
    });

    test(
        'three failed attempts in a row (3 s, then 6 s apart): the stream '
        'again in 5 minutes, and nothing fetched meanwhile', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.fail();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 2999));
        expect(server.conns, hasLength(1));
        async.elapse(const Duration(milliseconds: 1));
        expect(server.conns, hasLength(2));
        server.last.fail();
        async.flushMicrotasks();

        async.elapse(const Duration(milliseconds: 5999));
        expect(server.conns, hasLength(2));
        async.elapse(const Duration(milliseconds: 1));
        expect(server.conns, hasLength(3));
        server.last.fail();
        async.flushMicrotasks();

        expect(live.mode, LiveMode.polling);
        expect(polls, 1, reason: 'the page shows the fetch already');
        async.elapse(const Duration(minutes: 4, seconds: 59));
        expect(polls, 1);
        expect(server.conns, hasLength(3));
        async.elapse(const Duration(seconds: 1));
        expect(server.conns, hasLength(4));
        live.close();
      });
    });

    test('a stream that worked and then fails: one fetch, not a timer', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('Demos', id: '1')
          ..end();
        async.flushMicrotasks();
        // Reconnects 3 s after the end, 3 s after the first failure, 6 s
        // after the second; the third falls back.
        for (final wait in const [3, 3, 6]) {
          async.elapse(Duration(seconds: wait));
          server.last.fail();
          async.flushMicrotasks();
        }
        expect(server.conns, hasLength(4));
        expect(live.mode, LiveMode.polling);
        expect(polls, 2, reason: 'one fetch, at the first failure');
        async.elapse(const Duration(minutes: 4));
        expect(polls, 2);
        live.close();
      });
    });

    test('the doubled delay stops at 30 s (before jitter)', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..send('retry: 20000\n\n')
          ..ping()
          ..end();
        async.flushMicrotasks();
        // 20 s for the first reconnect...
        async.elapse(const Duration(seconds: 20));
        expect(server.conns, hasLength(2));
        server.last.fail();
        async.flushMicrotasks();
        // ... 20 s again after the first failure, then 40 s capped to 30.
        async.elapse(const Duration(seconds: 20));
        expect(server.conns, hasLength(3));
        server.last.fail();
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 29));
        expect(server.conns, hasLength(3));
        async.elapse(const Duration(seconds: 1));
        expect(server.conns, hasLength(4));
        live.close();
      });
    });

    test('401: handled by the poll first, then the stream again', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.refuse(401);
        async.flushMicrotasks();
        expect(polls, 2);
        expect(live.mode, LiveMode.reconnecting);
        async.elapse(LiveStreamClient.defaultRetry);
        expect(server.conns, hasLength(2));
        live.close();
      });
    });

    test('gone: closed, never reopened; one fetch says what to show', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('Demos', id: '9');
        async.flushMicrotasks();
        pollBanner = 'Confirmed by the poll';
        server.last
            .send('event: gone\ndata: {"status":404,"message":"Gone"}\n\n');
        async.flushMicrotasks();

        expect(live.mode, LiveMode.gone);
        expect(server.conns.single.closedByClient, isTrue);
        expect(polls, 2);
        expect(shown.last, 'Confirmed by the poll');
        async.elapse(const Duration(hours: 1));
        expect(server.conns, hasLength(1));
        expect(polls, 2);
        expect(async.pendingTimers, isEmpty);
        live.close();
      });
    });

    test('gone with a fetch that fails leaves the page as it is', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('Demos', id: '9');
        async.flushMicrotasks();
        pollError = StateError('404');
        server.last.send('event: gone\ndata: {"status":404}\n\n');
        async.flushMicrotasks();
        expect(shown.last, 'Demos');
        expect(live.mode, LiveMode.gone);
        live.close();
      });
    });
  });

  group('the app in the background', () {
    test('closes after 30 s hidden; reopens with the last id when back', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('Demos', id: '11');
        async.flushMicrotasks();

        live.hidden();
        async.elapse(const Duration(seconds: 29));
        expect(server.last.live, isTrue);
        async.elapse(const Duration(seconds: 1));
        expect(server.conns.single.closedByClient, isTrue);
        expect(live.mode, LiveMode.paused);

        async.elapse(const Duration(minutes: 20));
        expect(server.conns, hasLength(1), reason: 'nothing while hidden');
        expect(polls, 1);

        live.shown();
        async.flushMicrotasks();
        expect(server.conns, hasLength(2));
        expect(server.last.lastEventId, '11');
        live.close();
      });
    });

    test('back within 30 s: the same stream, untouched', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..snapshot('Demos', id: '11');
        async.flushMicrotasks();
        live.hidden();
        async.elapse(const Duration(seconds: 10));
        live.shown();
        async.elapse(const Duration(seconds: 30));
        expect(server.conns, hasLength(1));
        expect(server.last.live, isTrue);
        live.close();
      });
    });

    test('hidden and shown twice over: still one stream', () {
      fakeAsync((async) {
        final live = started(async);
        server.last
          ..accept()
          ..ping();
        live
          ..hidden()
          ..hidden();
        async.elapse(const Duration(seconds: 31));
        live
          ..shown()
          ..shown();
        async.flushMicrotasks();
        expect(server.conns, hasLength(2));
        expect(server.live, 1);
        live.close();
      });
    });

    test('reconnecting stops in the background, and starts again on return',
        () {
      fakeAsync((async) {
        final live = started(async);
        server.last.fail();
        async.flushMicrotasks();
        live.hidden();
        async.elapse(const Duration(seconds: 30));
        expect(live.mode, LiveMode.paused);
        expect(server.live, 0);
        final opened = server.conns.length;

        async.elapse(const Duration(minutes: 10));
        expect(server.conns, hasLength(opened), reason: 'nothing while hidden');
        live.shown();
        async.flushMicrotasks();
        expect(server.conns, hasLength(opened + 1));
        expect(live.mode, LiveMode.connecting);
        live.close();
      });
    });

    test('a stream retry that came due while hidden runs on return', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.refuse(503, body: _fullBody); // retried at 60 s
        async.flushMicrotasks();
        live.hidden();
        async.elapse(const Duration(minutes: 2));
        expect(server.conns, hasLength(1));

        live.shown();
        async.flushMicrotasks();
        expect(server.conns, hasLength(2));
        expect(polls, 1, reason: 'no fetch for coming back');
        live.close();
      });
    });

    test('not live, or no streams: nothing more on coming back', () {
      for (final status in ['published', 'live']) {
        fakeAsync((async) {
          server = _Server();
          polls = 0;
          pollStatus = status;
          final live = client()..start();
          async.flushMicrotasks();
          if (status == 'live') server.last.refuse(404);
          async.flushMicrotasks();
          final opened = server.conns.length;
          live.hidden();
          async.elapse(const Duration(minutes: 1));
          live.shown();
          async.flushMicrotasks();
          expect(server.conns, hasLength(opened), reason: status);
          expect(polls, 1, reason: status);
          live.close();
        });
      }
    });

    test('hidden before it loaded: the fetch as ever; the stream when back',
        () {
      fakeAsync((async) {
        final live = client();
        live.hidden();
        async.elapse(const Duration(seconds: 30));
        live.start();
        async.flushMicrotasks();
        expect(polls, 1);
        expect(server.conns, isEmpty);
        live.shown();
        async.flushMicrotasks();
        expect(server.conns, hasLength(1));
        live.close();
      });
    });
  });

  group('never two of anything', () {
    test('start twice, and a reload while streaming: one stream, no fetch', () {
      fakeAsync((async) {
        final live = client()
          ..start()
          ..start();
        async.flushMicrotasks();
        expect(polls, 1);
        server.last
          ..accept()
          ..ping();
        async.flushMicrotasks();
        live
          ..refresh()
          ..refresh();
        async.flushMicrotasks();
        expect(server.conns, hasLength(1));
        expect(polls, 1);
        live.close();
      });
    });

    test('a reload with no stream fetches once, as the page always did', () {
      fakeAsync((async) {
        final live = client()..refresh(); // the first one starts it
        async.flushMicrotasks();
        server.last.refuse(404);
        async.flushMicrotasks();
        expect(polls, 1);
        live.refresh();
        async.flushMicrotasks();
        expect(polls, 2);
        expect(server.conns, hasLength(1), reason: 'off: not asked again');
        live.close();
      });
    });

    test('one fetch in flight at a time', () {
      fakeAsync((async) {
        pollStatus = 'published';
        final live = client()..start();
        async.flushMicrotasks();
        pollGate = Completer<void>();
        live
          ..refresh()
          ..refresh();
        async.flushMicrotasks();
        expect(polls, 2);
        pollGate!.complete();
        live.close();
      });
    });

    test('close stops the stream and every clock', () {
      fakeAsync((async) {
        final live = started(async);
        server.last.refuse(503, body: _fullBody);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 61)); // retrying
        live.hidden();
        live.close();
        async.flushMicrotasks();
        expect(server.live, 0);
        expect(async.pendingTimers, isEmpty);
        final before = polls;
        async.elapse(const Duration(hours: 1));
        expect(polls, before);
        expect(live.mode, LiveMode.closed);
      });
    });

    test('an answer to an open already given up on is closed, not used', () {
      fakeAsync((async) {
        server.ignoreAborts = true;
        final live = started(async);
        final first = server.last;
        async.elapse(LiveStreamClient.openDeadline); // given up on
        async.elapse(LiveStreamClient.defaultRetry);
        expect(server.conns, hasLength(2));

        first
          ..accept()
          ..snapshot('Late', id: '1');
        async.flushMicrotasks();
        expect(first.responseClosed, isTrue);
        expect(shown, ['From the poll']);
        expect(live.mode, LiveMode.connecting);
        live.close();
      });
    });

    test('through drops, failures, refusals and the background: never two', () {
      fakeAsync((async) {
        final live = client()..start();
        void check() {
          async.flushMicrotasks();
          expect(server.live, lessThanOrEqualTo(1));
        }

        check();
        server.last
          ..accept()
          ..snapshot('A', id: '1');
        check();
        server.last.end();
        async.elapse(const Duration(seconds: 3));
        check();
        server.last.fail();
        check();
        live.hidden();
        async.elapse(const Duration(seconds: 2));
        check();
        live.shown();
        check();
        async.elapse(const Duration(seconds: 3));
        check();
        server.last.refuse(503, body: _fullBody);
        check();
        live.refresh();
        async.elapse(const Duration(seconds: 60));
        check();
        server.last
          ..accept()
          ..ping();
        check();
        expect(live.mode, LiveMode.streaming);
        live.close();
        check();
        expect(server.live, 0);
      });
    });
  });
}
