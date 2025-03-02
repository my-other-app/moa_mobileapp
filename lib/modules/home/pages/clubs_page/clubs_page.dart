import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/modules/home/custom_widgets/search_college_widget.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/explore_more_clubs_page.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/no_clubs_following_page.dart';
import 'package:myotherapp/modules/home/pages/home_page/home_page_tabs/for_you_events_page.dart';
import 'package:shimmer/shimmer.dart';

import 'clubs_you_follow_section.dart';
import 'pinned_clubs_section.dart';

class ClubsPage extends StatefulWidget {
  const ClubsPage({super.key});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

class ClubTileShimmer extends StatelessWidget {
  const ClubTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(16),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          spacing: 16,
          children: [
            Row(
              spacing: 16,
              children: [
                SimmerContainer(
                  height: 52,
                  width: 52,
                ),
                Column(
                  spacing: 8,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SimmerContainer(
                      height: 16,
                      width: 200,
                    ),
                    SimmerContainer(
                      height: 16,
                      width: 100,
                    ),
                  ],
                )
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                SimmerContainer(
                  height: 16,
                  width: double.infinity,
                ),
                SimmerContainer(
                  height: 16,
                  width: double.infinity,
                ),
                SimmerContainer(
                  height: 16,
                  width: 200,
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
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

  final List<Map<String, String>> test = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          // ? const Center(child: CircularProgressIndicator())
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              itemCount: 15,
              itemBuilder: (BuildContext context, int index) {
                return ClubTileShimmer();
              },
              separatorBuilder: (_, __) => const SizedBox(height: 36),
            )
          : errorMessage != null
              ? Center(child: Text('Error: $errorMessage'))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SearchAndCollegeList(
                      colleges: colleges,
                    ),
                    // Show PinnedClubsSection only if there are pinned clubs.
                    if (pinnedClubs.isNotEmpty) ...[
                      PinnedClubsSection(
                        pinnedClubs: pinnedClubs,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Divider(height: 0, thickness: 1),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // ...
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
                    // const SizedBox(height: 16),
                    followingClubs.isEmpty
                        ? Expanded(
                            child:
                                NoClubsFollowingPage()) // Show this widget if no clubs are followed.
                        : Expanded(
                            child: SingleChildScrollView(
                              child: ClubsYouFollowSection(
                                clubs: followingClubs,
                              ),
                            ),
                          ),
// ...
                  ],
                ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

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
      debugPrint("Pinned Clubs: $pinnedClubs");
      debugPrint("Following Clubs: $followingClubs");
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }
}
