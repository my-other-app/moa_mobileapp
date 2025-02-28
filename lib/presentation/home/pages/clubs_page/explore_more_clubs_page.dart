import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/widget/explore_more_club_card.dart';
import 'package:myotherapp/presentation/home/widget/search_college_widget.dart';

import '../../../../core/api/api_helper.dart';

class ExploreMoreClubsPage extends StatefulWidget {
  const ExploreMoreClubsPage({super.key});

  @override
  State<ExploreMoreClubsPage> createState() => _ExploreMoreClubsPageState();
}

class _ExploreMoreClubsPageState extends State<ExploreMoreClubsPage> {
  List<dynamic> clubs = [];
  bool isLoading = true;
  String? errorMessage;

  Future<void> _fetchData() async {
    try {
      Response<dynamic> res = await APIService.instance.request(
        '/clubs/list',
        DioMethod.get,
      );
      setState(() {
        // Adjust this based on your API response structure.
        // Here we assume events are under the key 'items'.
        clubs = res.data['items'] ?? [];
        print(clubs);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

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
