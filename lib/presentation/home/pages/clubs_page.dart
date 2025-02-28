import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/presentation/home/pages/clubs_page/explore_more_clubs_page.dart';
import 'package:myotherapp/presentation/home/widget/search_college_widget.dart';

import 'clubs_page/clubs_you_follow_section.dart';
import 'clubs_page/pinned_clubs_section.dart';

class ClubsPage extends StatefulWidget {
  ClubsPage({super.key});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class _ClubsPageState extends State<ClubsPage> {
  List<dynamic> pinnedClubs = [];
  List<dynamic> followingClubs = [];
  final List<String> colleges = [
    "College",
    "District",
    "State",
    "AI",
    "IOT",
    "Web",
    "Design",
    "Cyber Security",
    "App Development"
  ];

  bool isLoading = true;
  String? errorMessage;

  Future<void> _fetchData() async {
    try {
      // Fetch pinned clubs
      Response<dynamic> resPinned = await APIService.instance.request(
        '/clubs/list?is_pinned=true',
        DioMethod.get,
      );

      // Fetch clubs you follow
      Response<dynamic> resFollowing = await APIService.instance.request(
        '/clubs/list?is_following=true',
        DioMethod.get,
      );

      setState(() {
        pinnedClubs = resPinned.data['items'] ?? [];
        followingClubs = resFollowing.data['items'] ?? [];
        isLoading = false;
      });

      // Log the responses
      print("Pinned Clubs: $pinnedClubs");
      print("Following Clubs: $followingClubs");
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  final List<Map<String, String>> test = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text('Error: $errorMessage'))
              : Column(
                  children: [
                    SearchAndCollegeList(
                      colleges: colleges,
                    ),
                    // Show PinnedClubsSection only if there are pinned clubs.
                    if (pinnedClubs.isNotEmpty) ...[
                      PinnedClubsSection(
                        pinnedClubs: test,
                      ),
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Divider(height: 0, thickness: 1),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                                ?.copyWith(
                                    fontSize: 24, fontFamily: 'BebasNeue'),
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
                          clubs: test,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
