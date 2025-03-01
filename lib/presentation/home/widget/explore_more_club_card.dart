import 'dart:math';
import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/pages/club_individual_page.dart';
import '../../../core/themes/app_colors.dart';

class ExploreMoreClubCard extends StatelessWidget {
  final String name;
  final int followersCount;
  final String logo;
  final List<dynamic>
      intrests; // Each interest should be a string (or convertible to string)
  final int id;
  const ExploreMoreClubCard({
    super.key,
    required this.name,
    required this.followersCount,
    required this.logo,
    required this.intrests,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    // Define a list of colors to choose from randomly.
    final List<Color> colorList = [
      const Color(0xFFE1C9FF),
      const Color(0xFFF9FFA1),
      const Color(0xFFB8DFF2),
      const Color(0xFFFFC84A),
      const Color(0xFFE1C9FF),
    ];
    final Random random = Random();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ClubIndividualPage(
                    clubId: id,
                  )),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row with Logo, Title, and Follower Count.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo from variable.
                  Image.network(
                    (logo != null && logo.isNotEmpty)
                        ? logo
                        : 'https://picsum.photos/200',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),

                  const SizedBox(width: 12),
                  // Club name and followers.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$followersCount Followers',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Tags from the interests list with random colors.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: intrests.map((interest) {
                  // Select a random color from the color list.
                  final Color randomColor =
                      colorList[random.nextInt(colorList.length)];
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: randomColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      interest.toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Buttons.
              Row(
                children: [
                  // Left button.
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        // TODO: Implement "Join the Team" logic.
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2C333D),
                        side: const BorderSide(color: Color(0xFF2C333D)),
                      ),
                      child: const Text('JOIN THE TEAM'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right button.
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        // TODO: Implement "Follow" logic.
                      },
                      child: const Text(
                        'FOLLOW',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
