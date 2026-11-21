import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart'
    show eventIdOf;
import 'package:finnet/features/quests/domain/quest.dart';
import 'package:finnet/features/quests/presentation/providers/quest_provider.dart';
import 'package:finnet/features/quests/presentation/widgets/quest_card.dart';

/// `/events/{ref}/quest`: the quest in full -- every task, every milestone
/// and its rewards, the code box -- and the leaderboard when the organiser
/// has it on. What an unlock push opens, and the card's "All tasks".
///
/// By the event's id (a push names it). A slug opens the event's page,
/// whose card comes here by id. The event's name is shown over the card:
/// the one passed (the card, an inbox line), else the event's public
/// page's (a push).
class QuestPage extends ConsumerWidget {
  const QuestPage({super.key, required this.eventRef, this.eventName});

  final String eventRef;
  final String? eventName;

  static const emptyKey = ValueKey('quest-page-empty');
  static const leaderboardKey = ValueKey('quest-leaderboard');
  static const refreshKey = ValueKey('quest-page-refresh');
  static const eventNameKey = ValueKey('quest-page-event-name');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = eventIdOf(eventRef);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: AppColors.ink,
        title: const Text('QUEST',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
        centerTitle: true,
      ),
      body: id == null ? _noId(context) : _body(context, ref, id),
    );
  }

  Widget _noId(BuildContext context) => _Empty(
        text: 'Open the event to see its quest.',
        action: 'Open the event',
        onTap: () => context.go('/events/${Uri.encodeComponent(eventRef)}'),
      );

  Widget _body(BuildContext context, WidgetRef ref, int id) {
    final state = ref.watch(questProvider(id));
    if (state.quest == null && state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.visible) {
      return _Empty(
        text: "This event doesn't have a quest running.",
        action: 'Open the event',
        onTap: () => context.go('/events/$id'),
      );
    }
    final quest = state.quest!;
    // Opened from a push, which names only the event's id: its name from
    // the event's public page.
    final name = eventName ?? ref.watch(questEventNameProvider(id)).valueOrNull;
    return RefreshIndicator(
      key: refreshKey,
      color: AppColors.ink,
      onRefresh: () async {
        ref.invalidate(questLeaderboardProvider(id));
        await ref.read(questProvider(id).notifier).refresh();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (name != null)
            Padding(
              key: eventNameKey,
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(name,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            ),
          QuestCard(eventId: id, eventName: name, compact: false),
          if (quest.leaderboard) _LeaderboardSection(eventId: id),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text, required this.action, required this.onTap});

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: QuestPage.emptyKey,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onTap, child: Text(action)),
          ],
        ),
      ),
    );
  }
}

/// The leaderboard: names as the organiser allows (first name and initial
/// by default), the viewer's own row marked.
class _LeaderboardSection extends ConsumerWidget {
  const _LeaderboardSection({required this.eventId});

  final int eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(questLeaderboardProvider(eventId));
    final data = board.valueOrNull;
    if (data == null || data.rows.isEmpty) {
      if (board.isLoading) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return const SizedBox.shrink();
    }
    final unit = data.mode == QuestMode.points ? 'pts' : 'tasks';
    return Container(
      key: QuestPage.leaderboardKey,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Leaderboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (final row in data.rows)
            _row(row.rank, row.me ? '${row.name} (you)' : row.name,
                '${row.score} $unit',
                me: row.me),
          if (data.meBelow) ...[
            const Divider(height: 16),
            _row(data.myRank!, 'You', '${data.myScore ?? 0} $unit', me: true),
          ],
        ],
      ),
    );
  }

  Widget _row(int rank, String name, String score, {bool me = false}) {
    final style = TextStyle(
        fontSize: 14, fontWeight: me ? FontWeight.w700 : FontWeight.w400);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: me
          ? BoxDecoration(
              color: const Color(0xFFFEFCE8),
              borderRadius: BorderRadius.circular(8))
          : null,
      child: Row(
        children: [
          SizedBox(width: 36, child: Text('#$rank', style: style)),
          Expanded(child: Text(name, style: style)),
          Text(score, style: style),
        ],
      ),
    );
  }
}
