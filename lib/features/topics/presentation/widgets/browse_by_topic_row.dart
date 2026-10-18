import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';

/// "Browse by topic" on Home: a card per topic, with how many events are
/// coming up under it when the server counts, each opening Explore Events
/// on that topic.
///
/// Nothing while the topics load or if they fail -- it is a way in, not the
/// feed -- and nothing on a server with one topic holding everything.
class BrowseByTopicRow extends ConsumerWidget {
  /// Space below it, only when it draws anything.
  final double bottomGap;

  const BrowseByTopicRow({super.key, this.bottomGap = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicDirectoryProvider).valueOrNull;
    if (topics == null || !topicsWorthShowing(topics)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: _content(context, topics),
    );
  }

  Widget _content(BuildContext context, List<Topic> topics) {
    return Column(
      key: const ValueKey('browse-by-topic'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'BROWSE BY TOPIC',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 24,
                        fontFamily: 'BebasNeue',
                      ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: const ValueKey('browse-by-topic-all'),
              onTap: () => context.push('/events/explore'),
              child: const Text(
                'See all',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.redAccent,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          // Taller with larger text, so the name and count still fit.
          height: 72 + 40 * _textScale(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: topics.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _TopicCard(topic: topics[i]),
          ),
        ),
      ],
    );
  }
}

double _textScale(BuildContext context) =>
    (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 2.0);

class _TopicCard extends StatelessWidget {
  final Topic topic;

  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    final palette = TopicPalette.of(context, topic);
    final surface = TopicSurface.of(context);
    final count = topic.upcomingEvents;
    final countText = count == null || count <= 0
        ? null
        : '$count upcoming';

    return Semantics(
      container: true,
      button: true,
      label: [
        topic.label,
        if (countText != null) '$count upcoming events',
      ].join(', '),
      onTap: () => _open(context),
      excludeSemantics: true,
      child: Material(
        color: palette.tint,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('browse-topic-${topic.slug}'),
          onTap: () => _open(context),
          child: SizedBox(
            width: 136,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: palette.accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TopicIcon(
                            topic: topic, size: 22, color: palette.accent),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: palette.onTint,
                              ),
                            ),
                            if (countText != null)
                              Text(
                                countText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12, color: surface.muted),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) =>
      context.push('/events/explore', extra: {'topic': topic.slug});
}
