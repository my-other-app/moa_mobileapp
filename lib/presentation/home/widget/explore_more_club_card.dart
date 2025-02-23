import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/pages/club_individual_page.dart';

import '../../../core/themes/app_colors.dart';

class ExploreMoreClubCard extends StatelessWidget {
  const ExploreMoreClubCard({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample tags with background colors
    final List<Map<String, dynamic>> tags = [
      {'label': 'Programming', 'color': Colors.lightBlue.shade100},
      {'label': 'App Development', 'color': Colors.yellow.shade200},
      {'label': 'UI/UX', 'color': Colors.red.shade100},
      {'label': 'Web Designing', 'color': Colors.green.shade100},
      {'label': 'AI/ML', 'color': Colors.amber.shade100},
      {'label': 'DSA', 'color': Colors.pink.shade100},
      {'label': 'Competitive Coding', 'color': Colors.purple.shade100},
    ];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ClubIndividualPage()),
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
              // Row with Logo, Title, and Follower Count
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  Image.network(
                    'https://avatars.githubusercontent.com/u/98015594?s=280&v=4', // Replace with TinkerHub logo
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 12),
                  // Club name and followers
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Tinkerhub CET',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '123 Followers',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tagItem) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tagItem['color'] as Color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tagItem['label'],
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  // Left button
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        // TODO: Implement "Join the Team" logic
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Color(0xFFFFFFFF),
                        foregroundColor: Color(0xFF2C333D),
                        side: BorderSide(color: Color(0xFF2C333D)),
                      ),
                      child: const Text('JOIN THE TEAM'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Right button
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        // TODO: Implement "Follow" logic
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
