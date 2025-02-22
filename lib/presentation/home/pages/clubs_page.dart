import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/pages/clubs_page/explore_more_clubs_page.dart';
import 'package:myotherapp/presentation/home/widget/search_college_widget';

import 'clubs_page/clubs_you_follow_section.dart';
import 'clubs_page/pinned_clubs_section.dart';

class ClubsPage extends StatelessWidget {
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

  ClubsPage({super.key});
  final List<String> colleges = [
    "yourcollege 1",
    "yourcollege 2",
    "yourcollege 3",
    "yourcollege 4",
    "yourcollege 5"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          SearchAndCollegeList(
            colleges: colleges,
          ),
          PinnedClubsSection(
            pinnedClubs: pinnedClubs,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Divider(height: 0, thickness: 1),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CLUBS YOU FOLLOW',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 24, fontFamily: 'BebasNeue'),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExploreMoreClubsPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Explore More Clubs',
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.redAccent,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
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
