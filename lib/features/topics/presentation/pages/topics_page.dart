import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';

/// The counts under a topic: "12 upcoming events · 30 clubs"; null when
/// the server did not count.
String? topicCounts(Topic topic) {
  final parts = [
    if (topic.upcomingEvents != null)
      '${topic.upcomingEvents} upcoming ${topic.upcomingEvents == 1 ? 'event' : 'events'}',
    if (topic.clubs != null)
      '${topic.clubs} ${topic.clubs == 1 ? 'club' : 'clubs'}',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

/// Every topic as a card -- the website's `/topics`: find events and clubs
/// by what you're into, then narrow it by interest.
class TopicsPage extends ConsumerWidget {
  const TopicsPage({super.key});

  static const _interestsOnCard = 4;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicDirectoryProvider);

    Widget body;
    final list = topics.valueOrNull;
    if (list == null && topics.isLoading) {
      body = ShimmerList(
        itemCount: 6,
        padding: const EdgeInsets.all(16),
        separatorHeight: 12,
        itemBuilder: (_, __) => const ShimmerBox(height: 96),
      );
    } else if (list == null) {
      body = ErrorView(
        message: "Couldn't load the topics.",
        onRetry: () => ref.invalidate(topicDirectoryProvider),
      );
    } else if (list.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('NO TOPICS YET',
                  style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => context.push(findEventsPath),
                child: const Text('Find events'),
              ),
            ],
          ),
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.refresh(topicDirectoryProvider.future),
        child: ListView.separated(
          key: const ValueKey('topics-list'),
          padding: const EdgeInsets.all(16),
          itemCount: list.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Text(
                "Find events and clubs by what you're into: pick a topic, "
                'then narrow it down by interest.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              );
            }
            return _TopicCard(topic: list[i - 1]);
          },
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: const Text('TOPICS',
            style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue')),
      ),
      body: body,
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({required this.topic});

  final Topic topic;

  @override
  Widget build(BuildContext context) {
    final palette = TopicPalette.of(context, topic);
    final surface = TopicSurface.of(context);
    final counts = topicCounts(topic);
    final names =
        topic.interests.take(TopicsPage._interestsOnCard).map((i) => i.name);
    final more = topic.interests.length - names.length;
    final interests = [
      ...names,
      if (more > 0) '+$more more',
    ].join(' · ');
    void open() => context.push(topicLocation(topic.slug));

    return Semantics(
      container: true,
      button: true,
      label: [topic.label, if (counts != null) counts].join(', '),
      excludeSemantics: true,
      onTap: open,
      child: Material(
        color: palette.tint,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('topic-card-${topic.slug}'),
          onTap: open,
          child: Row(
            children: [
              Container(width: 5, height: 96, color: palette.accent),
              const SizedBox(width: 12),
              TopicIcon(topic: topic, size: 28, color: palette.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        topic.label,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: palette.onTint,
                        ),
                      ),
                      if ((topic.description ?? '').isNotEmpty)
                        Text(
                          topic.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: surface.ink),
                        ),
                      if (interests.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            interests,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(fontSize: 12, color: surface.muted),
                          ),
                        ),
                      if (counts != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            counts,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: palette.onTint,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.arrow_forward, color: palette.accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
