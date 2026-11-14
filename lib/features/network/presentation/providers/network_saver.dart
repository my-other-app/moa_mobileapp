import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/network/data/network_api.dart';
import 'package:finnet/features/network/data/save_queue.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/domain/network_errors.dart';
import 'package:finnet/features/network/presentation/providers/network_providers.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart' show gotNoAnswer;

/// How saving someone went.
sealed class SaveAttempt {
  const SaveAttempt();
}

/// Saved: the server's answer.
class Saved extends SaveAttempt {
  const Saved(this.result);
  final SaveResult result;
}

/// No signal: kept on the phone, with its time, and sent once there is one.
class SavedLater extends SaveAttempt {
  const SavedLater(this.save);
  final PendingSave save;
}

/// The server said no; [message] says why.
class SaveRefused extends SaveAttempt {
  const SaveRefused(this.message, {this.code, this.status});
  final String message;
  final String? code;
  final int? status;
}

class PendingSaves {
  const PendingSaves({this.count = 0, this.syncing = false});

  /// Saves made with no signal, still to send.
  final int count;
  final bool syncing;
}

/// Saves people to the network: at once when the server can be reached,
/// else on the phone until it can -- venues often have no signal. The
/// waiting ones go when the phone is back online, when the Network tab or
/// the scanner opens, and after any save that got through.
class NetworkSaver extends StateNotifier<PendingSaves> {
  NetworkSaver(
    this._api,
    this._store, {
    void Function()? onSynced,
    DateTime Function()? now,
    Random? random,
  })  : _onSynced = onSynced,
        _now = now ?? DateTime.now,
        _random = random ?? Random.secure(),
        super(const PendingSaves());

  final NetworkApi _api;
  final PendingSaveStore _store;
  final void Function()? _onSynced;
  final DateTime Function() _now;
  final Random _random;
  Future<int>? _draining;

  String _newRef() =>
      List.generate(12, (_) => _random.nextInt(36).toRadixString(36)).join();

  /// The server could not answer, or the person's session needs renewing:
  /// worth keeping, and trying again. Anything else it meant.
  static bool _worthKeeping(Object e) {
    if (gotNoAnswer(e)) return true;
    final status = statusCodeOf(e);
    return status == 401 || status == 429 || status == 502 ||
        status == 503 || status == 504;
  }

  Future<SaveAttempt> save({
    String? code,
    String? handle,
    required MetHow method,
    int? eventId,
  }) async {
    final at = _now();
    try {
      final result = await _api.save(
          code: code, handle: handle, method: method, eventId: eventId);
      _onSynced?.call();
      if (state.count > 0) unawaited(drain());
      return Saved(result);
    } catch (e) {
      if (gotNoAnswer(e) ||
          const {502, 503, 504}.contains(statusCodeOf(e))) {
        final pending = PendingSave(
          clientRef: _newRef(),
          code: code,
          handle: handle,
          method: method,
          eventId: eventId,
          metAt: at,
        );
        await _store.add(pending);
        await refreshCount();
        return SavedLater(pending);
      }
      return SaveRefused(saveErrorMessage(e),
          code: errorCodeOf(e), status: statusCodeOf(e));
    }
  }

  Future<void> refreshCount() async {
    try {
      final count = (await _store.all()).length;
      if (mounted) state = PendingSaves(count: count, syncing: state.syncing);
    } catch (e) {
      debugPrint('NetworkSaver: could not read the queue: $e');
    }
  }

  /// Sends what is waiting, oldest first; stops at the first that still
  /// can't get through. Answers how many went. One drain at a time.
  Future<int> drain() => _draining ??= _drain().whenComplete(() {
        _draining = null;
      });

  Future<int> _drain() async {
    List<PendingSave> waiting;
    try {
      waiting = await _store.all();
    } catch (e) {
      debugPrint('NetworkSaver: could not read the queue: $e');
      return 0;
    }
    if (waiting.isEmpty) {
      if (mounted) state = const PendingSaves();
      return 0;
    }
    if (mounted) state = PendingSaves(count: waiting.length, syncing: true);
    var sent = 0;
    for (final save in waiting) {
      try {
        await _api.save(
          code: save.code,
          handle: save.handle,
          method: save.method,
          eventId: save.eventId,
          metAt: save.metAt,
        );
        sent++;
        await _store.remove([save.clientRef]);
      } catch (e) {
        if (_worthKeeping(e)) break;
        // Refused for good (a replaced code, themselves, gone): nothing
        // sending it again would change.
        debugPrint('NetworkSaver: a waiting save was refused: $e');
        await _store.remove([save.clientRef]);
      }
    }
    if (sent > 0) _onSynced?.call();
    final left = (await _store.all()).length;
    if (mounted) state = PendingSaves(count: left);
    return sent;
  }
}

final networkSaverProvider =
    StateNotifierProvider<NetworkSaver, PendingSaves>((ref) {
  final saver = NetworkSaver(
    ref.watch(networkApiProvider),
    ref.watch(pendingSaveStoreProvider),
    onSynced: () {
      ref.invalidate(networkListProvider);
      ref.invalidate(savedMeProvider);
    },
  );
  final signedIn = ref.watch(isAuthenticatedProvider);
  if (signedIn) {
    ref.listen<int>(backOnlineProvider, (_, __) => saver.drain());
    unawaited(saver.refreshCount());
  }
  return saver;
});
