import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_club_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_sections.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/presentation/pages/topics_page.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';

/// Clubs shown on a topic's page; the rest are in the clubs directory.
const topicPageClubs = 8;

/// A topic's page -- the website's `/topics/{slug}`: the topic, its
/// interests as chips (each narrowing the page), its upcoming events
/// everywhere, a page at a time, its first clubs, and the other topics.
class TopicPage extends ConsumerStatefulWidget {
  const TopicPage({super.key, required this.slug, this.interest});

  final String slug;

  /// One of the topic's interests to start narrowed to.
  final int? interest;

  @override
  ConsumerState<TopicPage> createState() => _TopicPageState();
}

class _TopicPageState extends ConsumerState<TopicPage> {
  late int? _interest = widget.interest;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(topicPageProvider(widget.slug));
    final topic = async.valueOrNull;

    Widget body;
    if (topic == null && async.isLoading) {
      body = const ShimmerList(
        itemCount: 4,
        padding: EdgeInsets.all(16),
        itemBuilder: _skeletonRow,
      );
    } else if (async.hasError && topic == null) {
      body = ErrorView(
        message: "Couldn't load this topic.",
        onRetry: () => ref.invalidate(topicPageProvider(widget.slug)),
      );
    } else if (topic == null) {
      body = DiscoverEmpty(
        key: const ValueKey('topic-missing'),
        icon: Icons.search_off,
        title: "We couldn't find that topic",
        message: 'The link may be old, or the topic may have a new name.',
        actionLabel: 'Find events',
        onAction: () => context.push(findEventsPath),
        secondaryLabel: 'Browse clubs',
        onSecondary: () => context.push(clubsDirectoryPath),
      );
    } else {
      // Only one of its own interests narrows it.
      final interest =
          topic.interests.where((i) => i.id == _interest).firstOrNull;
      body = _TopicBody(
        topic: topic,
        interestId: interest?.id,
        interestName: interest?.name,
        onInterest: (id) => setState(() => _interest = id),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        centerTitle: true,
        title: Text(
          (topic?.label ?? 'Topic').toUpperCase(),
          style: const TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
      ),
      body: body,
    );
  }
}

Widget _skeletonRow(BuildContext context, int index) =>
    const ShimmerBox(height: 92);

class _TopicBody extends ConsumerWidget {
  const _TopicBody({
    required this.topic,
    required this.interestId,
    required this.interestName,
    required this.onInterest,
  });

  final Topic topic;
  final int? interestId;
  final String? interestName;
  final ValueChanged<int?> onInterest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final what = interestName ?? topic.label;
    final eventFilters = EventFilters(topic: topic.slug, interest: interestId);
    final clubFilters = ClubFilters(topic: topic.slug, interest: interestId);
    final events = ref.watch(eventSearchProvider(eventFilters));
    final eventsNotifier = ref.read(eventSearchProvider(eventFilters).notifier);
    final clubs = ref.watch(clubSearchProvider(clubFilters));
    final others = (ref.watch(topicDirectoryProvider).valueOrNull ?? const [])
        .where((t) => t.slug != topic.slug)
        .toList();
    final palette = TopicPalette.of(context, topic);
    final counts = topicCounts(topic);

    Widget eventsBlock() {
      if (events.isLoading && events.items.isEmpty) {
        return const ListSkeleton(rows: 3);
      }
      if (events.error != null && events.items.isEmpty) {
        return ErrorView(
            compact: true, message: events.error, onRetry: eventsNotifier.load);
      }
      if (events.items.isEmpty) {
        return DiscoverEmpty(
          key: const ValueKey('topic-events-empty'),
          title: 'No upcoming $what events right now',
          message: "Clubs add new events all the time. Follow a club below to "
              "hear first, or see everything that's on.",
          actionLabel: 'Browse all events',
          onAction: () => context.push(findEventsPath),
          secondaryLabel: interestId == null ? null : 'All of ${topic.label}',
          onSecondary: interestId == null ? null : () => onInterest(null),
        );
      }
      return Column(
        children: [
          for (final e in events.items)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DiscoverEventTile(event: e),
            ),
          PagedFooter(state: events, onLoadMore: eventsNotifier.loadMore),
        ],
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(topicPageProvider(topic.slug));
        await eventsNotifier.refresh();
      },
      child: ListView(
        key: const ValueKey('topic-page'),
        children: [
          // The topic.
          Container(
            color: palette.tint,
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopicIcon(topic: topic, size: 44, color: palette.accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          topic.label,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: palette.onTint,
                          ),
                        ),
                      ),
                      if ((topic.description ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(topic.description!,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      if (counts != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            counts,
                            key: const ValueKey('topic-counts'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: palette.onTint,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Its interests.
          if (topic.interests.isNotEmpty)
            SizedBox(
              height: 52,
              child: ListView(
                key: const ValueKey('topic-interest-chips'),
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  InterestChip(
                    key: const ValueKey('topic-interest-all'),
                    label: 'All',
                    compact: true,
                    selected: interestId == null,
                    onTap: () => onInterest(null),
                  ),
                  for (final i in topic.interests) ...[
                    const SizedBox(width: 8),
                    InterestChip(
                      key: ValueKey('topic-interest-${i.id}'),
                      label: i.name,
                      glyph: i.emoji,
                      compact: true,
                      count: i.upcomingEvents,
                      topicLabel: topic.label,
                      selected: interestId == i.id,
                      onTap: () => onInterest(interestId == i.id ? null : i.id),
                    ),
                  ],
                ],
              ),
            ),
          // Its events.
          DiscoverSection(
            title: 'Upcoming $what events',
            padding: const EdgeInsets.only(top: 12, bottom: 12),
            trailing: events.items.isEmpty
                ? null
                : Text(
                    plural(events.total, 'event'),
                    key: const ValueKey('topic-events-count'),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
            onSeeAll: events.items.isEmpty
                ? null
                : () => context.push(findEventsLocation(eventFilters)),
            child: eventsBlock(),
          ),
          // Its clubs.
          if (clubs.items.isNotEmpty)
            DiscoverSection(
              title: '$what clubs',
              subtitle: 'Clubs into $what on MyOtherApp',
              onSeeAll: () => context.push(clubsDirectoryLocation(clubFilters)),
              seeAllKey: const ValueKey('topic-clubs-all'),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  key: const ValueKey('topic-clubs'),
                  children: [
                    for (final c in clubs.items.take(topicPageClubs))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DiscoverClubCard(club: c),
                      ),
                  ],
                ),
              ),
            ),
          // The other topics.
          if (others.isNotEmpty)
            DiscoverSection(
              title: 'More topics',
              onSeeAll: () => context.push(topicsPath),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in others)
                      TopicChip(
                        topic: t,
                        onTap: () => context.push(topicLocation(t.slug)),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
