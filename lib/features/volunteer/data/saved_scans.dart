import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/data/scan_queue.dart';

/// What one try at sending an event's saved scans came to.
class SendResult {
  const SendResult({
    this.answered = const [],
    this.askedAgain = 0,
    this.error,
    this.sentAny = false,
  });

  /// The final answers, admitted or refused: those scans left the phone.
  final List<ReplayedScan> answered;

  /// Scans the server asked for again: still saved, sent after a wait.
  final int askedAgain;

  /// Why sending stopped (no signal, or the server refused the batch);
  /// the scans not answered stay saved.
  final Object? error;

  /// Whether anything was due and sent at all.
  final bool sentAny;
}

/// What sending every event's saved scans came to.
class SendAllResult {
  const SendAllResult({this.answered = 0, this.left = 0, this.error});

  /// Scans the server gave a final answer about.
  final int answered;

  /// Scans still saved on the phone afterwards.
  final int left;

  /// The first reason sending stopped, if it did.
  final Object? error;
}

/// Sends the door scans saved on the phone, for the signed-in account
/// ([ScanQueueStore] is that account's): from the console while it is
/// open, and by itself when the account is back -- a sign-in, a session
/// restored at start-up, the phone back online -- so scans saved before a
/// sign-out are never stranded.
///
/// A scan leaves the phone only on a final answer about it: admitted, or
/// refused for a reason the ticket has. One the server asks for again
/// (`retry: true`: it couldn't record it just now) stays, and is sent
/// again after [QueuedScan.retryFirst], doubling to [QueuedScan.retryMax];
/// so does one whose answer can't be read, and one with no answer at all.
///
/// One send an event at a time: a second ask while one runs gets the same
/// result. A console open on the event hears every final answer ([watch]),
/// whoever sent it; answers that came while no console was open are kept
/// for the next one to open on that event, to list who was refused.
class SavedScanSender {
  SavedScanSender({
    required GateApi Function() api,
    required ScanQueueStore queue,
    DateTime Function()? now,
    this.active = true,
  })  : _api = api,
        _queue = queue,
        _now = now ?? DateTime.now;

  /// Whether someone is signed in: with nobody, [sendAll] sends nothing.
  /// (An open console sends its own event's, through [send].)
  final bool active;

  final GateApi Function() _api;
  final ScanQueueStore _queue;
  final DateTime Function() _now;

  final Map<int, Future<SendResult>> _running = {};
  final Map<int, void Function(List<ReplayedScan>)> _watchers = {};
  final Map<int, List<ReplayedScan>> _unseen = {};
  bool _closed = false;

  /// At most this many unseen answers kept an event.
  static const keepUnseen = 500;

  /// [onAnswers] hears each batch of final answers for [eventId], starting
  /// with any that came while nobody watched. The returned function stops
  /// it.
  void Function() watch(
      int eventId, void Function(List<ReplayedScan>) onAnswers) {
    _watchers[eventId] = onAnswers;
    final unseen = _unseen.remove(eventId);
    if (unseen != null && unseen.isNotEmpty) onAnswers(unseen);
    return () {
      if (identical(_watchers[eventId], onAnswers)) _watchers.remove(eventId);
    };
  }

  void _tell(int eventId, List<ReplayedScan> answers) {
    if (answers.isEmpty) return;
    final watcher = _watchers[eventId];
    if (watcher != null) {
      watcher(answers);
      return;
    }
    final kept = _unseen.putIfAbsent(eventId, () => [])..addAll(answers);
    if (kept.length > keepUnseen) kept.removeRange(0, kept.length - keepUnseen);
  }

  /// Every saved scan of this account, across events; 0 when the queue
  /// can't be read.
  Future<int> count() async {
    try {
      return await _queue.count();
    } catch (e) {
      debugPrint('SavedScanSender: could not count the saved scans: $e');
      return 0;
    }
  }

