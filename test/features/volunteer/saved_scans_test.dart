import 'package:dio/dio.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/data/saved_scans.dart';
import 'package:finnet/features/volunteer/data/scan_queue.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart' show RouteAdapter;
import 'volunteer_fakes.dart';

QueuedScan _scan(int event, String ref) => QueuedScan(
    eventId: event,
    code: 'MOA-$ref',
    clientRef: ref,
    scannedAt: DateTime.utc(2026, 11, 28, 9));

void main() {
  group('the batch answer, as the server sends it', () {
    late RouteAdapter server;
    late GateApi api;

    setUp(() {
      server = RouteAdapter();
      api = GateApi(Dio()..httpClientAdapter = server);
    });

    Map<String, dynamic> row(String ref, Map<String, dynamic> response,
            {bool? retry}) =>
        {
          'client_ref': ref,
          'response': response,
          if (retry != null) 'retry': retry,
        };

    test('INVALID with retry: true is asked again, not "not found"; a plain '
        'INVALID is a final refusal', () async {
      server.on('POST', '/events/7/gate/scan-batch', {
        'results': [
          row('aaaaaaaa', {
            'outcome': 'INVALID',
            'attendee': null,
            'error': 'This scan could not be recorded just now.',
            'retry': true,
          }),
          row('bbbbbbbb', {'outcome': 'INVALID', 'attendee': null}),
          row('cccccccc', {'outcome': 'CHECKED_IN'}),
        ],
      });

      final answers = await api.scanBatch(
          7, [_scan(7, 'aaaaaaaa'), _scan(7, 'bbbbbbbb'), _scan(7, 'cccccccc')]);

      expect([for (final a in answers) a.isFinal], [false, true, true]);
      expect(answers.first.result.retry, isTrue);
    });

    test('retry beside the answer counts too', () async {
      server.on('POST', '/events/7/gate/scan-batch', {
        'results': [
          row('aaaaaaaa', {'outcome': 'INVALID'}, retry: true),
        ],
      });

      final answers = await api.scanBatch(7, [_scan(7, 'aaaaaaaa')]);

      expect(answers.single.isFinal, isFalse);
    });

    test("an answer this build can't read stays to be sent again; one for a "
        "scan that wasn't sent is left out", () async {
      server.on('POST', '/events/7/gate/scan-batch', {
        'results': [
          row('aaaaaaaa', {'outcome': 'SOMETHING_NEW'}),
          {'client_ref': 'bbbbbbbb'},
          row('zzzzzzzz', {'outcome': 'CHECKED_IN'}),
        ],
      });

      final answers =
          await api.scanBatch(7, [_scan(7, 'aaaaaaaa'), _scan(7, 'bbbbbbbb')]);

      expect(answers.map((a) => a.clientRef), ['aaaaaaaa', 'bbbbbbbb']);
      expect(answers.every((a) => !a.isFinal), isTrue);
    });

    test('a server from before (no retry anywhere): every answer is final',
        () async {
      server.on('POST', '/events/7/gate/scan-batch', {
        'results': [
          row('aaaaaaaa', {'outcome': 'INVALID'}),
          row('bbbbbbbb', {'outcome': 'ALREADY_CHECKED_IN'}),
        ],
      });

      final answers =
          await api.scanBatch(7, [_scan(7, 'aaaaaaaa'), _scan(7, 'bbbbbbbb')]);

      expect(answers.every((a) => a.isFinal), isTrue);
    });
  });

  group('SavedScanSender', () {
    late FakeGateApi api;
    late MemoryScanQueueStore queue;

    setUp(() {
      api = FakeGateApi();
      queue = MemoryScanQueueStore();
    });

    SavedScanSender sender({bool active = true}) =>
        SavedScanSender(api: () => api, queue: queue, active: active);

    test('sends every event\'s saved scans, and they leave the phone',
        () async {
      await queue.add(_scan(7, 'aaaaaaaa'));
      await queue.add(_scan(8, 'bbbbbbbb'));

      final result = await sender().sendAll();

      expect(api.batches, hasLength(2));
      expect(result.answered, 2);
      expect(result.left, 0);
      expect(await queue.count(), 0);
    });

    test('no signal: stops at once, and keeps everything', () async {
      await queue.add(_scan(7, 'aaaaaaaa'));
      await queue.add(_scan(8, 'bbbbbbbb'));
      api.batchError = noSignal('/scan-batch');

      final result = await sender().sendAll();

      expect(api.batches, hasLength(1));
      expect(result.left, 2);
      expect(result.error, isNotNull);
    });

    test('a batch the server refuses outright stays saved', () async {
      await queue.add(_scan(7, 'aaaaaaaa'));
      api.batchError = refused('/scan-batch', 403, 'Not on the team.');

      final result = await sender().sendAll();

      expect(result.left, 1);
    });

    test('nobody signed in: nothing is sent', () async {
      await queue.add(_scan(7, 'aaaaaaaa'));

      final result = await sender(active: false).sendAll();

      expect(api.batches, isEmpty);
      expect(await queue.count(), 1);
      expect(result.left, 0, reason: 'nothing counted as theirs to send');
    });

    test('closed with its session: sends nothing more', () async {
      await queue.add(_scan(7, 'aaaaaaaa'));
      final s = sender()..close();

      await s.sendAll();

      expect(api.batches, isEmpty);
      expect(await queue.count(), 1);
    });

    test('an unreadable queue counts as nothing, and never throws', () async {
      final s = SavedScanSender(api: () => api, queue: _Broken());

      expect(await s.count(), 0);
      expect((await s.sendAll()).answered, 0);
    });
  });
}

class _Broken implements ScanQueueStore {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future<Never>.error(StateError('disk'));
}
