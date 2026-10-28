import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:finnet/features/discover/domain/entities/discover_club.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/presentation/providers/paged_list.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_club_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart'
    show posterAspectRatio;
import 'package:finnet/shared/widgets/section_header.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/shared/widgets/poster_hero.dart';

export 'package:finnet/shared/widgets/section_header.dart' show SeeAllLink;

/// A titled block on a discover screen, with "See all" when there is more.
///
/// The title and "See all" sit on the gutter, 12 points over [child]; the
/// space under it ([padding]) keeps the sections on one rhythm.
class DiscoverSection extends StatelessWidget {
  const DiscoverSection({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllKey,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.only(bottom: sectionGap),
  });

  /// Between one section and the next.
  static const sectionGap = 32.0;

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final Key? seeAllKey;

  /// Beside the title, before "See all".
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionHeader(
            title: title,
            onSeeAll: onSeeAll,
            seeAllKey: seeAllKey,
            trailing: trailing,
            padding: const EdgeInsets.symmetric(horizontal: railGutter),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(railGutter, 2, railGutter, 0),
              child: Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B)),
              ),
            ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Left and right of a rail's first and last card.
const railGutter = 16.0;

/// Between cards in a rail.
const railSpacing = 12.0;

/// Events side by side, scrolled sideways: every card the same size.
class EventRail extends StatelessWidget {
  const EventRail({
    super.key,
    required this.events,
    this.limit = 10,
    this.heroScope,
  });

  final List<DiscoverEvent> events;
  final int limit;

  /// The rail's name among the screen's rails, for its posters to fly into
  /// the event's page; none without one.
  final String? heroScope;

  @override
  Widget build(BuildContext context) {
    final shown = events.take(limit).toList();
    final rail = SizedBox(
      height: DiscoverEventCard.heightFor(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: railGutter),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: railSpacing),
        itemBuilder: (_, i) => DiscoverEventCard(event: shown[i], index: i),
      ),
    );
    final scope = heroScope;
    return scope == null ? rail : PosterHeroScope(name: scope, child: rail);
  }
}

/// Clubs side by side, scrolled sideways: every card the same size.
class ClubRail extends StatelessWidget {
  const ClubRail({super.key, required this.clubs, this.limit = 8});

  final List<DiscoverClub> clubs;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final shown = clubs.take(limit).toList();
    return SizedBox(
      height: DiscoverClubCard.heightFor(context),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: railGutter),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: railSpacing),
        itemBuilder: (_, i) =>
            DiscoverClubCard(club: shown[i], width: DiscoverClubCard.railWidth),
      ),
    );
  }
}

/// A rail of event cards while it loads: the cards' own shapes, at their
/// size, under a bar where the title goes.
class RailSkeleton extends StatelessWidget {
  const RailSkeleton({super.key, this.clubs = false});

  /// Club cards rather than event cards.
  final bool clubs;

  @override
  Widget build(BuildContext context) {
    final height = clubs
        ? DiscoverClubCard.heightFor(context)
        : DiscoverEventCard.heightFor(context);
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: railGutter),
            child: ShimmerBox(height: 20, width: 160, borderRadius: 4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: railGutter),
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(width: railSpacing),
              itemBuilder: (_, __) => clubs
                  ? ShimmerBox(
                      height: height,
                      width: DiscoverClubCard.railWidth,
                      borderRadius: 10)
                  : const EventCardSkeleton(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rows of a list while its first page loads, shaped like the event rows.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 5, this.rowHeight});

  final int rows;

  /// Each row's height; an event row's by default.
  final double? rowHeight;

  @override
  Widget build(BuildContext context) {
    final height = rowHeight ??
        EventCardSlots.of(context, maxScale: tileMaxTextScale).content;
    final skeleton = Shimmer.fromColors(
      key: const ValueKey('discover-list-loading'),
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
              child: SizedBox(
                height: height,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ShimmerBox(
                        height: height,
                        // An event row's poster is 4:5 (DiscoverEventTile).
                        width: rowHeight == null
                            ? height * posterAspectRatio
                            : height),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ShimmerBox(height: 10, width: 110, borderRadius: 4),
                          ShimmerBox(height: 14, borderRadius: 4),
                          ShimmerBox(height: 14, width: 140, borderRadius: 4),
                          ShimmerBox(height: 10, width: 120, borderRadius: 4),
                          ShimmerBox(height: 10, width: 150, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    // Given a screen's height (a page that is loading), the rows past its
    // bottom are cut off rather than overflow it; in a list, all are drawn.
    return LayoutBuilder(
      builder: (context, box) => box.hasBoundedHeight
          ? ClipRect(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: skeleton,
              ),
            )
          : skeleton,
    );
  }
}

/// Nothing to show, said plainly, with a way on.
class DiscoverEmpty extends StatelessWidget {
  const DiscoverEmpty({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
    this.icon = Icons.event_busy_outlined,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              child: Text(actionLabel!),
            ),
          ],
          if (secondaryLabel != null && onSecondary != null)
            TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
        ],
      ),
    );
  }
}

/// The row under a list: asks for the next page as it comes into view (a
/// first page too short to scroll included), a retry when that failed, or
/// nothing at the end.
class PagedFooter extends StatefulWidget {
  const PagedFooter({
    super.key,
    required this.state,
    required this.onLoadMore,
    this.noun = 'events',
  });

  final PagedState<Object?, Object?> state;
  final VoidCallback onLoadMore;
  final String noun;

  @override
  State<PagedFooter> createState() => _PagedFooterState();
}

class _PagedFooterState extends State<PagedFooter> {
  @override
  void initState() {
    super.initState();
    _maybeLoadMore();
  }

  @override
  void didUpdateWidget(covariant PagedFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoadMore();
  }

  void _maybeLoadMore() {
    final s = widget.state;
    if (!s.hasMore || s.isLoadingMore || s.loadMoreError != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadMore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    if (s.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Text(
              "Couldn't load more ${widget.noun}",
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            TextButton(
              key: const ValueKey('discover-load-more-retry'),
              onPressed: widget.onLoadMore,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    if (!s.hasMore) return const SizedBox(height: 24);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
