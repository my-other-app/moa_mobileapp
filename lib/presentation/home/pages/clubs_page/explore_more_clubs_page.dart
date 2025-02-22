import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/widget/explore_more_club_card.dart';

class ExploreMoreClubsPage extends StatelessWidget {
  const ExploreMoreClubsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        shadowColor: Colors.grey,
        surfaceTintColor: Colors.white,
        title: Padding(
          padding: EdgeInsetsDirectional.only(bottom: 8),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search for clubs or interests',
              hintStyle: textTheme.bodyMedium?.copyWith(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Color(0xFF979797)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1E1E1E), width: 0.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    const BorderSide(color: Color(0xFF1E1E1E), width: 0.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onChanged: (value) {
              // Handle search text changes
            },
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        separatorBuilder: (_, __) => SizedBox(height: 16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return ExploreMoreClubCard();
        },
      ),
    );
  }
}
