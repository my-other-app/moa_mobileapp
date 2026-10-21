import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/providers/discover_providers.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_sections.dart';
import 'package:finnet/features/discover/presentation/widgets/filter_widgets.dart';
import 'package:finnet/features/home/presentation/widgets/at_event_banner.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:finnet/features/topics/presentation/widgets/browse_by_topic_row.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/shared/widgets/entrance.dart';
import 'package:finnet/shared/widgets/fade_switch.dart';
import 'package:finnet/shared/widgets/pressable.dart';
import 'package:shimmer/shimmer.dart';

/// Posts shown on the front page; the rest are in From the clubs.
const homeThreads = 3;

const _ink = Color(0xFF1E1E1E);
const _muted = Color(0xFF6B6B6B);

/// The DISCOVER tab: the website's front page, natively.
///
/// At the top, where the lists are about (placed by the person's
/// connection: the server says the city), what is on in numbers, and quick
/// ways into Find events. Then what is on near them, from the clubs they
/// follow when signed in, the topics as tiles, this week, the clubs near
/// them (or the most followed), online, popular, and the clubs' latest
/// posts. A rail with nothing in it is left out. Every card opens the app's
/// own event, club or post page. The saved copy is drawn first, and kept
/// when the server cannot be reached.
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

    // The skeleton gives way to the page with a cross-fade.
    if (data == null && home.isLoading) {
      return const FadeSwitch(
          phase: ScreenPhase.loading, child: _HomeSkeleton());
    }
    if (data == null) {
      return FadeSwitch(
        phase: ScreenPhase.error,
        child: ColoredBox(
          color: Colors.white,
          child: ErrorView(
            key: const ValueKey('discover-home-error'),
            message: switch (home.error) {
              Failure f => f.message,
              _ => "Couldn't load what's on.",
            },
            onRetry: () => ref.invalidate(discoverHomeProvider),
          ),
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
      // Checked in at an event that is on: its People Like You, first.
      const AtEventBanner(),
      _DiscoverTop(home: data),
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
          // The pill at the top names the place.
          title: 'Events near you',
          onSeeAll: () => context.push(findEventsLocation(const EventFilters(
              place: DiscoverPlace.near, sort: EventSort.distance))),
          child: EventRail(events: data.near, heroScope: 'near'),
        ),
      if (following.isNotEmpty)
        DiscoverSection(
          key: const ValueKey('rail-following'),
          title: 'From clubs you follow',
          onSeeAll: widget.onSeeFollowing,
          child: EventRail(events: following, heroScope: 'following'),
        ),
      // The topics, as tiles in their colours, after what is on nearby.
      const BrowseByTopicRow(
          gutter: railGutter, bottomGap: DiscoverSection.sectionGap),
      if (data.thisWeek.isNotEmpty)
        DiscoverSection(
          key: const ValueKey('rail-this-week'),
          title: 'This week',
          onSeeAll: () => context.push(
              findEventsLocation(const EventFilters(when: EventWhen.thisWeek))),
          child: EventRail(events: data.thisWeek, heroScope: 'this-week'),
        ),
      if (data.clubs.isNotEmpty)
        DiscoverSection(
          key: const ValueKey('rail-clubs'),
          title: data.clubsAreNear ? 'Clubs near you' : 'Popular clubs',
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
          child: EventRail(events: data.online, heroScope: 'online'),
        ),
      if (data.popular.isNotEmpty)
        DiscoverSection(
          key: const ValueKey('rail-popular'),
          title: 'Popular',
          onSeeAll: () => context.push(
              findEventsLocation(const EventFilters(sort: EventSort.popular))),
          child: EventRail(events: data.popular, heroScope: 'popular'),
        ),
      if (data.threads.isNotEmpty) _Threads(home: data),
      const SizedBox(height: 24),
    ];

    return FadeSwitch(
      phase: ScreenPhase.content,
      child: ColoredBox(
        color: Colors.white,
        child: RefreshIndicator(
          onRefresh: _refresh,
          // The sections come in one after another, the first time only.
          child: EntranceScope(
            child: ListView(
              key: const ValueKey('discover-home'),
              // Inside the header's NestedScrollView: the primary controller.
              primary: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 4),
              children: [
                for (final (i, section) in sections.indexed)
                  Entrance(index: i, child: section),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The top of the page: where the lists are about (a pill that changes
/// it), what is on in numbers, and quick ways into Find events.
class _DiscoverTop extends StatelessWidget {
  const _DiscoverTop({required this.home});

  final DiscoverHome home;

  @override
  Widget build(BuildContext context) {
    final stats = home.stats;
    final counts = [
      if (stats.upcomingEvents > 0)
        plural(stats.upcomingEvents, 'upcoming event'),
      if (stats.clubs > 0) plural(stats.clubs, 'club'),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: railGutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _WherePill(where: home.where),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: const Text(
                    "WHAT'S ON",
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 36,
                      height: 1,
                      letterSpacing: 0.4,
                      color: _ink,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  counts.isEmpty
                      ? 'Events, clubs and what they are up to'
                      : counts,
                  key: const ValueKey('discover-home-counts'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _QuickFilters(where: home.where),
        ],
      ),
    );
  }
}

/// "📍 Near Thiruvananthapuram ⌄": the place the server put the person in.
/// Tapped, it says how that was worked out and offers everywhere instead.
class _WherePill extends StatelessWidget {
  const _WherePill({required this.where});

  final DiscoverWhere where;

  @override
  Widget build(BuildContext context) {
    final label = where.isPlaced ? nearLabel(where) : 'Everywhere';
    return Semantics(
      button: true,
      label: '$label. Change',
      excludeSemantics: true,
      child: Pressable(
        child: Material(
          color: AppColors.paleYellow,
          shape: const StadiumBorder(
            side: BorderSide(color: AppColors.border, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const ValueKey('discover-home-where'),
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
              padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    where.isPlaced ? Icons.place : Icons.public,
                    size: 16,
                    color: _ink,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      key: const ValueKey('discover-home-place'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.expand_more, size: 18, color: _ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the quick ways into Find events.
class _Quick {
  const _Quick(this.id, this.label, this.icon, this.color, this.location);

  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String location;
}

/// Today, this weekend, free, online, near me and the calendar: each opens
/// Find events with that filter on. Near me only when the server could
/// place the person.
class _QuickFilters extends StatelessWidget {
  const _QuickFilters({required this.where});

  final DiscoverWhere where;

  static const _maxTextScale = 1.6;

  @override
  Widget build(BuildContext context) {
    final quick = [
      _Quick('today', 'Today', Icons.today_outlined, const Color(0xFFB4232C),
          findEventsLocation(const EventFilters(when: EventWhen.today))),
      _Quick(
          'weekend',
          'This weekend',
          Icons.weekend_outlined,
          const Color(0xFF7C3AED),
          findEventsLocation(const EventFilters(when: EventWhen.thisWeekend))),
      _Quick(
          'free',
          'Free',
          Icons.confirmation_number_outlined,
          const Color(0xFF17A58F),
          findEventsLocation(const EventFilters(price: EventPrice.free))),
      _Quick(
          'online',
          'Online',
          Icons.videocam_outlined,
          const Color(0xFF2563EB),
          findEventsLocation(const EventFilters(format: EventFormat.online))),
      if (where.isPlaced)
        _Quick(
            'near',
            'Near me',
            Icons.near_me_outlined,
            const Color(0xFFEA580C),
            findEventsLocation(const EventFilters(
                place: DiscoverPlace.near, sort: EventSort.distance))),
      _Quick('calendar', 'Calendar', Icons.calendar_month_outlined, _ink,
          findEventsLocation(EventFilters.none, calendar: true)),
    ];
    final scale =
        MediaQuery.textScalerOf(context).clamp(maxScaleFactor: _maxTextScale);
    final height = scale.scale(13) * 1.3 + 22;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: _maxTextScale,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          key: const ValueKey('discover-home-quick'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: railGutter),
          itemCount: quick.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) => _QuickChip(quick: quick[i]),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.quick});

  final _Quick quick;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: quick.label,
      excludeSemantics: true,
      onTap: () => context.push(quick.location),
      child: Pressable(
        scale: 0.94,
        child: Material(
          color: Colors.white,
          shape: const StadiumBorder(
            side: BorderSide(color: AppColors.border, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('discover-quick-${quick.id}'),
            onTap: () => context.push(quick.location),
            child: Padding(
              padding: const EdgeInsets.only(left: 5, right: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: quick.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(quick.icon, size: 16, color: quick.color),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    quick.label,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                ],
              ),
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

/// The page's shape while it loads: the top, the topics and two rails,
/// laid out as the page is.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('discover-home-loading'),
      color: Colors.white,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shimmer.fromColors(
              baseColor: Colors.grey.shade200,
              highlightColor: Colors.grey.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: railGutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(height: 32, width: 190, borderRadius: 16),
                        SizedBox(height: 14),
                        ShimmerBox(height: 34, width: 130, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerBox(height: 12, width: 180, borderRadius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.symmetric(horizontal: railGutter),
                      itemCount: 5,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => ShimmerBox(
                          height: 40,
                          width: i == 1 ? 132 : 92,
                          borderRadius: 20),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const RailSkeleton(),
            const SizedBox(height: DiscoverSection.sectionGap),
            const RailSkeleton(),
          ],
        ),
      ),
    );
  }
}
