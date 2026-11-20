import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart'
    show feedbackRouteFrom;
import 'package:finnet/features/live/live_locations.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:finnet/features/quests/data/quest_api.dart';
import 'package:finnet/features/quests/domain/quest.dart';
import 'package:finnet/features/quests/presentation/providers/quest_provider.dart';
import 'package:finnet/features/quests/presentation/widgets/quest_sheets.dart';
import 'package:finnet/features/quests/quest_links.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

/// Where the card is drawn.
enum QuestCardStyle {
  /// The event page and the quest page.
  light,

  /// The ticket's dark screen.
  dark,
}

class _Palette {
  const _Palette({
    required this.background,
    required this.border,
    required this.ink,
    required this.soft,
    required this.accent,
    required this.track,
    required this.button,
    required this.buttonInk,
    required this.newBackground,
  });

  final Color background;
  final Color border;
  final Color ink;
  final Color soft;
  final Color accent;
  final Color track;
  final Color button;
  final Color buttonInk;
  final Color newBackground;

  static const light = _Palette(
    background: Color(0xFFFEFCE8),
    border: Color(0xFFFDE68A),
    ink: Color(0xFF1F2937),
    soft: Color(0xFF6B7280),
    accent: Color(0xFF15803D),
    track: Color(0xFFE5E7EB),
    button: AppColors.ink,
    buttonInk: Colors.white,
    newBackground: Color(0xFFDCFCE7),
  );

  static final dark = _Palette(
    background: Colors.white.withAlpha(14),
    border: Colors.white.withAlpha(40),
    ink: Colors.white,
    soft: Colors.white.withAlpha(180),
    accent: const Color(0xFFB8FF9F),
    track: Colors.white.withAlpha(30),
    button: const Color(0xFFF9FFA1),
    buttonInk: const Color(0xFF0A0A0F),
    newBackground: const Color(0xFFB8FF9F).withAlpha(40),
  );
}

/// An event's quest: the tasks with their ticks and points, how far it is
/// to the next milestone, the rewards unlocked and where to collect them,
/// and a button into each task -- the Network scanner, the live room, the
/// survey, the poster, the code box.
///
/// Draws nothing for an event without a quest, with the quest switched
/// off, from a server older than quests, or when it can't be read and no
/// copy is kept on the phone. Kept on the phone, it shows with no signal.
class QuestCard extends ConsumerStatefulWidget {
  const QuestCard({
    super.key,
    required this.eventId,
    this.eventName,
    this.style = QuestCardStyle.light,
    this.compact = true,
    this.onOpenTicket,
    this.onlyWhenTakingPart = false,
    this.now,
  });

  final int? eventId;
  final String? eventName;
  final QuestCardStyle style;

  /// The event page's and the ticket's: the tasks still to do first, a few
  /// of them, and a way to the quest page for the rest. The quest page
  /// shows everything.
  final bool compact;

  /// "Show ticket" for the check-in task; none when null (on the ticket).
  final VoidCallback? onOpenTicket;

  /// Nothing unless the viewer has a place in it (the ticket's: an
  /// overview there is no use).
  final bool onlyWhenTakingPart;

  /// The clock, for tests.
  final DateTime Function()? now;

  /// How many tasks the compact card lists.
  static const compactTasks = 5;

  static const cardKey = ValueKey('quest-card');
  static const progressKey = ValueKey('quest-progress');
  static const codeKey = ValueKey('quest-enter-code');
  static const openKey = ValueKey('quest-open-page');
  static const offlineKey = ValueKey('quest-offline');
  static const newKey = ValueKey('quest-newly-unlocked');
  static Key taskKey(String id) => ValueKey('quest-task-$id');
  static Key actionKey(String id) => ValueKey('quest-action-$id');
  static Key rewardKey(String id) => ValueKey('quest-reward-$id');
  static Key sizeKey(String id) => ValueKey('quest-reward-size-$id');

