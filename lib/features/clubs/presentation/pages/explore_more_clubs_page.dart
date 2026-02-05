import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/shared/widgets/explore_more_club_card.dart';
import 'package:myotherapp/shared/widgets/search_college_widget.dart';
import 'package:myotherapp/shared/widgets/shimmer_widgets.dart';

class ExploreMoreClubsPage extends StatefulWidget {
  final int? initialOrganizationId;
  final List<int>? initialInterestIds;

  const ExploreMoreClubsPage({
    super.key,
    this.initialOrganizationId,
    this.initialInterestIds,
  });

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
              itemCount: 5,
              itemBuilder: (BuildContext context, int index) {
                return const ShimmerClubTile();
              },
              separatorBuilder: (_, __) => const SizedBox(height: 16),
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
      // Build query parameters with optional filters
      final Map<String, dynamic> params = {};

      if (widget.initialOrganizationId != null) {
        params['organization_id'] = widget.initialOrganizationId;
      }

      if (widget.initialInterestIds != null &&
          widget.initialInterestIds!.isNotEmpty) {
        params['interest_ids'] = widget.initialInterestIds!.join(',');
      }

      Response<dynamic> res = await APIService.instance.request(
        '/clubs/list',
        DioMethod.get,
        param: params.isNotEmpty ? params : null,
      );
      setState(() {
        clubs = res.data['items'] ?? [];
        debugPrint("Clubs: $clubs with filters: $params");
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
