import 'dart:convert';
import 'dart:io';

import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/data/scan_queue.dart';
import 'package:flutter_test/flutter_test.dart';

/// The door's saved scans are admissions that already happened: kept per
/// account and event, never emptied by a session ending, and never seen by
/// another account on the same phone.
void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('gateq'));
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  FileScanQueueStore store(int? owner) =>
      FileScanQueueStore(root: () async => dir, ownerId: owner);

  QueuedScan scan(int event, String ref) => QueuedScan(
      eventId: event,
      code: 'MOA-$ref',
      clientRef: ref,
      scannedAt: DateTime.utc(2026, 11, 28, 9),
      door: 'Gate');

  test('each account has its own: another one signed in sees none of them',
      () async {
    await store(41).add(scan(7, 'mine-1'));
    await store(41).add(scan(8, 'mine-2'));
    await store(52).add(scan(7, 'theirs'));

    expect((await store(41).all(7)).map((s) => s.clientRef), ['mine-1']);
    expect((await store(52).all(7)).map((s) => s.clientRef), ['theirs']);
    expect(await store(41).events(), [7, 8]);
    expect(await store(52).events(), [7]);
    expect(await store(41).count(), 2);
    expect(await store(52).count(), 1);
    // Nobody signed in: nothing of anyone's.
    expect(await store(null).count(), 0);
  });

  test("an account's scans are still there after it signed out and back in",
      () async {
    await store(41).add(scan(7, 'a'));
    // Signed out; someone else used the phone; the first one is back.
    await store(52).add(scan(7, 'b'));
    await store(52).remove(7, ['b']);

    expect((await store(41).all(7)).single.clientRef, 'a');
  });

  test('scans an older build left are taken by the account signed in',
      () async {
    // 1.2.1's file: one an event, no account in its name.
    final old = File('${dir.path}/event_7.json');
    await old.writeAsString(jsonEncode([scan(7, 'old').toJson()]));
    await store(41).add(scan(7, 'new'));

    final mine = store(41);
    expect((await mine.all(7)).map((s) => s.clientRef),
        containsAll(['old', 'new']));
    expect(await old.exists(), isFalse);
    expect(await store(52).count(), 0);
  });

  test('a scan asked for again is saved with its wait, across a restart',
      () async {
    final now = DateTime.utc(2026, 11, 28, 9, 30);
    await store(41).add(scan(7, 'a'));
    await store(41).add(scan(7, 'b'));

    final asked = (await store(41).all(7)).first.askedAgainAt(now);
    await store(41).update(7, [asked]);

    final again = await store(41).all(7);
    expect(again.map((s) => s.clientRef), ['a', 'b']);
    expect(again.first.attempts, 1);
    expect(again.first.retryAt!.toUtc(), now.add(const Duration(seconds: 15)));
    expect(again.first.isDue(now), isFalse);
    expect(again.last.isDue(now), isTrue);
    // Updating one no longer saved brings nothing back.
    await store(41).remove(7, ['a', 'b']);
    await store(41).update(7, [asked]);
    expect(await store(41).all(7), isEmpty);
  });

  test('the wait between asks doubles from 15 s, up to 5 minutes', () {
    final now = DateTime.utc(2026, 11, 28, 9);
    var s = scan(7, 'a');
    final waits = <int>[];
    for (var i = 0; i < 7; i++) {
      s = s.askedAgainAt(now);
      waits.add(s.retryAt!.difference(now).inSeconds);
    }
    expect(waits, [15, 30, 60, 120, 240, 300, 300]);
    expect(s.attempts, 7);
    // Not sent with the scan: the server never sees the bookkeeping.
    expect(s.toBody().keys, isNot(contains('attempts')));
  });
}
