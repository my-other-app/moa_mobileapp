import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/data/scan_queue.dart';
import 'package:finnet/features/volunteer/domain/gate_copy.dart';

/// The last answer at the door, with the scan's result when there was one.
class GateCard {
  const GateCard(this.card, {this.result, this.queued = false, this.seq = 0});

  final OutcomeCard card;
  final GateScanResult? result;

  /// Saved on the phone, not answered yet.
  final bool queued;

  /// Which answer this is: a card replaced by the next is a new one.
  final int seq;
}

class GateState {
  const GateState({
    this.context,
    this.loading = true,
    this.contextError,
    this.queued = 0,
    this.card,
    this.busy = false,
    this.report,
    this.syncing = false,
    this.syncError,
  });

  /// What the server says of this event and this volunteer, once read.
  final GateContext? context;
  final bool loading;

  /// Why it could not be read; scanning still works (scans are saved).
  final String? contextError;

  /// Scans saved on the phone, waiting to be sent.
  final int queued;
  final GateCard? card;

  /// A scan or a check-in on its way.
  final bool busy;

  /// What the server said of the saved scans it has taken since the
  /// volunteer last read the report.
  final ReplayReport? report;
  final bool syncing;

  /// The server refused the saved scans as a batch (no longer on the
  /// team, say): they stay on the phone.
  final String? syncError;

  GateState copyWith({
    GateContext? context,
    bool? loading,
    String? contextError,
    bool clearContextError = false,
    int? queued,
    GateCard? card,
    bool clearCard = false,
    bool? busy,
    ReplayReport? report,
    bool clearReport = false,
    bool? syncing,
    String? syncError,
    bool clearSyncError = false,
  }) =>
      GateState(
        context: context ?? this.context,
        loading: loading ?? this.loading,
        contextError:
            clearContextError ? null : (contextError ?? this.contextError),
        queued: queued ?? this.queued,
        card: clearCard ? null : (card ?? this.card),
        busy: busy ?? this.busy,
        report: clearReport ? null : (report ?? this.report),
        syncing: syncing ?? this.syncing,
        syncError: clearSyncError ? null : (syncError ?? this.syncError),
      );
}

/// The door for one event, on a volunteer's phone: as the club dashboard's
/// door console (moa_web `gate/queries.ts`).
///
/// A scan goes to `/gate/scan` and is answered at once. When no answer
/// comes -- no signal at the door -- it is saved on the phone
/// ([ScanQueueStore]) and shown as saved, honestly: "welcome in" is never
/// said before the server has committed. The saved scans are sent through
/// `/gate/scan-batch` when the app is back online, every [drainEvery], and
/// when the console opens; the server admits each once, by its client ref,
/// whichever phones come back first. Those it does not admit are listed by
/// name in [GateState.report].
class GateController extends StateNotifier<GateState> {
  GateController({
    required this.eventId,
    required GateApi api,
    required ScanQueueStore queue,
    NetworkStatus? network,
    Duration? drainEvery = const Duration(seconds: 15),
    DateTime Function()? now,
    String Function()? newRef,
  })  : _api = api,
        _queue = queue,
        _network = network,
        _now = now ?? DateTime.now,
        _newRef = newRef ?? _randomRef,
        super(const GateState()) {
    _network?.backOnline.addListener(_onBackOnline);
    if (drainEvery != null) {
      _timer = Timer.periodic(drainEvery, (_) => drain());
    }
  }

  final int eventId;
  final GateApi _api;
  final ScanQueueStore _queue;
  final NetworkStatus? _network;
  final DateTime Function() _now;
  final String Function() _newRef;
  Timer? _timer;
  bool _draining = false;
  int _seq = 0;

  static final _random = Random.secure();

  /// A scan's own reference: 8 to 64 characters, never reused.
  static String _randomRef() {
    final bytes = List<int>.generate(12, (_) => _random.nextInt(256));
    return 'app-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  /// Read the event and the queue, and send what was saved.
  Future<void> start() async {
    await Future.wait([load(), _refreshCount()]);
    await drain();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, clearContextError: true);
    try {
      final context = await _api.context(eventId);
      if (!mounted) return;
      state = state.copyWith(context: context, loading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loading: false,
        contextError: gateErrorMessage(
            e, "We couldn't read this event's door. Try again."),
      );
    }
  }

  Future<void> _refreshCount() async {
    try {
      final n = (await _queue.all(eventId)).length;
      if (mounted) state = state.copyWith(queued: n);
    } catch (e) {
      debugPrint('GateController: could not read the queue: $e');
    }
  }

  /// The door every admission here is recorded at: the volunteer's own,
  /// else the event's default (the server picks it).
  String? get _door => state.context?.doorName;

