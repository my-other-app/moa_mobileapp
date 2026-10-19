import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_sections.dart';
import 'package:finnet/features/discover/presentation/widgets/filter_widgets.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:finnet/features/topics/presentation/widgets/browse_by_topic_row.dart';
import 'package:finnet/shared/widgets/error_view.dart';

/// Posts shown on the front page; the rest are in From the clubs.
const homeThreads = 3;

/// The DISCOVER tab: the website's front page, natively.
///
/// What is on near the person (placed by their connection: the server says
/// the city), this week, the clubs near them (or the most followed), online,
/// popular, from the clubs they follow when signed in, browse by topic, and
/// the clubs' latest posts. A rail with nothing in it is left out. Every
/// card opens the app's own event, club or post page. The saved copy is
/// drawn first, and kept when the server cannot be reached.
class DiscoverHomePage extends ConsumerStatefulWidget {
  const DiscoverHomePage({super.key, this.onSeeFollowing});

  /// "See all" on the followed clubs' rail: the FOLLOWING tab.
  final VoidCallback? onSeeFollowing;

  @override
  ConsumerState<DiscoverHomePage> createState() => _DiscoverHomePageState();
}

class _DiscoverHomePageState extends ConsumerState<DiscoverHomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Future<void> _refresh() async {
    ref.invalidate(discoverHomeProvider);
    ref.invalidate(followingRailProvider);
    try {
      await ref.read(discoverHomeProvider.future);
    } catch (_) {
      // The screen shows the failure.
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final home = ref.watch(discoverHomeProvider);
    final data = home.valueOrNull;

    if (data == null && home.isLoading) {
      return const _HomeSkeleton();
    }
    if (data == null) {
      return ColoredBox(
        color: Colors.white,
        child: ErrorView(
          key: const ValueKey('discover-home-error'),
          message: switch (home.error) {
            Failure f => f.message,
            _ => "Couldn't load what's on.",
          },
          onRetry: () => ref.invalidate(discoverHomeProvider),
        ),
      );
    }

    final signedIn = ref.watch(isAuthenticatedProvider);
    final following = signedIn
        ? (ref.watch(followingRailProvider).valueOrNull ??
            const <DiscoverEvent>[])
        : const <DiscoverEvent>[];
    final where = data.where;

    final sections = <Widget>[
      _WhereLine(where: where),
      if (data.isEmpty)
        DiscoverEmpty(
          key: const ValueKey('discover-home-empty'),
          title: "It's quiet out here",
          message: 'No events or clubs to show yet. Clubs add new events all '
              'the time — look further afield.',
          actionLabel: 'Browse all events',
          onAction: () => context.push(findEventsLocation(EventFilters.none)),
        ),
      if (data.near.isNotEmpty && where.isPlaced)
        DiscoverSection(
          key: const ValueKey('rail-near'),
          title: 'Events ${nearPhrase(where)}',
          onSeeAll: () => context.push(findEventsLocation(const EventFilters(
              place: DiscoverPlace.near, sort: EventSort.distance))),
          child: EventRail(events: data.near),
        ),
      if (following.isNotEmpty)
        DiscoverSection(
          key: const ValueKey('rail-following'),
          title: 'From clubs you follow',
          onSeeAll: widget.onSeeFollowing,
          child: EventRail(events: following),
        ),
      if (data.thisWeek.isNotEmpty)
        DiscoverSection(
          key: const ValueKey('rail-this-week'),
          title: 'This week',
          onSeeAll: () => context.push(
              findEventsLocation(const EventFilters(when: EventWhen.thisWeek))),
          child: EventRail(events: data.thisWeek),
        ),
      if (data.clubs.isNotEmpty)
        DiscoverSection(
          key: const ValueKey('rail-clubs'),
          title: data.clubsAreNear
              ? 'Clubs ${nearPhrase(where)}'
              : 'Popular clubs',
          onSeeAll: () => context.push(clubsDirectoryLocation(data.clubsAreNear
              ? const ClubFilters(
                  place: DiscoverPlace.near, sort: ClubSort.nearby)
              : ClubFilters.none)),
          child: ClubRail(clubs: data.clubs),
        ),
      if (data.online.isNotEmpty)
        DiscoverSection(
          key: const ValueKey('rail-online'),
          title: 'Online events',
          onSeeAll: () => context.push(findEventsLocation(
              const EventFilters(format: EventFormat.online))),
          child: EventRail(events: data.online),
        ),
      if (data.popular.isNotEmpty)
        DiscoverSection(
          key: const ValueKey('rail-popular'),
          title: 'Popular',
          onSeeAll: () => context.push(
              findEventsLocation(const EventFilters(sort: EventSort.popular))),
          child: EventRail(events: data.popular),
        ),
      // The existing row, opening the topic pages.
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: BrowseByTopicRow(bottomGap: 28),
      ),
      if (data.threads.isNotEmpty) _Threads(home: data),
      const SizedBox(height: 24),
    ];

    return ColoredBox(
      color: Colors.white,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const ValueKey('discover-home'),
          // Inside the header's NestedScrollView: the primary controller.
          primary: true,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 8),
          children: sections,
        ),
      ),
    );
  }
}

/// "Near Thiruvananthapuram · How we know": the place the server put the
/// person in, with what that means and a way to look everywhere instead.
class _WhereLine extends StatelessWidget {
  const _WhereLine({required this.where});

  final DiscoverWhere where;

  @override
  Widget build(BuildContext context) {
    final label = where.isPlaced ? nearLabel(where) : 'Everywhere';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Semantics(
        button: true,
        label: '$label. Change',
        excludeSemantics: true,
        child: InkWell(
          key: const ValueKey('discover-home-where'),
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final picked = await showWhereSheet(context,
                where: where,
                place: where.isPlaced
                    ? DiscoverPlace.near
                    : DiscoverPlace.everywhere);
            if (picked == null || !context.mounted) return;
            context.push(findEventsLocation(picked == DiscoverPlace.near
                ? const EventFilters(
                    place: DiscoverPlace.near, sort: EventSort.distance)
                : EventFilters.none));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.place_outlined,
                    size: 18, color: Color(0xFF1E1E1E)),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    key: const ValueKey('discover-home-place'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const Text(' · ', style: TextStyle(color: Colors.grey)),
                const Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The clubs' latest posts: the first few, each opening the post.
class _Threads extends StatelessWidget {
  const _Threads({required this.home});

  final DiscoverHome home;

  @override
  Widget build(BuildContext context) {
    return DiscoverSection(
      key: const ValueKey('rail-threads'),
      title: 'From the clubs',
      subtitle: 'The latest posts and polls from clubs on MyOtherApp',
      onSeeAll: () => context.push(threadsFeedPath),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            for (final t in home.threads.take(homeThreads))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                // Read here; liked, voted on and commented on in the post.
                child: ThreadCard(
                  key: ValueKey('home-thread-${t.id}'),
                  thread: t,
                  onTap: () => openDiscoverThread(context, t.id),
                  onClubTap: () => openDiscoverClub(context,
                      id: t.club.id, slug: t.club.slug, name: t.club.name),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: ValueKey('discover-home-loading'),
      color: Colors.white,
      child: SingleChildScrollView(
        physics: NeverScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 16),
        child: Column(
          children: [
            RailSkeleton(),
            SizedBox(height: 28),
            RailSkeleton(clubs: true),
            SizedBox(height: 28),
            RailSkeleton(),
          ],
        ),
      ),
    );
  }
}
