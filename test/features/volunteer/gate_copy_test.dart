import 'dart:io';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/data/scan_queue.dart';
import 'package:finnet/features/volunteer/domain/gate_copy.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';
import 'volunteer_fakes.dart';

void main() {
  group('what each answer at the door says', () {
    final now = DateTime.utc(2026, 10, 25, 10);

    test('let in', () {
      final c = outcomeCard(scanned(ScanOutcome.checkedIn, who: guest()),
          door: 'Main gate');
      expect(c.tone, GateTone.admit);
      expect(c.tag, 'Welcome in');
      expect(c.sub, 'MOA-4KD9W-22XQZ · ATTENDEE · MAIN GATE');
    });

    test('already in: who let them in, where and when', () {
      final c = outcomeCard(
          scanned(ScanOutcome.alreadyCheckedIn,
              who: guest(),
              byName: 'Rahul',
              byDoor: 'Side door',
              at: now.subtract(const Duration(minutes: 12))),
          now: now);
      expect(c.tone, GateTone.caution);
      expect(c.attribution, 'Rahul at Side door, 12 minutes ago.');
    });

    test('a ticket for another event names it', () {
      final c = outcomeCard(
          scanned(ScanOutcome.wrongEvent, otherEvent: 'Robotics Day'));
      expect(c.tone, GateTone.refuse);
      expect(c.sub, 'VALID TICKET · ROBOTICS DAY');
    });

    test('revoked, unpaid, door shut, not recognised', () {
      expect(outcomeCard(scanned(ScanOutcome.revoked, who: guest())).tag,
          'Revoked');
      expect(outcomeCard(scanned(ScanOutcome.unpaid, who: guest())).title,
          'Aarav Menon has not paid for this ticket.');
      expect(outcomeCard(scanned(ScanOutcome.eventNotOpen)).tag, 'Door shut');
      expect(outcomeCard(scanned(ScanOutcome.invalid)).tag, 'Not recognised');
    });

    test('an admission number asks to check its holder in by hand', () {
      final r = scanned(ScanOutcome.invalid,
          who: guest(admissionNo: 'MOA-0042-E7'), hint: admissionNumberHint);
      expect(r.needsHandCheckIn, isTrue);
      final c = outcomeCard(r);
      expect(c.tag, 'Admission number');
      expect(c.title,
          'Aarav Menon, admission no. MOA-0042-E7: check in by hand?');
    });

    test('a saved scan is never "welcome in"', () {
      expect(queuedCard.tone, GateTone.queued);
      expect(queuedCard.title.toLowerCase(), isNot(contains('welcome')));
    });
  });

  group('the saved scans, as the server answered them', () {
    QueuedScan saved(String code, String ref) => QueuedScan(
        eventId: 7,
        code: code,
        clientRef: ref,
        scannedAt: DateTime.utc(2026, 10, 25, 9, 5),
        door: 'Main gate');

    test('admissions are only counted; each refusal is named, with why', () {
      final report = withReplayed(null, [
        ReplayedScan(
            clientRef: 'a',
            result: scanned(ScanOutcome.checkedIn, who: guest()),
            scan: saved('MOA-AAAAA-AAAAA', 'a')),
        ReplayedScan(
            clientRef: 'b',
            result: scanned(ScanOutcome.checkedIn, replayed: true),
            scan: saved('MOA-BBBBB-BBBBB', 'b')),
        ReplayedScan(
            clientRef: 'c',
            result: scanned(ScanOutcome.revoked,
                who: guest(name: 'Diya Nair', ticket: 'MOA-CCCCC-CCCCC')),
            scan: saved('MOA-CCCCC-CCCCC', 'c')),
        ReplayedScan(
            clientRef: 'd',
            result: scanned(ScanOutcome.invalid),
            scan: saved('MOA-DDDDD', 'd')),
      ]);

      expect(report.synced, 4);
      expect(report.admitted, 2);
      expect(report.problems.map((p) => (p.name, p.ticket, p.tag)), [
        ('Diya Nair', 'MOA-CCCCC-CCCCC', 'Revoked'),
        (null, 'MOA-DDDDD', 'Not found'),
      ]);
      expect(report.problems.first.door, 'Main gate');
      expect(report.problems.first.reason, contains('cancelled or refunded'));
    });

    test('every refusal has its reason', () {
      for (final (outcome, tag) in [
        (ScanOutcome.alreadyCheckedIn, 'Already used'),
        (ScanOutcome.wrongEvent, 'Wrong event'),
        (ScanOutcome.unpaid, 'Not paid'),
        (ScanOutcome.eventNotOpen, 'Door shut'),
      ]) {
        final p = replayProblem(
            ReplayedScan(clientRef: 'x', result: scanned(outcome)))!;
        expect(p.tag, tag);
        expect(p.reason, isNotEmpty);
      }
    });

    test('a scan answered twice is listed once', () {
      final once = withReplayed(null, [
        ReplayedScan(clientRef: 'c', result: scanned(ScanOutcome.revoked)),
      ]);
      final twice = withReplayed(once, [
        ReplayedScan(clientRef: 'c', result: scanned(ScanOutcome.revoked)),
      ]);
      expect(twice.problems, hasLength(1));
    });
  });

  group('the routes, as the club dashboard console sends them', () {
    test('a scan, a batch and a search', () async {
      final api = useFakeApi()
        ..on('POST', '/events/7/gate/scan', {
          'outcome': 'ALREADY_CHECKED_IN',
          'attendee': {
            'id': 'reg-1',
            'name': 'Aarav Menon',
            'ticket_id': 'MOA-4KD9W-22XQZ',
            'role': 'attendee',
            'checked_in_at': '2026-10-25T09:00:00Z',
          },
          'checked_in_at': '2026-10-25T09:00:00Z',
          'checked_in_by': {'name': 'Rahul', 'door': 'Side door'},
          'replayed': false,
          'capture': {'ask': false},
          'badge': {},
        })
        ..on('POST', '/events/7/gate/scan-batch', {
          'results': [
            {
              'client_ref': 'ref-1-abcdefgh',
              'response': {'outcome': 'UNPAID', 'attendee': null},
            },
          ],
        })
        ..on('GET', '/events/7/gate/search', [
          {
            'id': 'reg-2',
            'name': 'Diya Nair',
            'ticket_id': 'MOA-ZZZZZ-ZZZZZ',
            'admission_no': 'MOA-0042-E7',
            'is_paid': false,
          },
        ]);
      final gate = GateApi(APIService.instance.dio);
      final scan = QueuedScan(
          eventId: 7,
          code: 'MOA-4KD9W-22XQZ',
          clientRef: 'ref-1-abcdefgh',
          scannedAt: DateTime.utc(2026, 10, 25, 9, 30),
          door: 'Main gate');

      final r = await gate.scan(7, scan);
      expect(r.outcome, ScanOutcome.alreadyCheckedIn);
      expect(r.checkedInByName, 'Rahul');
      expect(r.attendee!.checkedIn, isTrue);
      expect(api.sent('POST', '/events/7/gate/scan').single.data, {
        'code': 'MOA-4KD9W-22XQZ',
        'client_ref': 'ref-1-abcdefgh',
        'scanned_at': '2026-10-25T09:30:00.000Z',
        'door': 'Main gate',
      });

      final replayed = await gate.scanBatch(7, [scan]);
      expect(replayed.single.result.outcome, ScanOutcome.unpaid);
      expect(replayed.single.scan, same(scan));
      expect(
          (api.sent('POST', '/events/7/gate/scan-batch').single.data
              as Map)['scans'],
          hasLength(1));

      final found = await gate.search(7, 'diya');
      expect(found.single.admissionNo, 'MOA-0042-E7');
      expect(found.single.isPaid, isFalse);
      expect(api.sent('GET', '/events/7/gate/search').single.queryParameters,
          {'q': 'diya'});
    });

    test('the merch and the shelf\'s orders', () async {
      final api = useFakeApi()
        ..on('GET', '/events/7/gate/merch/reg-1', {
          'attendee': {'id': 'reg-1'},
          'items': [
            {
              'item_id': 'tee',
              'name': 'T-shirt',
              'status': 'NO_VARIANT_VALUE',
              'choices': [
                {'label': 'M', 'remaining': 4},
                {'label': 'L', 'remaining': 0},
              ],
            },
          ],
        })
        ..on('POST', '/events/7/gate/merch/tee/collect',
            {'status': 'COLLECTED', 'collected': true, 'variant_label': 'M'})
        ..on('GET', '/events/7/gate/store/reg-1', [
          {
            'id': 'o-1',
            'registration_id': 'reg-1',
            'guest': 'Aarav',
            'status': 'paid',
            'total': 499,
            'summary': '1 × Hoodie',
            'lines': [
              {'item_name': 'Hoodie', 'variant_label': 'L', 'qty': 1},
            ],
            'paid_at': '2026-10-20T10:00:00Z',
            'handed_over_at': null,
            'created_at': '2026-10-20T10:00:00Z',
          },
        ])
        ..on('POST', '/events/7/gate/store/o-1/handover', {
          'id': 'o-1',
          'status': 'paid',
          'summary': '1 × Hoodie',
          'handed_over_at': '2026-10-25T10:00:00Z',
        });
      final gate = GateApi(APIService.instance.dio);

      final owed = (await gate.merchFor(7, 'reg-1')).items.single;
      expect(owed.needsSize, isTrue);
      expect(owed.choices.map((c) => c.label), ['M', 'L']);
      final r = await gate.collect(7,
          itemId: 'tee', registrationId: 'reg-1', size: 'M', door: 'Gate');
      expect(r.collected, isTrue);
      expect(api.sent('POST', '/events/7/gate/merch/tee/collect').single.data,
          {'registration_id': 'reg-1', 'variant_label': 'M', 'door': 'Gate'});

      final order = (await gate.ordersFor(7, 'reg-1')).single;
      expect(order.toHandOver, isTrue);
      expect(order.lines.single.variant, 'L');
      final done = await gate.handOver(7, 'o-1');
      expect(done!.handedOver, isTrue);
    });

    test('no answer is told apart from a refusal', () {
      expect(gotNoAnswer(noSignal('/x')), isTrue);
      expect(gotNoAnswer(refused('/x', 403, 'no')), isFalse);
      expect(gateErrorMessage(refused('/x', 403, 'Not on the team.'), 'f'),
          'Not on the team.');
    });
  });

  group('the queue on the phone', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('gateq'));
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    QueuedScan scan(int event, String ref) => QueuedScan(
        eventId: event,
        code: 'MOA-$ref',
        clientRef: ref,
        scannedAt: DateTime.utc(2026, 10, 25, 9),
        door: 'Gate');

    test('keeps each event\'s scans across a restart, until answered',
        () async {
      final store = FileScanQueueStore(root: () async => dir);
      await store.add(scan(7, 'a'));
      await store.add(scan(7, 'b'));
      await store.add(scan(8, 'c'));
      // The same scan saved twice is one.
      await store.add(scan(7, 'a'));

      // The app closed and opened again.
      final again = FileScanQueueStore(root: () async => dir);
      expect((await again.all(7)).map((s) => s.clientRef), ['b', 'a']);
      expect((await again.all(8)).single.door, 'Gate');

      await again.remove(7, ['a', 'b']);
      expect(await again.all(7), isEmpty);
      expect(await again.all(8), hasLength(1));

      await again.clear();
      expect(await again.all(8), isEmpty);
    });

    test('scans saved at once are all kept', () async {
      final store = FileScanQueueStore(root: () async => dir);
      await Future.wait([for (var i = 0; i < 20; i++) store.add(scan(7, 'r$i'))]);
      expect(await store.all(7), hasLength(20));
    });
  });
}
