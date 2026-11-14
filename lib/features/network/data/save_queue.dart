import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/network/domain/network.dart';

/// A save made with no signal: who (by code or handle), how, at which
/// event, and when -- sent as `met_at` once the phone is back online, so
/// the meeting keeps its own time (the server takes up to 72 hours).
class PendingSave {
  const PendingSave({
    required this.clientRef,
    this.code,
    this.handle,
    required this.method,
    this.eventId,
    required this.metAt,
    this.ownerId,
  });

  /// This phone's own name for it: saving one twice keeps one.
  final String clientRef;
  final String? code;
  final String? handle;
  final MetHow method;
  final int? eventId;
  final DateTime metAt;

  /// The account that made it: sent only while that account is signed in.
  final int? ownerId;

  /// The same person, however they were asked for.
  String get who => code != null ? 'code:$code' : 'handle:$handle';

  Map<String, dynamic> toJson() => {
        'client_ref': clientRef,
        if (code != null) 'code': code,
        if (handle != null) 'handle': handle,
        'method': method.name,
        if (eventId != null) 'event_id': eventId,
        'met_at': metAt.toUtc().toIso8601String(),
        if (ownerId != null) 'owner_id': ownerId,
      };

  static PendingSave? fromJson(Object? value) {
    final json = jsonObject(value);
    final ref = jsonString(json?['client_ref']);
    final code = jsonString(json?['code']);
    final handle = jsonString(json?['handle']);
    final method = metHowFrom(json?['method']);
    final metAt = jsonDate(json?['met_at']);
    if (ref == null ||
        (code == null && handle == null) ||
        method == null ||
        metAt == null) {
      return null;
    }
    return PendingSave(
      clientRef: ref,
      code: code,
      handle: handle,
      method: method,
      eventId: jsonInt(json?['event_id']),
      metAt: metAt,
      ownerId: jsonInt(json?['owner_id']),
    );
  }
}

/// What became of a save made with no signal, once there was one, when
/// the person should hear of it: refused by the server, or saved without
/// its event because more than [NetworkSaverLimits.maxAge] had passed.
enum SaveNoticeKind { refused, late }

class SaveNotice {
  const SaveNotice({
    required this.kind,
    required this.save,
    required this.message,
    required this.at,
  });

  final SaveNoticeKind kind;
  final PendingSave save;

  /// Why, in words for the person.
  final String message;

  /// When the server answered.
  final DateTime at;

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'save': save.toJson(),
        'message': message,
        'at': at.toUtc().toIso8601String(),
      };

  static SaveNotice? fromJson(Object? value) {
    final json = jsonObject(value);
    final save = PendingSave.fromJson(json?['save']);
    final message = jsonString(json?['message']);
    final at = jsonDate(json?['at']);
    final kind = SaveNoticeKind.values
        .where((k) => k.name == jsonString(json?['kind']))
        .firstOrNull;
    if (save == null || message == null || at == null || kind == null) {
      return null;
    }
    return SaveNotice(kind: kind, save: save, message: message, at: at);
  }
}

/// The saves waiting for a signal, kept across restarts until the server
/// has answered each, and the notices of what became of them. Cleared at
/// sign-out with the rest of the person's data (session_services.dart):
/// they were theirs.
abstract class PendingSaveStore {
  /// Oldest first.
  Future<List<PendingSave>> all();

  /// Saving the same person again replaces the earlier one.
  Future<void> add(PendingSave save);

  Future<void> remove(Iterable<String> clientRefs);

  /// Newest first; at most [maxNotices].
  Future<List<SaveNotice>> notices();
  Future<void> addNotice(SaveNotice notice);
  Future<void> clearNotices();

  /// The saves and the notices.
  Future<void> clear();

  static const maxNotices = 20;
}

class MemoryPendingSaveStore implements PendingSaveStore {
  final List<PendingSave> saved = [];
  final List<SaveNotice> told = [];

  @override
  Future<List<PendingSave>> all() async => List.of(saved);