  /// A ticket's code at the door, scanned or typed.
  Future<void> scan(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty || state.busy) return;
    final scan = QueuedScan(
      eventId: eventId,
      code: trimmed,
      clientRef: _newRef(),
      scannedAt: _now(),
      door: _door,
    );
    state = state.copyWith(busy: true);
    try {
      final result = await _api.scan(eventId, scan);
      if (!mounted) return;
      _show(GateCard(outcomeCard(result, door: _doorLabel, now: _now()),
          result: result));
      if (result.admitted && !result.replayed) _bumpCount();
      // Something got through: anything saved can go too.
      if (state.queued > 0) unawaited(drain());
    } catch (e) {
      if (!mounted) return;
      if (_keepForLater(e)) {
        await _queue.add(scan);
        await _refreshCount();
        if (!mounted) return;
        _show(const GateCard(queuedCard, queued: true));
      } else {
        _show(GateCard(OutcomeCard(
          tone: GateTone.refuse,
          tag: 'Not checked in',
          title: gateErrorMessage(e, "The scan wasn't taken. Try again."),
        )));
      }
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  /// No answer, or the server down for a moment (a deploy's 502): the scan
  /// is kept and sent again. A refusal the server meant is not.
  static bool _keepForLater(Object e) {
    if (gotNoAnswer(e)) return true;
    return e is DioException && ApiCacheInterceptor.serverDown(e);
  }

  String get _doorLabel => _door ?? 'Door';

  void _show(GateCard card) {
    state = state.copyWith(
        card: GateCard(card.card,
            result: card.result, queued: card.queued, seq: ++_seq));
  }

  void _bumpCount() {
    final c = state.context;
    final n = c?.checkedIn;
    if (c == null || n == null) return;
    state = state.copyWith(context: c.withCheckedIn(n + 1));
  }

  /// Someone found by name (or holding an admission number), checked in by
  /// hand: a person has looked at them. Needs the signal.
  Future<GateScanResult?> checkInByHand(GateAttendee guest) async {
    if (state.busy) return null;
    state = state.copyWith(busy: true);
    try {
      final result = await _api.checkInByHand(eventId, guest.id, door: _door);
      if (!mounted) return result;
      _show(GateCard(outcomeCard(result, door: _doorLabel, now: _now()),
          result: result));
      if (result.admitted && !result.replayed) _bumpCount();
      return result;
    } catch (e) {
      if (mounted) {
        _show(GateCard(OutcomeCard(
          tone: GateTone.refuse,
          tag: 'Not checked in',
          title: gateErrorMessage(e, "They weren't checked in. Try again."),
        )));
      }
      return null;
    } finally {
      if (mounted) state = state.copyWith(busy: false);
    }
  }

  /// Send the saved scans, [GateApi.batchSize] at a time. Quiet when there
  /// is nothing to send or still no signal; the next tick tries again.
  Future<void> drain() async {
    if (_draining || !mounted) return;
    _draining = true;
    try {
      final pending = await _queue.all(eventId);
      if (pending.isEmpty || !mounted) return;
      state = state.copyWith(syncing: true);
      for (var i = 0; i < pending.length; i += GateApi.batchSize) {
        final slice =
            pending.sublist(i, min(i + GateApi.batchSize, pending.length));
        final results = await _api.scanBatch(eventId, slice);
        await _queue.remove(eventId, results.map((r) => r.clientRef));
        if (!mounted) return;
        state = state.copyWith(
          report: withReplayed(state.report, results),
          clearSyncError: true,
        );
      }
      // The counters moved: read them again.
      unawaited(load());
    } catch (e) {
      if (!_keepForLater(e) && mounted) {
        state = state.copyWith(
            syncError: gateErrorMessage(
                e, "The saved scans couldn't be sent. They stay saved."));
      }
    } finally {
      _draining = false;
      if (mounted) {
        state = state.copyWith(syncing: false);
        await _refreshCount();
      }
    }
  }

  void _onBackOnline() => unawaited(drain());

  void dismissCard() => state = state.copyWith(clearCard: true);

  void dismissReport() => state = state.copyWith(clearReport: true);

  @override
  void dispose() {
    _timer?.cancel();
    _network?.backOnline.removeListener(_onBackOnline);
    super.dispose();
  }
}

/// The door for an event: while its console is open.
final gateControllerProvider = StateNotifierProvider.autoDispose
    .family<GateController, GateState, int>((ref, eventId) {
  final controller = GateController(
    eventId: eventId,
    api: ref.watch(gateApiProvider),
    queue: ref.watch(scanQueueStoreProvider),
    network: ref.watch(networkStatusProvider),
    drainEvery: ref.watch(gateDrainEveryProvider),
  );
  unawaited(controller.start());
  return controller;
});

/// How often the saved scans are tried again; null for never (tests).
final gateDrainEveryProvider =
    Provider<Duration?>((ref) => const Duration(seconds: 15));
