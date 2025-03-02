import 'package:flutter/material.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/club_individual_page.dart';

class PinnedClubsSection extends StatelessWidget {
  final List<Map<String, String>> pinnedClubs;
  const PinnedClubsSection({
    super.key,
    required this.pinnedClubs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // "PINNED" heading
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PINNED',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 24, fontFamily: 'BebasNeue'),
            ),
          ),
        ),
        // Horizontally scrollable list of pinned clubs
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: pinnedClubs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final club = pinnedClubs[index];
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ClubIndividualPage(
                              clubId: 1,
                              clubname: '',
                              clubSlug: 's',
                            )),
                  );
                },
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: NetworkImage(club['imageUrl']!),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60, // limit the width so text can wrap/ellipsis
                      child: Text(
                        club['name']!,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
