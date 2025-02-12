import 'package:flutter/material.dart';

class PinnedClubsSection extends StatelessWidget {
  final List<Map<String, String>> pinnedClubs;
  const PinnedClubsSection({
    Key? key,
    required this.pinnedClubs,
  }) : super(key: key);

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
              return Column(
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
              );
            },
          ),
        ),
      ],
    );
  }
}
