import 'package:flutter/material.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'club_list_tile.dart';

class ClubsYouFollowSection extends StatelessWidget {
  final List<dynamic> clubs;
  final VoidCallback? onActionCompleted;

  const ClubsYouFollowSection({
    super.key,
    required this.clubs,
    this.onActionCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // List of clubs (user follows)
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clubs.length,
          itemBuilder: (context, index) {
            final club = clubs[index];
            return ClubListTile(
              clubId: club['id'],
              clubName: club['name'] ?? 'name',
              imageUrl: imageUrlFrom(club['logo']) ?? '',
              clubSlug: club['slug'] ?? '',
              isPinned: club['is_pinned'] ?? false,
              isHidden: club['is_hidden'] ?? false,
              onActionCompleted: onActionCompleted,
            );
          },
        ),
      ],
    );
  }
}
