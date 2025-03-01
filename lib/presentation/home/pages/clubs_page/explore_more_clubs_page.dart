import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/presentation/home/widget/explore_more_club_card.dart';
import 'package:myotherapp/presentation/home/widget/search_college_widget.dart';

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
        clubs = res.data['items'] ?? [];
        print("Clubs: $clubs");
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
          padding: const EdgeInsetsDirectional.only(bottom: 8),
          child: Text(
            "EXPLORE MORE",
            style: const TextStyle(
              fontSize: 24,
              fontFamily: "BebasNeue",
            ),
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text('Error: $errorMessage'))
              : clubs.isEmpty
                  ? const Center(
                      child: Text(
                        'Nothing to display',
                        style: TextStyle(fontSize: 18),
                      ),
                    )
                  : Column(
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
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 16),
                            itemCount: clubs.length,
                            itemBuilder: (context, index) {
                              final club = clubs[index];
                              return ExploreMoreClubCard(
                                name: club['name'] ?? '',
                                followersCount: club['followers_count'] ?? 0,
                                logo: club['logo'] != null &&
                                        club['logo'] is Map &&
                                        club['logo']['thumbnail'] != null
                                    ? club['logo']['thumbnail']
                                    : '',
                                intrests: club['interests'] != null
                                    ? (club['interests'] as List)
                                        .map((interest) =>
                                            interest['name'] ?? '')
                                        .toList()
                                    : [],
                                id: club['id'] ?? 0,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}
