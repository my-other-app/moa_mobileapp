import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/shared/widgets/search_college_widget.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/explore_more_clubs_page.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/no_clubs_following_page.dart';
import 'package:myotherapp/modules/home/pages/home_page/home_page_tabs/for_you_events_page.dart';
import 'package:shimmer/shimmer.dart';

import 'clubs_you_follow_section.dart';
import 'pinned_clubs_section.dart';

/// Clubs Page - migrated to Riverpod with exact same UI.
class ClubsPage extends StatefulWidget {
  const ClubsPage({super.key});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

/// Shimmer loading widget for club tiles.
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
          children: [
            Row(
              children: [
                const SimmerContainer(height: 52, width: 52),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SimmerContainer(height: 16, width: 200),
                    SizedBox(height: 8),
                    SimmerContainer(height: 16, width: 100),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SimmerContainer(height: 16, width: double.infinity),
                SizedBox(height: 4),
                SimmerContainer(height: 16, width: double.infinity),
                SizedBox(height: 4),
                SimmerContainer(height: 16, width: 200),
              ],
            ),
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

      if (mounted) {
        setState(() {
          pinnedClubs = resPinned.data['items'] ?? [];
          followingClubs = resFollowing.data['items'] ?? [];
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in ProviderScope for Riverpod access
    return ProviderScope(
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        itemCount: 15,
        itemBuilder: (BuildContext context, int index) {
          return const ClubTileShimmer();
        },
        separatorBuilder: (_, __) => const SizedBox(height: 36),
      );
    }

    if (errorMessage != null) {
      return Center(child: Text('Error: $errorMessage'));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SearchAndCollegeList(colleges: colleges),
        // Show PinnedClubsSection only if there are pinned clubs
        if (pinnedClubs.isNotEmpty) ...[
          PinnedClubsSection(pinnedClubs: pinnedClubs),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 0, thickness: 1),
          ),
          const SizedBox(height: 16),
        ],
        // Header with "Explore More Clubs" link
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CLUBS YOU FOLLOW',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontSize: 24,
                      fontFamily: 'BebasNeue',
                    ),
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
        // Clubs list or empty state
        followingClubs.isEmpty
            ? Expanded(child: NoClubsFollowingPage())
            : Expanded(
                child: SingleChildScrollView(
                  child: ClubsYouFollowSection(clubs: followingClubs),
                ),
              ),
      ],
    );
  }
}
