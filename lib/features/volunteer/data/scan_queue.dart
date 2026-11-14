import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:finnet/core/auth/jwt_claims.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';

/// The scans taken at the door while the phone had no signal, kept until
/// the server has answered each -- as the club dashboard's console keeps
/// them in IndexedDB (moa_web `gate/lib/queue.ts`). Each carries its own
/// client ref, so sending one twice admits nobody twice.
///
/// Kept on the phone across restarts, sign-outs and sessions the server
/// ended: each scan is an admission that has already happened, so it is
/// never thrown away unsent. The scans are the account's that took them --
/// a store is one account's ([FileScanQueueStore.ownerId]) -- so another
/// person signing in on the phone never sees or sends them, and they go
/// when their own account is back (saved_scans.dart).
abstract class ScanQueueStore {
  /// The event's saved scans, oldest first.
  Future<List<QueuedScan>> all(int eventId);

  Future<void> add(QueuedScan scan);

  /// The scans the server has answered, by client ref.
  Future<void> remove(int eventId, Iterable<String> clientRefs);

  /// Saves [scans] again as they now are (their asks counted, say), in
  /// one go. Only scans still saved are written.
  Future<void> update(int eventId, Iterable<QueuedScan> scans);

  /// The events with saved scans.
  Future<List<int>> events();

  /// Every saved scan, across events.
  Future<int> count();
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
    if (saved[eventId]?.isEmpty ?? false) saved.remove(eventId);
  }

  @override
  Future<void> update(int eventId, Iterable<QueuedScan> scans) async {
    final now = {for (final s in scans) s.clientRef: s};
    final list = saved[eventId];
    if (list == null) return;
    for (var i = 0; i < list.length; i++) {
      list[i] = now[list[i].clientRef] ?? list[i];
    }
  }

  @override
  Future<List<int>> events() async => [
        for (final e in saved.entries)
          if (e.value.isNotEmpty) e.key,
      ];

  @override
  Future<int> count() async =>
      saved.values.fold<int>(0, (n, list) => n + list.length);
}

/// One JSON file an event and account (`event_{id}_u{user}.json`), in the
/// app's support directory (not its cache, which the system may empty),
/// written whole or not at all.
///
/// Builds before 1.3.0 kept one file an event (`event_{id}.json`) and
/// emptied the directory at every sign-in and sign-out, so a file of that
/// shape on the phone is the account signed in when the app was updated:
/// the first store with an account takes it as its own.
class FileScanQueueStore implements ScanQueueStore {
  FileScanQueueStore({Future<Directory> Function()? root, this.ownerId})
      : _root = root ?? _defaultRoot;

  final Future<Directory> Function() _root;

  /// The account whose scans these are: the signed-in one. Null when it
  /// can't be told (no session, or a token without a `user_id`): then
  /// only the unowned files.
  final int? ownerId;

  static Future<Directory> _defaultRoot() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/gate_queue');

  /// One write at a time, across every store of the run: a scan saved
  /// while the last batch is removed must not be lost between a read and
  /// a write, and a session's store and the next one's share the files.
  static Future<void> _last = Future.value();

  Future<T> _serial<T>(Future<T> Function() task) {
    final run = _last.then((_) => task());
    _last = run.then((_) {}, onError: (_) {});
    return run;
  }

  bool _adopted = false;

  String get _suffix => ownerId == null ? '' : '_u$ownerId';

  static final _fileName = RegExp(r'^event_(\d+)(?:_u(\d+))?\.json$');

  Future<Directory> _dir() async {
    final dir = await _root();
    if (!await dir.exists()) await dir.create(recursive: true);
    if (!_adopted) {
      _adopted = true;
      await _adoptUnowned(dir);
    }
    return dir;
  }

  /// The files an older build left, taken as [ownerId]'s.
  Future<void> _adoptUnowned(Directory dir) async {
    if (ownerId == null) return;
    try {
      await for (final entry in dir.list()) {
        final match = _fileName.firstMatch(entry.uri.pathSegments.last);
        if (entry is! File || match == null || match.group(2) != null) {
          continue;
        }
        final eventId = int.parse(match.group(1)!);
        final old = await _readFile(entry);
        final mine = File('${dir.path}/event_$eventId$_suffix.json');
        final kept = await _readFile(mine);
        final known = {for (final s in kept) s.clientRef};
        await _writeFile(
            mine, [...kept, ...old.where((s) => !known.contains(s.clientRef))]);
        await entry.delete();
      }
    } catch (e) {
      debugPrint('FileScanQueueStore: could not take over older scans: $e');
    }
  }

  Future<File> _file(int eventId) async {
    final dir = await _dir();
    return File('${dir.path}/event_$eventId$_suffix.json');
  }

  Future<List<QueuedScan>> _readFile(File file) async {
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString());
      return (data is List ? data : const [])
          .map(QueuedScan.fromJson)
          .whereType<QueuedScan>()
          .toList();
    } catch (e) {
      debugPrint('FileScanQueueStore: unreadable queue ${file.path}: $e');
      return [];
    }
  }

  Future<void> _writeFile(File file, List<QueuedScan> scans) async {
    if (scans.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode([for (final s in scans) s.toJson()]),
        flush: true);
    await temp.rename(file.path);
  }

  Future<List<QueuedScan>> _read(int eventId) async =>
      _readFile(await _file(eventId));

  Future<void> _write(int eventId, List<QueuedScan> scans) async =>
      _writeFile(await _file(eventId), scans);

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
        if (gone.isEmpty) return;
        final scans = await _read(eventId)
          ..removeWhere((s) => gone.contains(s.clientRef));
        await _write(eventId, scans);
      });

  @override
  Future<void> update(int eventId, Iterable<QueuedScan> scans) =>
      _serial(() async {
        final now = {for (final s in scans) s.clientRef: s};
        if (now.isEmpty) return;
        final saved = await _read(eventId);
        await _write(eventId, [
          for (final s in saved) now[s.clientRef] ?? s,
        ]);
      });

  @override
  Future<List<int>> events() => _serial(() async {
        final dir = await _dir();
        final found = <int>{};
        await for (final entry in dir.list()) {
          final match = _fileName.firstMatch(entry.uri.pathSegments.last);
          if (entry is! File || match == null) continue;
          if (match.group(2) != ownerId?.toString()) continue;
          found.add(int.parse(match.group(1)!));
        }
        return found.toList()..sort();
      });

  @override
  Future<int> count() async {
    var n = 0;
    for (final eventId in await events()) {
      n += (await all(eventId)).length;
    }
    return n;
  }
}

/// The signed-in account's queue; tests put a [MemoryScanQueueStore] in
/// its place.
final scanQueueStoreProvider = Provider<ScanQueueStore>((ref) =>
    FileScanQueueStore(
        ownerId: ref
            .watch(authStateProvider.select((s) => userIdOf(s.accessToken)))));
