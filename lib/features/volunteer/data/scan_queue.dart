import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';

/// The scans taken at the door while the phone had no signal, kept until
/// the server has answered each -- as the club dashboard's console keeps
/// them in IndexedDB (moa_web `gate/lib/queue.ts`). Each carries its own
/// client ref, so sending one twice admits nobody twice.
///
/// Kept on the phone across restarts: a volunteer whose app is closed in a
/// dead spot still has the scans when it opens again. Cleared at sign-out,
/// with everything else of the person's (session_services.dart): the scans
/// were theirs to send.
abstract class ScanQueueStore {
  /// The event's saved scans, oldest first.
  Future<List<QueuedScan>> all(int eventId);

  Future<void> add(QueuedScan scan);

  /// The scans the server has answered, by client ref.
  Future<void> remove(int eventId, Iterable<String> clientRefs);

  /// Every event's.
  Future<void> clear();
}

/// In memory: for tests, and a fallback.
class MemoryScanQueueStore implements ScanQueueStore {
  final Map<int, List<QueuedScan>> saved = {};

  @override
  Future<List<QueuedScan>> all(int eventId) async =>
      List.of(saved[eventId] ?? const []);

  @override
  Future<void> add(QueuedScan scan) async {
    final list = saved.putIfAbsent(scan.eventId, () => []);
    list.removeWhere((s) => s.clientRef == scan.clientRef);
    list.add(scan);
  }

  @override
  Future<void> remove(int eventId, Iterable<String> clientRefs) async {
    final gone = clientRefs.toSet();
    saved[eventId]?.removeWhere((s) => gone.contains(s.clientRef));
  }

  @override
  Future<void> clear() async => saved.clear();
}

/// One JSON file an event, in the app's support directory (not its cache,
/// which the system may empty), written whole or not at all.
class FileScanQueueStore implements ScanQueueStore {
  FileScanQueueStore({Future<Directory> Function()? root})
      : _root = root ?? _defaultRoot;

  final Future<Directory> Function() _root;

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/gate_queue');

  /// One write at a time: a scan saved while the last batch is removed must
  /// not be lost between a read and a write.
  Future<void> _last = Future.value();

  Future<T> _serial<T>(Future<T> Function() task) {
    final run = _last.then((_) => task());
    _last = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<File> _file(int eventId) async {
    final dir = await _root();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/event_$eventId.json');
  }

  Future<List<QueuedScan>> _read(int eventId) async {
    final file = await _file(eventId);
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString());
      return (data is List ? data : const [])
          .map(QueuedScan.fromJson)
          .whereType<QueuedScan>()
          .toList();
    } catch (e) {
      debugPrint('FileScanQueueStore: unreadable queue for $eventId: $e');
      return [];
    }
  }

  Future<void> _write(int eventId, List<QueuedScan> scans) async {
    final file = await _file(eventId);
    if (scans.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode([for (final s in scans) s.toJson()]),
        flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<List<QueuedScan>> all(int eventId) => _serial(() => _read(eventId));

  @override
  Future<void> add(QueuedScan scan) => _serial(() async {
        final scans = await _read(scan.eventId)
          ..removeWhere((s) => s.clientRef == scan.clientRef)
          ..add(scan);
        await _write(scan.eventId, scans);
      });

  @override
  Future<void> remove(int eventId, Iterable<String> clientRefs) =>
      _serial(() async {
        final gone = clientRefs.toSet();
        final scans = await _read(eventId)
          ..removeWhere((s) => gone.contains(s.clientRef));
        await _write(eventId, scans);
      });

  @override
  Future<void> clear() => _serial(() async {
        final dir = await _root();
        if (await dir.exists()) await dir.delete(recursive: true);
      });
}

/// The app's one queue; tests put a [MemoryScanQueueStore] in its place.
final scanQueueStoreProvider =
    Provider<ScanQueueStore>((ref) => FileScanQueueStore());
