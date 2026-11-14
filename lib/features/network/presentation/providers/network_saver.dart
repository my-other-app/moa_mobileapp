import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/auth/jwt_claims.dart';
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
  const PendingSaves({
    this.count = 0,
    this.syncing = false,
    this.notices = const [],
  });

  /// Saves made with no signal, still to send.
  final int count;
  final bool syncing;

  /// What became of earlier ones the person should hear of: refused, or
  /// saved without their event. Newest first; kept until dismissed.
  final List<SaveNotice> notices;

  PendingSaves copyWith(
          {int? count, bool? syncing, List<SaveNotice>? notices}) =>
      PendingSaves(
        count: count ?? this.count,
        syncing: syncing ?? this.syncing,
        notices: notices ?? this.notices,
      );
}

/// The server keeps an offline scan's own time only this far back; older,
/// it records now and no event.
const offlineSaveMaxAge = Duration(hours: 72);

/// Saves people to the network: at once when the server can be reached,
/// else on the phone until it can -- venues often have no signal. The
/// waiting ones go when the phone is back online, when the Network tab or
/// the scanner opens, and after any save that got through.
///
/// Each waiting save is the account's that made it ([ownerId]): it goes
/// only while that account is signed in, and a send under way stops when
/// the session ends (this notifier is disposed with it).
class NetworkSaver extends StateNotifier<PendingSaves> {
  NetworkSaver(
    this._api,
    this._store, {
    this.ownerId,
    void Function()? onSynced,
    DateTime Function()? now,
    Random? random,
  })  : _onSynced = onSynced,
        _now = now ?? DateTime.now,
        _random = random ?? Random.secure(),
        super(const PendingSaves());

  final NetworkApi _api;
  final PendingSaveStore _store;

  /// The signed-in account; null when it can't be told (then every
  /// waiting save is taken as theirs).
  final int? ownerId;
  final void Function()? _onSynced;
  final DateTime Function() _now;
  final Random _random;
  Future<int>? _draining;

  String _newRef() =>
      List.generate(12, (_) => _random.nextInt(36).toRadixString(36)).join();

  bool _mine(PendingSave save) =>
      ownerId == null || save.ownerId == null || save.ownerId == ownerId;

  /// The server could not answer, or the person's session needs renewing:
  /// worth keeping, and trying again. Anything else it meant.
  static bool _worthKeeping(Object e) {
    if (gotNoAnswer(e)) return true;
    final status = statusCodeOf(e);
    return status == 401 ||
        status == 429 ||
        status == 502 ||
        status == 503 ||
        status == 504;
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
      if (gotNoAnswer(e) || const {502, 503, 504}.contains(statusCodeOf(e))) {
        final pending = PendingSave(
          clientRef: _newRef(),
          code: code,
          handle: handle,
          method: method,
          eventId: eventId,
          metAt: at,
          ownerId: ownerId,
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
      final count = (await _store.all()).where(_mine).length;
      final notices = await _store.notices();
      if (mounted) state = state.copyWith(count: count, notices: notices);
    } catch (e) {
      debugPrint('NetworkSaver: could not read the queue: $e');
    }
  }

  /// The notices, read: gone from the Network tab.
  Future<void> dismissNotices() async {
    try {
      await _store.clearNotices();
    } catch (e) {
      debugPrint('NetworkSaver: could not clear the notices: $e');
    }
    if (mounted) state = state.copyWith(notices: const []);
  }

  /// Sends what is waiting, oldest first; stops at the first that still
  /// can't get through. Answers how many went. One drain at a time.
  Future<int> drain() => _draining ??= _drain().whenComplete(() {
        _draining = null;
      });

  Future<int> _drain() async {
    List<PendingSave> waiting;
    try {
      waiting = (await _store.all()).where(_mine).toList();
    } catch (e) {
      debugPrint('NetworkSaver: could not read the queue: $e');
      return 0;
    }
    if (waiting.isEmpty) {
      if (mounted) state = state.copyWith(count: 0, syncing: false);
      return 0;
    }
    if (mounted) state = state.copyWith(count: waiting.length, syncing: true);
    var sent = 0;
    for (final save in waiting) {
      // Signed out (or another account in) since this began: stop here.
      if (!mounted) break;
      // Past what the server keeps of an offline scan's time: saved now,
      // without the event -- and said so, rather than claiming the meeting.
      final late = _now().difference(save.metAt) > offlineSaveMaxAge;
      try {
        await _api.save(
          code: save.code,
          handle: save.handle,
          method: save.method,
          eventId: late ? null : save.eventId,
          metAt: late ? null : save.metAt,
        );
        sent++;
        await _store.remove([save.clientRef]);
        if (late) {
          await _store.addNotice(SaveNotice(
            kind: SaveNoticeKind.late,
            save: save,
            message: 'Saved, but without where you met: there was no '
                'signal for more than 3 days.',
            at: _now(),
          ));
        }
      } catch (e) {
        if (_worthKeeping(e)) break;
        // Refused for good (a replaced code, themselves, gone): sending it
        // again changes nothing -- but they were told "Saved, it'll sync",
        // so they hear of it.
        await _store.remove([save.clientRef]);
        await _store.addNotice(SaveNotice(
          kind: SaveNoticeKind.refused,
          save: save,
          message: saveErrorMessage(e),
          at: _now(),
        ));
      }
    }
    if (sent > 0) _onSynced?.call();
    if (mounted) {
      state = state.copyWith(syncing: false);
      await refreshCount();
    }
    return sent;
  }
}

final networkSaverProvider =
    StateNotifierProvider<NetworkSaver, PendingSaves>((ref) {
  final saver = NetworkSaver(
    ref.watch(networkApiProvider),
    ref.watch(pendingSaveStoreProvider),
    ownerId:
        ref.watch(authStateProvider.select((s) => userIdOf(s.accessToken))),
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
