import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:finnet/features/discover/domain/entities/discover_club.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/presentation/providers/paged_list.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_club_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';

/// A titled block on a discover screen, with "See all" when there is more.
class DiscoverSection extends StatelessWidget {
  const DiscoverSection({
    super.key,
    required this.title,
    this.subtitle,
    this.onSeeAll,
    this.seeAllKey,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.only(bottom: 28),
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final Key? seeAllKey;

  /// Beside the title instead of "See all".
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 24,
                        fontFamily: 'BebasNeue',
                        color: Color(0xFF1E1E1E),
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
                if (onSeeAll != null) ...[
                  const SizedBox(width: 8),
                  SeeAllLink(key: seeAllKey, onTap: onSeeAll!),
                ],
              ],
            ),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
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

/// "See all", as Home's topic row has it.
class SeeAllLink extends StatelessWidget {
  const SeeAllLink({super.key, required this.onTap, this.label = 'See all'});

  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            label,
            style: const TextStyle(
              decoration: TextDecoration.underline,
              decorationColor: Colors.redAccent,
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// Events side by side, scrolled sideways.
class EventRail extends StatelessWidget {
  const EventRail({super.key, required this.events, this.limit = 10});

  final List<DiscoverEvent> events;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final shown = events.take(limit).toList();
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.6);
    return SizedBox(
      height: 140 + 160 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => Align(
          alignment: Alignment.topCenter,
          child: DiscoverEventCard(event: shown[i]),
        ),
      ),
    );
  }
}

/// Clubs side by side, scrolled sideways.
class ClubRail extends StatelessWidget {
  const ClubRail({super.key, required this.clubs, this.limit = 8});

  final List<DiscoverClub> clubs;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final shown = clubs.take(limit).toList();
    final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, 1.6);
    return SizedBox(
      height: 76 + 112 * scale,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: shown.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => Align(
          alignment: Alignment.topCenter,
          child: DiscoverClubCard(club: shown[i], width: 240),
        ),
      ),
    );
  }
}

/// A rail's shape while it loads.
class RailSkeleton extends StatelessWidget {
  const RailSkeleton({super.key, this.height = 260, this.width = 248});

  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) =>
              ShimmerBox(height: height, width: width, borderRadius: 10),
        ),
      ),
    );
  }
}

/// Rows of a list while its first page loads.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.rows = 5, this.rowHeight = 92});

  final int rows;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      key: const ValueKey('discover-list-loading'),
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: [
          for (var i = 0; i < rows; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  ShimmerBox(height: rowHeight, width: rowHeight),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(height: 12, width: 120),
                        SizedBox(height: 8),
                        ShimmerBox(height: 16),
                        SizedBox(height: 8),
                        ShimmerBox(height: 12, width: 160),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
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
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