  @override
  ConsumerState<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends ConsumerState<QuestCard>
    with WidgetsBindingObserver {
  DateTime _now() => (widget.now ?? DateTime.now)();

  int? get _id {
    final id = widget.eventId;
    return id == null || id <= 0 ? null : id;
  }

  _Palette get _p =>
      widget.style == QuestCardStyle.dark ? _Palette.dark : _Palette.light;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the survey in the browser, or from another app: read again.
    final id = _id;
    if (state == AppLifecycleState.resumed && id != null) {
      unawaited(ref.read(questProvider(id).notifier).refresh());
    }
  }

  Future<void> _refreshAfter(Future<void> going) async {
    await going;
    final id = _id;
    if (mounted && id != null) {
      unawaited(ref.read(questProvider(id).notifier).refresh());
    }
  }

  void _say(String text) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openLink(String? link, String failed) async {
    final uri = link == null ? null : Uri.tryParse(link);
    if (uri == null) return;
    final opened = await ref.read(linkLauncherProvider)(uri);
    if (!opened && mounted) _say(failed);
  }

  Future<void> _enterCode(int id) async {
    final outcome = await showQuestCodeSheet(context, id);
    if (!mounted || outcome == null) return;
    final task = switch (outcome) {
      CodeDone(:final task) => task,
      CodeAlreadyDone(:final task) => task,
      _ => null,
    };
    _say(outcome is CodeAlreadyDone
        ? 'You have that one already.'
        : task == null
            ? 'Code accepted ✓'
            : '✓ ${task.title}');
  }

  Future<void> _act(Quest quest, QuestTask task) async {
    final id = quest.eventId;
    final router = GoRouter.maybeOf(context);
    switch (task.action) {
      case QuestAction.networkScan:
        if (router != null) {
          await _refreshAfter(router.push(savePersonScanAt(id)));
        }
      case QuestAction.liveRoom:
        final to = QuestKinds.quiz.contains(task.kind)
            ? liveQuizLocation(id)
            : liveRoomLocation(id);
        if (router != null) {
          await _refreshAfter(
              router.push(to, extra: {'eventName': widget.eventName}));
        }
      case QuestAction.feedback:
        final link = quest.links.feedback;
        final route = link == null ? null : feedbackRouteFrom(link);
        if (route != null && router != null) {
          await _refreshAfter(router.push(route));
        } else {
          await _openLink(link, "Couldn't open the survey");
        }
      case QuestAction.poster:
        await _openLink(quest.links.poster, "Couldn't open your poster");
      case QuestAction.follow:
        final link = quest.links.club;
        final uri = link == null ? null : Uri.tryParse(link);
        final route = uri == null ? null : webLocation(uri);
        if (route != null && router != null) {
          await _refreshAfter(router.push(route));
        } else {
          await _openLink(link, "Couldn't open the club");
        }
      case QuestAction.profile:
        if (router != null) {
          await _refreshAfter(router.push(editPublicProfileLocation));
        }
      case QuestAction.ticket:
        widget.onOpenTicket?.call();
      case QuestAction.code:
        await _enterCode(id);
      case QuestAction.station:
      case QuestAction.none:
        break;
    }
  }

  /// The button's words for [task], or null when it has none here.
  String? _actionLabel(Quest quest, QuestTask task) {
    if (task.done || !quest.takingPart || !quest.open) return null;
    if (task.windowAt(_now()) != QuestTaskWindow.open) return null;
    return switch (task.action) {
      QuestAction.networkScan => 'Scan a QR',
      QuestAction.liveRoom =>
        QuestKinds.quiz.contains(task.kind) ? 'Play' : 'Live room',
      QuestAction.feedback =>
        quest.links.feedback == null ? null : 'Give feedback',
      QuestAction.poster => quest.links.poster == null
          ? null
          : task.kind == QuestKinds.posterLink
              ? 'Share poster'
              : 'Make poster',
      QuestAction.follow => quest.links.club == null ? null : 'Follow',
      QuestAction.profile => 'Finish profile',
      QuestAction.ticket => widget.onOpenTicket == null ? null : 'Show ticket',
      QuestAction.code => 'Enter code',
      QuestAction.station || QuestAction.none => null,
    };
  }

