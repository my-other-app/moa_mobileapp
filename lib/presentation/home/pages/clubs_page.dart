import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/pages/clubs_page/explore_more_clubs_page.dart';

import 'clubs_page/clubs_you_follow_section.dart';
import 'clubs_page/pinned_clubs_section.dart';

class ClubsPage extends StatelessWidget {
  const ClubsPage({Key? key}) : super(key: key);

  // Example data for pinned clubs
  final List<Map<String, String>> pinnedClubs = const [
    {
      'name': 'IEDC CET',
      'imageUrl': 'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
    },
    {
      'name': 'IEEE CET',
      'imageUrl': 'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
    },
    {
      'name': 'TinkerHub CET',
      'imageUrl': 'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
    },
    {
      'name': 'Zenith',
      'imageUrl': 'https://via.placeholder.com/60?text=Zenith',
    },
    {
      'name': 'Robotics',
      'imageUrl': 'https://via.placeholder.com/60?text=Robotics',
    },
    {
      'name': 'IEDC CET',
      'imageUrl': 'https://via.placeholder.com/60?text=IEDC',
    },
    {
      'name': 'IEEE CET',
      'imageUrl': 'https://via.placeholder.com/60?text=IEEE',
    },
    {
      'name': 'TinkerHub CET',
      'imageUrl': 'https://via.placeholder.com/60?text=TinkerHub',
    },
    {
      'name': 'Zenith',
      'imageUrl': 'https://via.placeholder.com/60?text=Zenith',
    },
    {
      'name': 'Robotics',
      'imageUrl': 'https://via.placeholder.com/60?text=Robotics',
    },
  ];

  // Example data for the clubs you follow
  final List<Map<String, String>> clubsYouFollow = const [
    {
      'name': 'IEDC CET',
      'imageUrl': 'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
    },
    {
      'name': 'Dhwani',
      'imageUrl': 'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
    },
    {
      'name': 'IEEE CET Chapter',
      'imageUrl': 'https://via.placeholder.com/60?text=IEEE',
    },
    {
      'name': 'Tinkerhub CET',
      'imageUrl': 'https://via.placeholder.com/60?text=TinkerHub',
    },
    {
      'name': 'IEDC CET',
      'imageUrl': 'https://via.placeholder.com/60?text=IEDC',
    },
    {
      'name': 'Dhwani',
      'imageUrl': 'https://via.placeholder.com/60?text=Dhwani',
    },
    {
      'name': 'IEEE CET Chapter',
      'imageUrl': 'https://via.placeholder.com/60?text=IEEE',
    },
    {
      'name': 'Tinkerhub CET',
      'imageUrl': 'https://via.placeholder.com/60?text=TinkerHub',
    },
    {
      'name': 'IEDC CET',
      'imageUrl': 'https://via.placeholder.com/60?text=IEDC',
    },
    {
      'name': 'Dhwani',
      'imageUrl': 'https://via.placeholder.com/60?text=Dhwani',
    },
    {
      'name': 'IEEE CET Chapter',
      'imageUrl': 'https://via.placeholder.com/60?text=IEEE',
    },
    {
      'name': 'Tinkerhub CET',
      'imageUrl': 'https://via.placeholder.com/60?text=TinkerHub',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            // Handle search tap
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFC), // Slightly off-white
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E1E1E)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF979797)),
                const SizedBox(width: 8),
                const Text(
                  "Search for clubs or interests",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        centerTitle: true,
      ),
      // Use a Column so the pinned clubs stay at the top.
      body: Column(
        children: [
          // Pinned Clubs (fixed at top)
          PinnedClubsSection(
            pinnedClubs: pinnedClubs,
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CLUBS YOU FOLLOW',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ExploreMoreClubsPage(), // the screen to display
                      ),
                    );
                  },
                  child: const Text(
                    'Explore More Clubs',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),
          // Now only the "Clubs You Follow" section scrolls vertically
          Expanded(
            child: SingleChildScrollView(
              child: ClubsYouFollowSection(
                clubs: clubsYouFollow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
