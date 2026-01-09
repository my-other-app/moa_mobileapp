import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/shared/widgets/search_college_widget.dart';
import 'package:myotherapp/shared/widgets/error_view.dart';
import 'package:myotherapp/shared/widgets/shimmer_widgets.dart';
import 'package:myotherapp/features/clubs/presentation/pages/no_clubs_following_page.dart';

import 'package:myotherapp/features/clubs/presentation/pages/clubs_you_follow_section.dart';
import 'package:myotherapp/features/clubs/presentation/pages/pinned_clubs_section.dart';

/// Clubs Page - exact same UI as original, using APIService for data.
class ClubsPage extends StatefulWidget {
  const ClubsPage({super.key});

  @override
  State<ClubsPage> createState() => _ClubsPageState();
}

/// Using ShimmerClubTile from shimmer_widgets.dart for consistency

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
          errorMessage = null;
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

  Future<void> _refresh() async {
    await _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shrinkWrap: true,
        itemCount: 15,
        itemBuilder: (BuildContext context, int index) {
          return const ShimmerClubTile();
        },
        separatorBuilder: (_, __) => const SizedBox(height: 36),
      );
    }

    if (errorMessage != null) {
      return ErrorView(
        message: errorMessage,
        onRetry: () {
          setState(() {
            isLoading = true;
            errorMessage = null;
          });
          _fetchData();
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
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
                      context.push('/clubs/explore');
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
                ? SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: NoClubsFollowingPage(),
                  )
                : ClubsYouFollowSection(clubs: followingClubs),
          ],
        ),
      ),
    );
  }
}
