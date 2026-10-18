import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/interest_tags.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';

/// An event's or a club's topics, as chips in their colours -- with its
/// interests beneath when [showInterests].
///
/// [declared] is the payload's own `topics`. Without it the topics are
/// worked out from [interests] against the cached catalogue; but not on a
/// server from before topics, whose one category holds everything, where
/// every event would read "Arts". Draws nothing when there is nothing to
/// show, so a page can always include it.
class TopicTagStrip extends ConsumerWidget {
  final List<Topic>? declared;
  final List<Interest> interests;
  final bool showInterests;
  final ValueChanged<Topic>? onTopicTap;

  /// Space above it, only when it draws anything.
  final double topGap;

  const TopicTagStrip({
    super.key,
    this.declared,
    this.interests = const [],
    this.showInterests = false,
    this.onTopicTap,
    this.topGap = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogue =
        ref.watch(topicCatalogueProvider).valueOrNull ?? const <Topic>[];
    final topics = declared != null || topicsWorthShowing(catalogue)
        ? resolveTopics(
            declared: declared, interests: interests, catalogue: catalogue)
        : const <Topic>[];
    final withInterests = showInterests && interests.isNotEmpty;
    if (topics.isEmpty && !withInterests) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: topGap),
      child: Column(
        key: const ValueKey('topic-tag-strip'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (topics.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final topic in topics)
                  TopicChip(
                    topic: topic,
                    onTap: onTopicTap == null ? null : () => onTopicTap!(topic),
                  ),
              ],
            ),
          if (topics.isNotEmpty && withInterests) const SizedBox(height: 8),
          if (withInterests) InterestTags(interests: interests),
        ],
      ),
    );
  }
}
