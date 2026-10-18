import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/club_logo.dart';

class PinnedClubsSection extends StatelessWidget {
  final List<dynamic> pinnedClubs;
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                  context.push('/clubs/${club['id']}', extra: {
                    'clubSlug': club['slug'],
                    'clubName': club['name'],
                  });
                },
                child: Column(
                  children: [
                    // A club with no logo has `logo: null`; reading
                    // `club['logo']['thumbnail']` threw and took the whole
                    // clubs tab down with it.
                    ClubLogo(
                      url: imageUrlFrom(club['logo']),
                      size: 48,
                      circle: true,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 60, // limit the width so text can wrap/ellipsis
                      child: Text(
                        club['name'] ?? '',
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
