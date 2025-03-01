import 'package:flutter/material.dart';
import 'club_list_tile.dart';

class ClubsYouFollowSection extends StatelessWidget {
  final List<dynamic> clubs;

  const ClubsYouFollowSection({
    Key? key,
    required this.clubs,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header row with "CLUBS YOU FOLLOW" and "Explore More Clubs"

        // List of clubs (user follows)
        ListView.builder(
          shrinkWrap:
              true, // Let the SingleChildScrollView handle overall scrolling
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clubs.length,
          itemBuilder: (context, index) {
            final club = clubs[index];
            return ClubListTile(
              clubId: club['id'],
              clubName: club['name'] ?? 'name',
              imageUrl: club['logo']['thumbnail'] ?? '',
              clubSlug: club['slug'],
            );
          },
        ),
      ],
    );
  }
}