  /// Send [eventId]'s saved scans that are due ([force]: all of them, as
  /// "Send now" asks), [GateApi.batchSize] at a time. [onSending] runs
  /// once something is about to go. Never throws.
  Future<SendResult> send(int eventId,
      {bool force = false, void Function()? onSending}) {
    final running = _running[eventId];
    if (running != null) return running;
    final run = _send(eventId, force: force, onSending: onSending);
    _running[eventId] = run;
    return run.whenComplete(() => _running.remove(eventId));
  }

  Future<SendResult> _send(int eventId,
      {required bool force, void Function()? onSending}) async {
    final answered = <ReplayedScan>[];
    var again = 0;
    var sentAny = false;
    try {
      final now = _now();
      final pending = (await _queue.all(eventId))
          .where((s) => force || s.isDue(now))
          .toList();
      if (pending.isEmpty || _closed) return const SendResult();
      onSending?.call();
      final api = _api();
      for (var i = 0; i < pending.length; i += GateApi.batchSize) {
        if (_closed) break;
        final slice =
            pending.sublist(i, min(i + GateApi.batchSize, pending.length));
        sentAny = true;
        final results = await api.scanBatch(eventId, slice);
        final saved = {for (final s in slice) s.clientRef: s};
        final done = <ReplayedScan>[];
        final retry = <QueuedScan>[];
        for (final r in results) {
          final scan = saved.remove(r.clientRef);
          if (scan == null) continue;
          if (r.isFinal) {
            done.add(r.scan == null
                ? ReplayedScan(
                    clientRef: r.clientRef, result: r.result, scan: scan)
                : r);
          } else {
            retry.add(scan.askedAgainAt(_now()));
          }
        }
        await _queue.remove(eventId, done.map((r) => r.clientRef));
        await _queue.update(eventId, retry);
        again += retry.length;
        answered.addAll(done);
        _tell(eventId, done);
      }
      return SendResult(
          answered: answered, askedAgain: again, sentAny: sentAny);
    } catch (e) {
      debugPrint('SavedScanSender: event $eventId not sent: $e');
      return SendResult(
          answered: answered, askedAgain: again, error: e, sentAny: sentAny);
    }
  }

  /// Send every event's saved scans that are due ([force]: all). Stops at
  /// the first event that gets no answer: there is no signal for the rest
  /// either. Never throws.
  Future<SendAllResult> sendAll({bool force = false}) async {
    var answered = 0;
    Object? error;
    if (!active) return const SendAllResult();
    try {
      for (final eventId in await _queue.events()) {
        if (_closed) break;
        final result = await send(eventId, force: force);
        answered += result.answered.length;
        error ??= result.error;
        if (result.error != null && noAnswer(result.error!)) break;
      }
    } catch (e) {
      debugPrint('SavedScanSender: could not send the saved scans: $e');
      error ??= e;
    }
    return SendAllResult(answered: answered, left: await count(), error: error);
  }

  /// No answer, or the server down for a moment (a deploy's 502): the scans
  /// are kept and sent again. A refusal the server meant is not this.
  static bool noAnswer(Object e) =>
      gotNoAnswer(e) ||
      (e is DioException && ApiCacheInterceptor.serverDown(e));

  /// The session these scans belong to has ended: nothing more is sent by
  /// this sender (the next session has its own).
  void close() => _closed = true;
}

/// The signed-in account's sender: one a session. It sends by itself when
/// the phone comes back online.
final savedScanSenderProvider = Provider<SavedScanSender>((ref) {
  final signedIn = ref.watch(isAuthenticatedProvider);
  final sender = SavedScanSender(
    api: () => ref.read(gateApiProvider),
    queue: ref.watch(scanQueueStoreProvider),
    active: signedIn,
  );
  if (signedIn) {
    ref.listen<int>(backOnlineProvider, (_, __) => unawaited(sender.sendAll()));
  }
  ref.onDispose(sender.close);
  return sender;
});
