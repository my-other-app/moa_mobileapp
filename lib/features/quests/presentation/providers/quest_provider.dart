import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/core/services/push_arrivals.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/ticketing_api.dart';
import 'package:finnet/features/quests/data/quest_api.dart';
import 'package:finnet/features/quests/domain/quest.dart';

/// The quest card's state, for one event.
class QuestState {
  const QuestState({
    this.quest,
    this.loading = true,
    this.offline = false,
    this.counting = false,
    this.notCounted = false,
    this.newlyUnlocked = const {},
  });

  /// The card; null before the first read, and when there is nothing to
  /// show (no quest, an older server, a failure with no copy kept).
  final Quest? quest;

  /// The first read is on its way.
  final bool loading;

  /// What is shown is the copy kept on the phone: there was no signal.
  final bool offline;

  /// Someone was just saved in the Network: the server counts the meeting
  /// within a few seconds, and the card is read again until it has.
  final bool counting;

  /// The last saves were read back without the count moving: those people
  /// did not count towards the task (not checked in here, too many in a
  /// minute, or met before).
  final bool notCounted;

  /// Milestones unlocked while the card was open.
  final Set<String> newlyUnlocked;

  /// Whether the card shows at all: the event has a quest and it is on, or
  /// it is switched off with a reward still held for the guest (then only
  /// that shows: [Quest.paused]).
  bool get visible => quest?.shows ?? false;

  QuestState copyWith({
    Quest? Function()? quest,
    bool? loading,
    bool? offline,
    bool? counting,
    bool? notCounted,
    Set<String>? newlyUnlocked,
  }) =>
      QuestState(
        quest: quest != null ? quest() : this.quest,
        loading: loading ?? this.loading,
        offline: offline ?? this.offline,
        counting: counting ?? this.counting,
        notCounted: notCounted ?? this.notCounted,
        newlyUnlocked: newlyUnlocked ?? this.newlyUnlocked,
      );
}

/// How picking a size went: null when it was saved, else what to say (and
/// the sizes left, when the one picked just went).
typedef SizeOutcome = ({String message, List<QuestSizeChoice> sizesLeft})?;

/// Keeps one event's quest card current: from the copy on the phone at
/// once, then the server; again when the phone is back online, when a push
/// arrives (an unlock, say), on a pull, and after a code or a size. After a
/// Network save it is read again a few times, as the server counts the
/// meeting a few seconds later ([afterNetworkSave]).
class QuestNotifier extends StateNotifier<QuestState> {
  QuestNotifier(
    this._api,
    this.eventId, {
    this.recheckAfterSave = defaultRechecks,
    this.onFresh,
  }) : super(const QuestState());

  final QuestApi _api;
  final int eventId;

  /// Told each card the server answers (not a kept copy): the freshest word
  /// on whether the event has a quest to show ([QuestFlags.noteCard]).
  final void Function(Quest quest)? onFresh;

  /// When the card is read again after a save, counted from the save.
  final List<Duration> recheckAfterSave;

  static const defaultRechecks = [
    Duration(seconds: 3),
    Duration(seconds: 8),
    Duration(seconds: 15),
    Duration(seconds: 30),
  ];

  Future<void>? _reading;
  Timer? _recheck;
  int _recheckStep = 0;

  /// The Network task's count before the saves being waited for, and how
  /// many saves that is.
  int? _countBefore;
  int _savesWaiting = 0;

  /// The milestones unlocked the first time the card was read.
  Set<String>? _unlockedAtOpen;

  /// The saved copy, then the server's.
  Future<void> load() async {
    try {
      final saved = await _api.saved(eventId);
      if (saved != null && mounted && state.quest == null) {
        // Shown at once; the server's answer follows.
        _show(saved, offline: false, loading: true);
      }
    } catch (e) {
      debugPrint('Quest $eventId: no saved copy: $e');
    }
    await refresh();
  }

  /// The card from the server. A failure keeps what is shown (marked as
  /// the phone's copy); with nothing shown, the card stays hidden.
  Future<void> refresh() => _reading ??= _read().whenComplete(() {
        _reading = null;
      });

  Future<void> _read() async {
    try {
      final read = await _api.card(eventId);
      if (!mounted) return;
      _show(read.quest, offline: read.offline);
      if (!read.offline) onFresh?.call(read.quest);
    } catch (e) {
      if (!mounted) return;
      final status = statusCodeOf(e);
      if (status == 404 || status == 403) {
        // No quest here (or a server from before quests): nothing shows.
        state =
            state.copyWith(quest: () => null, loading: false, offline: false);
        return;
      }
      state = state.copyWith(loading: false, offline: state.quest != null);
    }
  }

