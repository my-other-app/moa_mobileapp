import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/data/scan_queue.dart';
import 'package:finnet/features/volunteer/domain/gate_copy.dart';
import 'package:finnet/features/volunteer/presentation/providers/gate_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'volunteer_fakes.dart';

/// The door on a volunteer's phone: online it checks in at once; with no
/// signal it saves the scan and sends it later through the batch route, and
/// lists by name what the server then refused -- as the club dashboard's
/// door console does.
void main() {
  late FakeGateApi api;
  late MemoryScanQueueStore queue;
  late NetworkStatus network;
  late GateController door;
  var refs = 0;

  GateController make() => GateController(
        eventId: 7,
        api: api,
        queue: queue,
        network: network,
        drainEvery: null,
        now: () => DateTime.utc(2026, 10, 25, 9, 30),
        newRef: () => 'ref-${++refs}-abcdefgh',
      );

  setUp(() {
    api = FakeGateApi(context: gateContext(door: 'Main gate'));
    queue = MemoryScanQueueStore();
    network = NetworkStatus(probe: () async => false);
    refs = 0;
    door = make();
  });

  tearDown(() {
    if (door.mounted) door.dispose();
    network.dispose();
  });

  test('opens on the event, its counts and the volunteer\'s door', () async {
    await door.start();

    expect(door.state.context?.eventName, 'Hack Night 04');
    expect(door.state.context?.doorName, 'Main gate');
    expect(door.state.loading, isFalse);
    expect(door.state.queued, 0);
  });

  group('online', () {
    test('a scan is checked in at once, at the volunteer\'s door', () async {
      await door.start();
      api.scanAnswers.add(scanned(ScanOutcome.checkedIn, who: guest()));

      await door.scan(' MOA-4KD9W-22XQZ ');

      final sent = api.scans.single;
      expect(sent.code, 'MOA-4KD9W-22XQZ');
      expect(sent.door, 'Main gate');
      expect(sent.clientRef, 'ref-1-abcdefgh');
      expect(sent.toBody()['scanned_at'], '2026-10-25T09:30:00.000Z');
      final card = door.state.card!;
      expect(card.card.tone, GateTone.admit);
      expect(card.card.title, 'Aarav Menon — welcome in.');
      expect(card.queued, isFalse);
      expect(door.state.context?.checkedIn, 11);
      expect(await queue.all(7), isEmpty);
    });

    test('a refused ticket says why, and is not saved', () async {
      await door.start();
      api.scanAnswers.add(scanned(ScanOutcome.revoked, who: guest()));

      await door.scan('MOA-4KD9W-22XQZ');

      expect(door.state.card!.card.tag, 'Revoked');
      expect(door.state.context?.checkedIn, 10);
      expect(await queue.all(7), isEmpty);
    });

    test('the server refusing the volunteer is said, not saved', () async {
      await door.start();
      api.scanAnswers.add(refused('/scan', 403, "You are not on this event's team.",
          code: 'NOT_A_VOLUNTEER'));

      await door.scan('MOA-4KD9W-22XQZ');

      expect(door.state.card!.card.tone, GateTone.refuse);
      expect(door.state.card!.card.title, "You are not on this event's team.");
      expect(await queue.all(7), isEmpty);
    });

    test('an empty code is not a scan', () async {
      await door.start();
      await door.scan('   ');
      expect(api.scans, isEmpty);
    });
  });

  group('no signal', () {
    test('the scan is saved on the phone and shown as saved, not admitted',
        () async {
      await door.start();
      api.scanAnswers.add(noSignal('/scan'));

      await door.scan('MOA-4KD9W-22XQZ');

      final card = door.state.card!;
      expect(card.queued, isTrue);
      expect(card.card.tone, GateTone.queued);
      expect(card.card.title, isNot(contains('welcome')));
      expect(door.state.queued, 1);
      final saved = (await queue.all(7)).single;
      expect(saved.code, 'MOA-4KD9W-22XQZ');
      expect(saved.clientRef, 'ref-1-abcdefgh');
      expect(saved.door, 'Main gate');
      // Not counted until the server takes it.
      expect(door.state.context?.checkedIn, 10);
    });

    test('a server down for a moment (502) is kept for later too', () async {
      await door.start();
      api.scanAnswers.add(DioException(
        requestOptions: RequestOptions(path: '/scan'),
        type: DioExceptionType.badResponse,
        response: Response(
            requestOptions: RequestOptions(path: '/scan'), statusCode: 502),
      ));

      await door.scan('MOA-4KD9W-22XQZ');

      expect(door.state.queued, 1);
    });

    test('the console opens without signal: scans are still saved', () async {
      api.context_ = noSignal('/context');
      api.scanAnswers.add(noSignal('/scan'));
      await door.start();

      expect(door.state.context, isNull);
      expect(door.state.contextError, contains('No signal'));
      await door.scan('MOA-4KD9W-22XQZ');
      expect(door.state.queued, 1);
    });
  });

  group('back online', () {
    Future<void> saveTwo() async {
      await door.start();
      api.scanAnswers.add(noSignal('/scan'));
      await door.scan('MOA-AAAAA-AAAAA');
      await door.scan('MOA-BBBBB-BBBBB');
      expect(door.state.queued, 2);
    }

    test('the saved scans go through the batch route and leave the phone',
        () async {
      await saveTwo();

      await door.drain();

      expect(api.batches.single.map((s) => s.code),
          ['MOA-AAAAA-AAAAA', 'MOA-BBBBB-BBBBB']);
      expect(await queue.all(7), isEmpty);
      expect(door.state.queued, 0);
      final report = door.state.report!;
      expect(report.synced, 2);
      expect(report.admitted, 2);
      expect(report.problems, isEmpty);
    });

    test('the ones the server refused are listed by name, with why',
        () async {
      await saveTwo();
      api.batchAnswer = (s) => s.code == 'MOA-BBBBB-BBBBB'
          ? scanned(ScanOutcome.alreadyCheckedIn,
              who: guest(name: 'Diya Nair', ticket: 'MOA-BBBBB-BBBBB'),
              byName: 'Rahul',
              byDoor: 'Side door')
          : scanned(ScanOutcome.checkedIn, who: guest());

      await door.drain();

      final report = door.state.report!;
      expect(report.admitted, 1);
      final problem = report.problems.single;
      expect(problem.name, 'Diya Nair');
      expect(problem.ticket, 'MOA-BBBBB-BBBBB');
      expect(problem.tag, 'Already used');
      expect(problem.reason, contains('by Rahul at Side door'));
      expect(problem.door, 'Main gate');

      door.dismissReport();
      expect(door.state.report, isNull);
    });

    test('coming back online sends them by itself', () async {
      await saveTwo();
      network.reportOffline();

      network.reportOnline();
      await pumpEventQueue();

      expect(api.batches, hasLength(1));
      expect(door.state.queued, 0);
    });

    test('still no signal: they stay saved, quietly', () async {
      await saveTwo();
      api.batchError = noSignal('/scan-batch');

      await door.drain();

      expect(door.state.queued, 2);
      expect(door.state.syncError, isNull);
      expect(door.state.report, isNull);
    });

    test('a batch the server refuses outright stays saved, and says why',
        () async {
      await saveTwo();
      api.batchError = refused('/scan-batch', 403,
          'You may not check guests in at this door.');

      await door.drain();

      expect(door.state.queued, 2);
      expect(door.state.syncError, 'You may not check guests in at this door.');
    });

    test('a scan that gets through sends the saved ones after it', () async {
      await saveTwo();
      api.scanAnswers
        ..clear()
        ..add(scanned(ScanOutcome.checkedIn, who: guest()));

      await door.scan('MOA-CCCCC-CCCCC');
      await pumpEventQueue();

      expect(api.batches, hasLength(1));
      expect(door.state.queued, 0);
    });

    test('a long queue goes 200 at a time', () async {
      await door.start();
      for (var i = 0; i < 250; i++) {
        await queue.add(QueuedScan(
            eventId: 7,
            code: 'MOA-$i',
            clientRef: 'r-$i-xxxxxxxx',
            scannedAt: DateTime.utc(2026)));
      }

      await door.drain();

      expect(api.batches.map((b) => b.length), [200, 50]);
      expect(door.state.report!.synced, 250);
    });
  });

  group('by hand', () {
    test('a guest found by name is checked in at the volunteer\'s door',
        () async {
      await door.start();

      final r = await door.checkInByHand(guest(id: 'reg-9'));

      expect(api.byHand.single, ('reg-9', 'Main gate'));
      expect(r!.admitted, isTrue);
      expect(door.state.card!.card.tone, GateTone.admit);
      expect(door.state.context?.checkedIn, 11);
    });

    test('with no signal it says so (a person must see it go through)',
        () async {
      await door.start();
      api.handAnswer = noSignal('/check-in');

      final r = await door.checkInByHand(guest());

      expect(r, isNull);
      expect(door.state.card!.card.tone, GateTone.refuse);
      expect(door.state.card!.card.title, contains('No signal'));
      expect(door.state.queued, 0);
    });
  });
}