  @override
  Future<void> add(PendingSave save) async {
    saved
        .removeWhere((s) => s.who == save.who || s.clientRef == save.clientRef);
    saved.add(save);
  }

  @override
  Future<void> remove(Iterable<String> clientRefs) async {
    final gone = clientRefs.toSet();
    saved.removeWhere((s) => gone.contains(s.clientRef));
  }

  @override
  Future<List<SaveNotice>> notices() async => List.of(told);

  @override
  Future<void> addNotice(SaveNotice notice) async {
    told.insert(0, notice);
    if (told.length > PendingSaveStore.maxNotices) {
      told.removeRange(PendingSaveStore.maxNotices, told.length);
    }
  }

  @override
  Future<void> clearNotices() async => told.clear();

  @override
  Future<void> clear() async {
    saved.clear();
    told.clear();
  }
}

/// One JSON file in the app's support directory (not its cache, which the
/// system may empty), written whole or not at all:
/// `{"pending": [...], "notices": [...]}`.
class FilePendingSaveStore implements PendingSaveStore {
  FilePendingSaveStore({Future<File> Function()? file})
      : _fileOf = file ?? _defaultFile;

  final Future<File> Function() _fileOf;

  static Future<File> _defaultFile() async => File(
      '${(await getApplicationSupportDirectory()).path}/network_saves.json');

  Future<void> _last = Future.value();

  Future<T> _serial<T>(Future<T> Function() task) {
    final run = _last.then((_) => task());
    _last = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<({List<PendingSave> pending, List<SaveNotice> notices})>
      _read() async {
    final file = await _fileOf();
    if (!await file.exists()) {
      return (pending: <PendingSave>[], notices: <SaveNotice>[]);
    }
    try {
      final data = jsonDecode(await file.readAsString());
      final json = jsonObject(data);
      final pending = data is List ? data : json?['pending'];
      return (
        pending: [
          for (final item in pending is List ? pending : const [])
            if (PendingSave.fromJson(item) case final save?) save,
        ],
        notices: [
          for (final item
              in json?['notices'] is List ? json!['notices'] as List : const [])
            if (SaveNotice.fromJson(item) case final notice?) notice,
        ],
      );
    } catch (e) {
      debugPrint('FilePendingSaveStore: unreadable: $e');
      return (pending: <PendingSave>[], notices: <SaveNotice>[]);
    }
  }

  Future<void> _write(
      List<PendingSave> pending, List<SaveNotice> notices) async {
    final file = await _fileOf();
    if (pending.isEmpty && notices.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
        jsonEncode({
          'pending': [for (final s in pending) s.toJson()],
          'notices': [for (final n in notices) n.toJson()],
        }),
        flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<List<PendingSave>> all() =>
      _serial(() async => (await _read()).pending);

  @override
  Future<void> add(PendingSave save) => _serial(() async {
        final now = await _read();
        final saves = now.pending
          ..removeWhere(
              (s) => s.who == save.who || s.clientRef == save.clientRef)
          ..add(save);
        await _write(saves, now.notices);
      });

  @override
  Future<void> remove(Iterable<String> clientRefs) => _serial(() async {
        final gone = clientRefs.toSet();
        final now = await _read();
        await _write(
            now.pending..removeWhere((s) => gone.contains(s.clientRef)),
            now.notices);
      });

  @override
  Future<List<SaveNotice>> notices() =>
      _serial(() async => (await _read()).notices);

  @override
  Future<void> addNotice(SaveNotice notice) => _serial(() async {
        final now = await _read();
        final notices = [notice, ...now.notices];
        await _write(
            now.pending,
            notices.length > PendingSaveStore.maxNotices
                ? notices.sublist(0, PendingSaveStore.maxNotices)
                : notices);
      });

  @override
  Future<void> clearNotices() => _serial(() async {
        final now = await _read();
        await _write(now.pending, const []);
      });

  @override
  Future<void> clear() => _serial(() => _write(const [], const []));
}

final pendingSaveStoreProvider =
    Provider<PendingSaveStore>((ref) => FilePendingSaveStore());
