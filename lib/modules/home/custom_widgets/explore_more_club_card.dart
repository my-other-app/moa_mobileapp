import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/club_individual_page.dart';
import '../../../core/themes/app_colors.dart';

class ExploreMoreClubCard extends StatefulWidget {
  final String name;
  final int followersCount;
  final String logo;
  final List<dynamic> interests; // Each interest should be a string
  final int id;
  final String clubSlug;
  final bool isFollowing;
  const ExploreMoreClubCard({
    super.key,
    required this.name,
    required this.followersCount,
    required this.logo,
    required this.interests,
    required this.id,
    required this.clubSlug,
    required this.isFollowing,
  });

  @override
  State<ExploreMoreClubCard> createState() => _ExploreMoreClubCardState();
}

class _ExploreMoreClubCardState extends State<ExploreMoreClubCard> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
  }

  Future<void> _toggleFollow() async {
    final String endpoint;
    if (!_isFollowing) {
      endpoint = '/clubs/follow/${widget.id}';
    } else {
      endpoint = '/clubs/unfollow/${widget.id}';
    }
    try {
      Response<dynamic> res =
          await APIService.instance.request(endpoint, DioMethod.post);
      // Assuming the API returns a JSON with an "is_following" boolean field:
      setState(() {
        _isFollowing = res.data['is_following'] as bool;
      });
    } catch (e) {
      // Handle error (for example, show a SnackBar)
      debugPrint("Error toggling follow: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Define a list of colors for the interest tags.
    final List<Color> colorList = [
      const Color(0xFFE1C9FF),
      const Color(0xFFF9FFA1),
      const Color(0xFFB8DFF2),
      const Color(0xFFFFC84A),
      const Color(0xFFE1C9FF),
    ];

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ClubIndividualPage(
                    clubId: widget.id,
                    clubSlug: widget.clubSlug,
                    clubname: widget.name,
                  )),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row with Logo, Club name, and Follower Count.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Club logo with fallback.
                  Image.network(
                    (widget.logo.isNotEmpty)
                        ? widget.logo
                        : 'https://picsum.photos/200',
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.followersCount} Followers',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Interest tags: assign colors based on index to avoid repeats.
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.start,
                children: widget.interests.asMap().entries.map((entry) {
                  int index = entry.key;
                  final interest = entry.value;
                  final Color assignedColor =
                      colorList[index % colorList.length];
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: assignedColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      interest.toString(),
                      style: const TextStyle(fontSize: 14),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              // Buttons: "Join the Team" and Follow/Unfollow.
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        // TODO: Implement "Join the Team" logic.
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF2C333D),
                        side: const BorderSide(color: Color(0xFF2C333D)),
                      ),
                      child: const Text('JOIN THE TEAM'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _toggleFollow,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2C333D),
                      ),
                      child: Text(
                        _isFollowing ? 'UNFOLLOW' : 'FOLLOW',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
