import 'package:flutter/material.dart';
import 'package:finnet/features/clubs/domain/club_summary.dart';
import 'club_list_tile.dart';

/// The clubs this person follows, as a sliver: each row is built as it
/// scrolls into view, in the clubs tab's own scroll. It was a shrink-wrapped
/// list inside a scroll view, which built every followed club, with its
/// logo, on open.
class ClubsYouFollowSection extends StatelessWidget {
  final List<ClubSummary> clubs;
  final VoidCallback? onActionCompleted;

  const ClubsYouFollowSection({
    super.key,
    required this.clubs,
    this.onActionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return SliverList.builder(
      itemCount: clubs.length,
      itemBuilder: (context, index) {
        final club = clubs[index];
        return ClubListTile(
          key: ValueKey('followed-club-${club.id}'),
          clubId: club.id,
          clubName: club.name.isEmpty ? 'name' : club.name,
          imageUrl: club.logoUrl ?? '',
          clubSlug: club.slug,
          isPinned: club.isPinned,
          isHidden: club.isHidden,
          onActionCompleted: onActionCompleted,
        );
      },
    );
  }
}
