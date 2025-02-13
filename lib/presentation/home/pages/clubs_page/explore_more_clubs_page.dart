import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/widget/explore_more_club_card.dart';

class ExploreMoreClubsPage extends StatelessWidget {
  const ExploreMoreClubsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: () {
            // Handle search tap
          },
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDFDFC), // Slightly off-white
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E1E1E)),
            ),
            child: Row(
              children: const [
                Icon(Icons.search, color: Color(0xFF979797)),
                SizedBox(width: 8),
                Text(
                  "Search for clubs or interests",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: const [
          ExploreMoreClubCard(),
          const Divider(height: 0),
          ExploreMoreClubCard(),
          const Divider(height: 0),
          ExploreMoreClubCard(),
          const Divider(height: 0),
        ],
      ),
    );
  }
}
