import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/widget/explore_more_club_card.dart';
import 'package:myotherapp/presentation/home/widget/search_college_widget';

class ExploreMoreClubsPage extends StatelessWidget {
  const ExploreMoreClubsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Padding(
            padding: EdgeInsetsDirectional.only(bottom: 8),
            child: Text(
              "EXPLORE MORE",
              style: TextStyle(
                fontSize: 24,
                fontFamily: "BebasNeue",
              ),
            )),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SearchAndCollegeList(
            colleges: [
              "yourcollege 1",
              "yourcollege 2",
              "yourcollege 3",
              "yourcollege 4",
              "yourcollege 5"
            ],
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              separatorBuilder: (_, __) => SizedBox(height: 16),
              itemCount: 3,
              itemBuilder: (context, index) {
                return ExploreMoreClubCard();
              },
            ),
          ),
        ],
      ),
    );
  }
}