  void _show(Quest quest, {required bool offline, bool loading = false}) {
    final unlocked = quest.unlockedIds;
    final atOpen = _unlockedAtOpen ??= unlocked;
    final fresh = unlocked.difference(atOpen);
    state = state.copyWith(
      quest: () => quest,
      loading: loading,
      offline: offline,
      newlyUnlocked: fresh.isEmpty
          ? state.newlyUnlocked
          : {...state.newlyUnlocked, ...fresh},
    );
    _checkCounted(quest);
  }

  // ─── After a Network save ─────────────────────────────────────────────

  int? get _networkCount => state.quest?.networkTask?.count;

  /// A person was saved at this event.
  ///
  /// With the save's own [counts] (contract v1.2 §8.6: the server counts
  /// the saver's "meet people" tasks in the save itself), the card shows
  /// them at once ("3 of 5 met"); [newMeeting] says whether the save was a
  /// new meeting, so a count that did not move is said ("didn't add").
  /// A task just done means milestones may have unlocked: the card is read
  /// once more for them.
  ///
  /// Without counts (a server from before them), the card is read again
  /// until the Network task's count has moved for every save made, a few
  /// times over half a minute. Nothing for a quest without that task, or
  /// once it is done.
  void afterNetworkSave({QuestNetworkCounts? counts, bool newMeeting = true}) {
    final shown = state.quest;
    if (counts != null &&
        (counts.eventId == null || counts.eventId == eventId)) {
      if (shown == null) {
        unawaited(refresh());
      } else {
        _showCounts(shown, counts, newMeeting: newMeeting);
      }
      return;
    }
    if (!newMeeting) return;
    final task = shown?.networkTask;
    if (task == null || task.done || shown?.me == null) return;
    _countBefore ??= task.count;
    _savesWaiting++;
    _recheckStep = 0;
    state = state.copyWith(counting: true, notCounted: false);
    _scheduleRecheck();
  }

  void _scheduleRecheck() {
    _recheck?.cancel();
    if (_recheckStep >= recheckAfterSave.length) {
      _stopCounting(counted: false);
      return;
    }
    final wait = _recheckStep == 0
        ? recheckAfterSave.first
        : recheckAfterSave[_recheckStep] - recheckAfterSave[_recheckStep - 1];
    _recheck = Timer(wait, () async {
      _recheckStep++;
      await refresh();
      if (!mounted || !state.counting) return;
      _scheduleRecheck();
    });
  }

  void _checkCounted(Quest quest) {
    final before = _countBefore;
    if (!state.counting || before == null) return;
    final task = quest.networkTask;
    if (task == null) {
      _stopCounting(counted: true);
      return;
    }
    if (task.done || task.count - before >= _savesWaiting) {
      _stopCounting(counted: true);
    }
  }

  void _showCounts(Quest shown, QuestNetworkCounts counts,
      {required bool newMeeting}) {
    // The save's answer is the server's count now: nothing left to wait
    // for, from this save or any before it.
    _recheck?.cancel();
    _recheck = null;
    _countBefore = null;
    _savesWaiting = 0;
    final before = shown.networkTask;
    final updated = shown.withNetworkCounts(counts);
    final after = updated.networkTask;
    final justDone = {
      for (final c in counts.tasks)
        if (c.done) c.taskId,
    }.any((id) => shown.tasks.any((t) => t.id == id && !t.done));
    final didNotAdd = newMeeting &&
        before != null &&
        after != null &&
        !after.done &&
        after.count <= before.count;
    state = state.copyWith(
      quest: () => updated,
      counting: false,
      notCounted: didNotAdd,
    );
    // Done: its milestone may have unlocked in the same save.
    if (justDone) unawaited(refresh());
  }

  void _stopCounting({required bool counted}) {
    _recheck?.cancel();
    _recheck = null;
    final before = _countBefore;
    final now = _networkCount;
    // Some of the saves counted: only the rest didn't.
    final none = !counted && (before == null || now == null || now <= before);
    _countBefore = null;
    _savesWaiting = 0;
    if (!mounted) return;
    state = state.copyWith(counting: false, notCounted: none);
  }

  // ─── A code, a size ───────────────────────────────────────────────────

  /// Enters a code from the stage or the venue. The card is the server's
  /// answer when it sends one, else read again.
  Future<CodeOutcome> enterCode(String code) async {
    final outcome = await _api.enterCode(eventId, code.trim());
    if (!mounted) return outcome;
    final card = switch (outcome) {
      CodeDone(:final card) => card,
      CodeAlreadyDone(:final card) => card,
      _ => null,
    };
    if (card != null) {
      _show(card, offline: false);
    } else if (outcome is CodeWrong || outcome is CodeLocked) {
      // The tries left changed.
      unawaited(refresh());
    }
    return outcome;
  }

