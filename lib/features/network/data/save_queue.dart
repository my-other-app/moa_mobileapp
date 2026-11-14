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
  });

  /// This phone's own name for it: saving one twice keeps one.
  final String clientRef;
  final String? code;
  final String? handle;
  final MetHow method;
  final int? eventId;
  final DateTime metAt;

  /// The same person, however they were asked for.
  String get who => code != null ? 'code:$code' : 'handle:$handle';

  Map<String, dynamic> toJson() => {
        'client_ref': clientRef,
        if (code != null) 'code': code,
        if (handle != null) 'handle': handle,
        'method': method.name,
        if (eventId != null) 'event_id': eventId,
        'met_at': metAt.toUtc().toIso8601String(),
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
    );
  }
}

/// The saves waiting for a signal, kept across restarts until the server
/// has answered each. Cleared at sign-out with the rest of the person's
/// data (session_services.dart): they were theirs to send.
abstract class PendingSaveStore {
  /// Oldest first.
  Future<List<PendingSave>> all();

  /// Saving the same person again replaces the earlier one.
  Future<void> add(PendingSave save);

  Future<void> remove(Iterable<String> clientRefs);
  Future<void> clear();
}

class MemoryPendingSaveStore implements PendingSaveStore {
  final List<PendingSave> saved = [];

  @override
  Future<List<PendingSave>> all() async => List.of(saved);

  @override
  Future<void> add(PendingSave save) async {
    saved.removeWhere((s) => s.who == save.who || s.clientRef == save.clientRef);
    saved.add(save);
  }

  @override
  Future<void> remove(Iterable<String> clientRefs) async {
    final gone = clientRefs.toSet();
    saved.removeWhere((s) => gone.contains(s.clientRef));
  }

  @override
  Future<void> clear() async => saved.clear();
}

/// One JSON file in the app's support directory (not its cache, which the
/// system may empty), written whole or not at all.
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

  Future<List<PendingSave>> _read() async {
    final file = await _fileOf();
    if (!await file.exists()) return [];
    try {
      final data = jsonDecode(await file.readAsString());
      return [
        for (final item in data is List ? data : const [])
          if (PendingSave.fromJson(item) case final save?) save,
      ];
    } catch (e) {
      debugPrint('FilePendingSaveStore: unreadable: $e');
      return [];
    }
  }

  Future<void> _write(List<PendingSave> saves) async {
    final file = await _fileOf();
    if (saves.isEmpty) {
      if (await file.exists()) await file.delete();
      return;
    }
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode([for (final s in saves) s.toJson()]),
        flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<List<PendingSave>> all() => _serial(_read);

  @override
  Future<void> add(PendingSave save) => _serial(() async {
        final saves = await _read()
          ..removeWhere(
              (s) => s.who == save.who || s.clientRef == save.clientRef)
          ..add(save);
        await _write(saves);
      });

  @override
  Future<void> remove(Iterable<String> clientRefs) => _serial(() async {
        final gone = clientRefs.toSet();
        final saves = await _read()
          ..removeWhere((s) => gone.contains(s.clientRef));
        await _write(saves);
      });

  @override
  Future<void> clear() => _serial(() => _write(const []));
}

final pendingSaveStoreProvider =
    Provider<PendingSaveStore>((ref) => FilePendingSaveStore());
