import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/quests/presentation/providers/quest_provider.dart';
import 'package:finnet/shared/widgets/app_spinner.dart';

/// On the Network scanner opened at an event whose quest has a "meet
/// people" task: how far the guest has got ("3 of 5 met"), brought up to
/// date after each save -- the server counts a meeting a few seconds after
/// it. Nothing for any other event, or for someone not taking part.
class QuestScanProgress extends ConsumerWidget {
  const QuestScanProgress({super.key, required this.eventId});

  final int eventId;

  static const lineKey = ValueKey('quest-scan-progress');
  static const countingKey = ValueKey('quest-scan-counting');
  static const notCountedKey = ValueKey('quest-scan-not-counted');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The event's info says it has no quest on: nothing to ask for.
    final flag =
        ref.watch(questFlagsProvider.select((flags) => flags[eventId]));
    if (!(flag?.worthAsking() ?? true)) return const SizedBox.shrink();
    final state = ref.watch(questProvider(eventId));
    final quest = state.quest;
    final task = quest?.networkTask;
    if (!state.visible || quest == null || task == null || !quest.takingPart) {
      return const SizedBox.shrink();
    }
    final done = task.done;
    final text = done
        ? '${task.title}: done ✓'
        : '${task.title}: ${task.count} of ${task.target} met';
    return Container(
      key: lineKey,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(170),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF9FFA1).withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text('🎯', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ),
              if (state.counting)
                const SizedBox(
                  key: countingKey,
                  width: 14,
                  height: 14,
                  child: AppSpinner(
                      strokeWidth: 2, color: Color(0xFFF9FFA1)),
                ),
            ],
          ),
          if (!done) ...[
            const SizedBox(height: 6),
            AppProgressBar(
              value: task.count / task.target,
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
              backgroundColor: Colors.white24,
              color: const Color(0xFFB8FF9F),
            ),
          ],
          if (state.notCounted && !state.counting && !done) ...[
            const SizedBox(height: 6),
            const Text(
              "That one didn't add to your count. People count when you're "
              'both checked in here, met by scanning, a few a minute.',
              key: notCountedKey,
              style: TextStyle(color: Colors.white70, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}