  /// Picks [label] for [claim].
  Future<SizeOutcome> chooseSize(QuestClaim claim, String label) async {
    try {
      final saved = await _api.chooseSize(eventId, claim.id, label);
      if (mounted && state.quest != null) {
        state = state.copyWith(quest: () => state.quest!.withClaim(saved));
      }
      unawaited(refresh());
      return null;
    } catch (e) {
      final left = sizesLeftIn(e);
      unawaited(refresh());
      if (left.isNotEmpty || errorCodeOf(e) == 'QUEST_SIZE_GONE') {
        return (
          message: 'Size $label just went. Pick another.',
          sizesLeft: left,
        );
      }
      if (errorCodeOf(e) == 'QUEST_CLAIM_NOT_RESERVED') {
        return (
          message: 'This reward is no longer held for you.',
          sizesLeft: const <QuestSizeChoice>[],
        );
      }
      return (
        message: extractErrorMessage(e,
            defaultMessage: "That size didn't save. Try again."),
        sizesLeft: const <QuestSizeChoice>[],
      );
    }
  }

  @override
  void dispose() {
    _recheck?.cancel();
    super.dispose();
  }
}

/// One event's quest card, shared by the event page, the ticket, the quest
/// page and the scanner's progress line while any of them is open.
final questProvider = StateNotifierProvider.autoDispose
    .family<QuestNotifier, QuestState, int>((ref, eventId) {
  // Signing in or out changes whose card it is.
  ref.watch(isAuthenticatedProvider);
  final notifier = QuestNotifier(
    ref.watch(questApiProvider),
    eventId,
    // A card read now is fresher than what the event's info said: a quest
    // switched on since shows wherever its card is drawn.
    onFresh: (quest) =>
        ref.read(questFlagsProvider.notifier).noteCard(eventId, quest),
  );
  ref.listen<int>(backOnlineProvider, (_, __) => notifier.refresh());
  // A push while the app is open may be this quest's unlock.
  void pushed() => notifier.refresh();
  PushArrivals.count.addListener(pushed);
  ref.onDispose(() => PushArrivals.count.removeListener(pushed));
  unawaited(notifier.load());
  return notifier;
});

/// The leaderboard of an event's quest, while it is on; null when off.
final questLeaderboardProvider =
    FutureProvider.autoDispose.family<QuestLeaderboard?, int>((ref, eventId) {
  ref.watch(backOnlineProvider);
  return ref.watch(questApiProvider).leaderboard(eventId);
});

/// What each event's info said of its quest this session (`/events/info`'s
/// `quest`, contract §8.5), by event id: the event page notes it, and the
/// card, the ticket's card and the scanner's line ask for the quest only
/// when it says there is something to show. An event not noted (never
/// opened, or a server from before the flag) is asked as before.
class QuestFlags extends StateNotifier<Map<int, QuestFlag>> {
  QuestFlags() : super(const {});

  /// [flag] for [eventId]; null forgets it (a server without the flag).
  void note(int eventId, QuestFlag? flag) {
    if (flag == null) {
      if (!state.containsKey(eventId)) return;
      state = {...state}..remove(eventId);
      return;
    }
    final had = state[eventId];
    if (had != null &&
        had.enabled == flag.enabled &&
        had.canTakePart == flag.canTakePart &&
        had.held == flag.held) {
      return;
    }
    state = {...state, eventId: flag};
  }

  /// What a card just read from the server says, as a flag.
  void noteCard(int eventId, Quest quest) => note(
        eventId,
        QuestFlag(
          enabled: quest.enabled,
          canTakePart: quest.enabled && quest.takingPart,
          held: !quest.enabled && quest.paused != null,
        ),
      );
}

/// Signing in or out changes whose flags they are: they start again.
final questFlagsProvider =
    StateNotifierProvider<QuestFlags, Map<int, QuestFlag>>((ref) {
  ref.watch(isAuthenticatedProvider);
  return QuestFlags();
});

/// Whether [eventId]'s quest card is worth asking for, by its flag: yes
/// when the quest is on or a reward is held, and for an event whose flag
/// isn't known. [onlyTakingPart]: the ticket's card, for a guest who can
/// take part.
bool questWorthAsking(Map<int, QuestFlag> flags, int eventId,
        {bool onlyTakingPart = false}) =>
    flags[eventId]?.worthAsking(onlyTakingPart: onlyTakingPart) ?? true;

/// The event's name, for a quest page opened without it (a push names
/// only the event's id): from the event's public page, as the ticket list
/// reads it (`/discover/events/{id}`, kept on the phone; it counts no
/// view). Null for an event that isn't public, or with nothing to go on.
final questEventNameProvider =
    FutureProvider.autoDispose.family<String?, int>((ref, eventId) async {
  try {
    final event = await ref.watch(ticketingApiProvider).publicEvent(eventId);
    final name = jsonString(event?['name'])?.trim();
    return name == null || name.isEmpty ? null : name;
  } catch (e) {
    debugPrint('Quest $eventId: no event name: $e');
    return null;
  }
});
