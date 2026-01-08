import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/shared/widgets/explore_more_club_card.dart';
import 'package:myotherapp/shared/widgets/search_college_widget.dart';
import 'package:myotherapp/features/home/presentation/pages/home_page_tabs/for_you_events_page.dart';
import 'package:shimmer/shimmer.dart';

class ExploreClubCardShimmer extends StatelessWidget {
  const ExploreClubCardShimmer({super.key});

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
          crossAxisAlignment: CrossAxisAlignment.start,
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
            Wrap(
              alignment: WrapAlignment.start,
              spacing: 8,
              runSpacing: 8,
              runAlignment: WrapAlignment.start,
              children: List.generate(
                5,
                (index) => SimmerContainer(
                  height: 16,
                  width: 100,
                ),
              ),
            ),
            // Row(
            //   spacing: 12,
            //   children: [
            //     Expanded(
            //       child: SimmerContainer(
            //         height: 48,
            //         width: 100,
            //       ),
            //     ),
            //     Expanded(
            //       child: SimmerContainer(
            //         height: 48,
            //         width: 100,
            //       ),
            //     ),
            //   ],
            // )
          ],
        ),
      ),
    );
  }
}

class ExploreMoreClubsPage extends StatefulWidget {
  const ExploreMoreClubsPage({super.key});

  @override
  State<ExploreMoreClubsPage> createState() => _ExploreMoreClubsPageState();
}

class _ExploreMoreClubsPageState extends State<ExploreMoreClubsPage> {
  List<dynamic> clubs = [];
  bool isLoading = true;
  String? errorMessage;

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
          ? ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shrinkWrap: true,
              itemCount: 15,
              itemBuilder: (BuildContext context, int index) {
                return ExploreClubCardShimmer();
              },
              separatorBuilder: (_, __) => const SizedBox(height: 36),
            )
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
                                interests: club['interests'] != null
                                    ? (club['interests'] as List)
                                        .map((interest) =>
                                            interest['name'] ?? '')
                                        .toList()
                                    : [],
                                id: club['id'] ?? 0,
                                clubSlug: club['slug'] ?? '',
                                isFollowing: club['is_following'],
                              );
                            },
                          ),
                        ),
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
      Response<dynamic> res = await APIService.instance.request(
        '/clubs/list',
        DioMethod.get,
      );
      setState(() {
        clubs = res.data['items'] ?? [];
        debugPrint("Clubs: $clubs");
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }
}