  /// The line under a task's title.
  String? _taskLine(Quest quest, QuestTask task) {
    if (task.done) {
      return task.me?.source == 'grant'
          ? 'Marked done by the organisers'
          : null;
    }
    final now = _now();
    switch (task.windowAt(now)) {
      case QuestTaskWindow.notYet:
        return 'Opens ${questWhen(task.startsAt!, now)}';
      case QuestTaskWindow.over:
        return 'Closed';
      case QuestTaskWindow.open:
        break;
    }
    if (task.action == QuestAction.station) {
      return 'Get your ticket scanned at ${task.stationName ?? 'the station'}';
    }
    if (task.action == QuestAction.feedback && quest.links.feedback == null) {
      return task.description ?? 'Opens when the survey does';
    }
    return task.description;
  }

  @override
  Widget build(BuildContext context) {
    final id = _id;
    if (id == null) return const SizedBox.shrink();
    final state = ref.watch(questProvider(id));
    final quest = state.quest;
    if (quest == null || !state.visible) return const SizedBox.shrink();
    if (widget.onlyWhenTakingPart && !quest.takingPart) {
      return const SizedBox.shrink();
    }
    final p = _p;
    return Container(
      key: QuestCard.cardKey,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: p.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(quest),
          if (quest.intro != null) ...[
            const SizedBox(height: 4),
            Text(quest.intro!,
                maxLines: widget.compact ? 3 : null,
                overflow: widget.compact ? TextOverflow.ellipsis : null,
                style: TextStyle(fontSize: 13.5, color: p.soft, height: 1.3)),
          ],
          ..._window(quest),
          if (state.offline)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                key: QuestCard.offlineKey,
                children: [
                  Icon(Icons.cloud_off, size: 14, color: p.soft),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Offline: your progress as last seen',
                        style: TextStyle(fontSize: 12, color: p.soft)),
                  ),
                ],
              ),
            ),
          ..._progress(quest),
          ..._newlyUnlocked(quest, state.newlyUnlocked),
          ..._rewards(quest),
          const SizedBox(height: 8),
          ..._tasks(quest),
          ..._footer(quest),
        ],
      ),
    );
  }

  Widget _header(Quest quest) {
    final p = _p;
    final me = quest.me;
    final score = me == null
        ? null
        : quest.mode == QuestMode.points
            ? '${me.points} pts'
            : '${quest.doneCount} of ${quest.tasks.length} done';
    return Row(
      children: [
        Text('🎯', style: TextStyle(fontSize: 22, color: p.ink)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(quest.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: p.ink)),
        ),
        if (score != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.accent.withAlpha(36),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              me?.rank == null ? score : '$score · #${me!.rank}',
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: p.ink),
            ),
          ),
      ],
    );
  }

  List<Widget> _window(Quest quest) {
    final p = _p;
    final now = _now();
    String? line;
    if (!quest.open) {
      final start = quest.startsAt;
      line = start != null && start.isAfter(now)
          ? 'Starts ${questWhen(start, now)}'
          : 'This quest has ended';
    } else if (quest.endsAt case final end? when end.isAfter(now)) {
      // Only on its last day: a deadline weeks away is noise.
      if (end.difference(now) < const Duration(hours: 24)) {
        line = 'Ends ${questWhen(end, now)}';
      }
    }
    if (!quest.takingPart) {
      final signedIn = ref.watch(isAuthenticatedProvider);
      final join = signedIn
          ? 'Guests with a ticket take part: do the tasks, unlock the rewards.'
          : 'Sign in with your ticket to see your progress.';
      line = line == null ? join : '$line. $join';
    }
    if (line == null) return const [];
    return [
      const SizedBox(height: 6),
      Text(line, style: TextStyle(fontSize: 12.5, color: p.soft)),
    ];
  }

  List<Widget> _progress(Quest quest) {
    final line = quest.nextLine;
    if (line == null) return const [];
    final p = _p;
    return [
      const SizedBox(height: 12),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          key: QuestCard.progressKey,
          value: quest.progressToNext,
          minHeight: 8,
          backgroundColor: p.track,
          color: p.accent,
        ),
      ),
      const SizedBox(height: 6),
      Text(line,
          style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, color: p.ink)),
    ];
  }

  List<Widget> _newlyUnlocked(Quest quest, Set<String> ids) {
    if (ids.isEmpty) return const [];
    final p = _p;
    final titles = [
      for (final m in quest.milestones)
        if (ids.contains(m.id) && m.unlocked) m.title,
    ];
    if (titles.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      Container(
        key: QuestCard.newKey,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: p.newBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text('🎁 You unlocked ${titles.join(' and ')}!',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: p.ink)),
      ),
    ];
  }

  String _claimLine(Quest quest, QuestClaim claim) {
    switch (claim.status) {
      case QuestClaimStatus.reserved:
        if (claim.needsSize) {
          return 'Pick your size, then collect it at ${quest.deskLine}';
        }
        final size =
            claim.variantLabel == null ? '' : 'Size ${claim.variantLabel} · ';
        return '${size}Collect it at ${quest.deskLine}';
      case QuestClaimStatus.waitlisted:
        final at = claim.waitlistPosition == null
            ? ''
            : ' (#${claim.waitlistPosition})';
        return "On the waiting list$at. We'll tell you when one is held "
            'for you.';
      case QuestClaimStatus.soldOut:
        return 'All gone, sorry: they were first come, first served.';
      case QuestClaimStatus.collected:
        final at = claim.collectedAt;
        return at == null
            ? 'Collected ✓'
            : 'Collected ✓ ${questWhen(at, _now())}';
      case QuestClaimStatus.released:
        return '';
    }
  }

  List<Widget> _rewards(Quest quest) {
    final unlocked = quest.unlockedRewards;
    final locked = widget.compact
        ? const <QuestMilestone>[]
        : [
            for (final m in quest.milestones)
              if (!m.unlocked) m
          ];
    if (unlocked.isEmpty && locked.isEmpty) return const [];
    final p = _p;
    return [
      const SizedBox(height: 12),
      Text(unlocked.isEmpty ? 'Rewards' : 'Your rewards',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: p.ink)),
      for (final r in unlocked) _rewardRow(quest, r.reward, r.reward.claim!),
      for (final m in locked) _lockedRow(quest, m),
    ];
  }

  Widget _photo(QuestReward reward, {bool dim = false}) {
    final url = reward.photoUrl;
    final fallback = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _p.track,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(dim ? '🔒' : '🎁', style: const TextStyle(fontSize: 20)),
    );
    if (url == null) return fallback;
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AppNetworkImage(
          url: url,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (_) => fallback,
          placeholder: (_) => fallback,
        ),
      ),
    );
  }

  Widget _rewardRow(Quest quest, QuestReward reward, QuestClaim claim) {
    final p = _p;
    final id = quest.eventId;
    return Padding(
      key: QuestCard.rewardKey(reward.id),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          _photo(reward),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reward.name,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: p.ink)),
                Text(_claimLine(quest, claim),
                    style:
                        TextStyle(fontSize: 12.5, color: p.soft, height: 1.3)),
              ],
            ),
          ),
          if (claim.canPickSize)
            TextButton(
              key: QuestCard.sizeKey(reward.id),
              onPressed: () => showQuestSizeSheet(context,
                  eventId: id, reward: reward, claim: claim),
              style: TextButton.styleFrom(foregroundColor: p.ink),
              child: Text(claim.needsSize ? 'Pick size' : 'Change size'),
            ),
        ],
      ),
    );
  }

  Widget _lockedRow(Quest quest, QuestMilestone m) {
    final p = _p;
    final names = [for (final r in m.rewards) r.name];
    final soldOut = m.rewards.isNotEmpty && m.rewards.every((r) => r.soldOut);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          m.rewards.isEmpty
              ? _photo(const QuestReward(id: '', name: ''), dim: true)
              : _photo(m.rewards.first, dim: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.title,
                    style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: p.ink)),
                Text(
                  [
                    'At ${quest.units(m.threshold)}',
                    if (names.isNotEmpty) names.join(', '),
                    if (soldOut) 'sold out',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12.5, color: p.soft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _tasks(Quest quest) {
    final p = _p;
    var tasks = quest.tasks;
    var hidden = 0;
    if (widget.compact) {
      // What is left first, in the organiser's order; then what is done.
      final ordered = [
        ...tasks.where((t) => !t.done),
        ...tasks.where((t) => t.done),
      ];
      tasks = ordered.take(QuestCard.compactTasks).toList();
      hidden = ordered.length - tasks.length;
    }
    return [
      Text('Tasks',
          style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700, color: p.ink)),
      for (final task in tasks) _taskRow(quest, task),
      if (hidden > 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            hidden == 1 ? '1 more task' : '$hidden more tasks',
            style: TextStyle(fontSize: 12.5, color: p.soft),
          ),
        ),
    ];
  }

  Widget _taskRow(Quest quest, QuestTask task) {
    final p = _p;
    final line = _taskLine(quest, task);
    final label = _actionLabel(quest, task);
    final count = task.countLabel;
    final points = quest.mode == QuestMode.points && task.points > 0
        ? '${task.points} pts'
        : null;
    return Padding(
      key: QuestCard.taskKey(task.id),
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              task.done ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: task.done ? p.accent : p.soft,
              semanticLabel: task.done ? 'Done' : 'To do',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(task.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: task.done ? p.soft : p.ink,
                          )),
                    ),
                    if (task.required && !task.done) ...[
                      const SizedBox(width: 6),
                      Text('Required',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.accent)),
                    ],
                  ],
                ),
                if (line != null)
                  Text(line,
                      style: TextStyle(
                          fontSize: 12.5, color: p.soft, height: 1.3)),
                if (count != null && quest.takingPart && !task.done) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: task.count / task.target,
                            minHeight: 5,
                            backgroundColor: p.track,
                            color: p.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(count,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: p.ink)),
                    ],
                  ),
                ],
                if (label != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: OutlinedButton(
                      key: QuestCard.actionKey(task.id),
                      onPressed: () => _act(quest, task),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: p.ink,
                        side: BorderSide(color: p.ink.withAlpha(120)),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: Text(label),
                    ),
                  ),
              ],
            ),
          ),
          if (points != null)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 1),
              child: Text(points,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: task.done ? p.accent : p.soft)),
            ),
        ],
      ),
    );
  }

  List<Widget> _footer(Quest quest) {
    final p = _p;
    final code = quest.takesCodes && quest.takingPart && quest.open;
    final more = widget.compact;
    if (!code && !more) return const [];
    final router = GoRouter.maybeOf(context);
    return [
      const SizedBox(height: 12),
      Row(
        children: [
          if (code)
            Expanded(
              child: FilledButton.icon(
                key: QuestCard.codeKey,
                onPressed: () => _enterCode(quest.eventId),
                style: FilledButton.styleFrom(
                  backgroundColor: p.button,
                  foregroundColor: p.buttonInk,
                  minimumSize: const Size.fromHeight(42),
                ),
                icon: const Icon(Icons.pin_outlined, size: 18),
                label: const Text('Enter a code'),
              ),
            ),
          if (code && more) const SizedBox(width: 8),
          if (more && router != null)
            Expanded(
              child: OutlinedButton(
                key: QuestCard.openKey,
                onPressed: () => _refreshAfter(router.push(
                    questLocation(quest.eventId),
                    extra: {'eventName': widget.eventName})),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.ink,
                  side: BorderSide(color: p.ink.withAlpha(120)),
                  minimumSize: const Size.fromHeight(42),
                ),
                child: Text(quest.leaderboard
                    ? 'All tasks & leaderboard'
                    : 'All tasks & rewards'),
              ),
            ),
        ],
      ),
    ];
  }
}
