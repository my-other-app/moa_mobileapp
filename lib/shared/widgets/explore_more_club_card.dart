import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/api/api_helper.dart';

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
  late int _followersCount;

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
        context.push('/clubs/${widget.id}', extra: {
          'clubSlug': widget.clubSlug,
          'clubName': widget.name,
        });
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row with Logo, Club name, and Follower Count.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The club's logo; a placeholder when it has none.
                  ClubLogo(url: widget.logo, size: 40, radius: 0),
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
                        '$_followersCount Followers',
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
              // Follow/Unfollow, the full width. A "Join the Team" button
              // used to share the row with nothing behind it.
              SizedBox(
                width: double.infinity,
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
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowing;
    _followersCount = widget.followersCount;
  }

  //TODO: need to handle this toggle in a better way
  Future<void> _toggleFollow() async {
    final String endpoint;
    if (!_isFollowing) {
      endpoint = '/clubs/follow/${widget.id}';
    } else {
      endpoint = '/clubs/unfollow/${widget.id}';
    }

    if (widget.isFollowing != _isFollowing) {
      _followersCount = widget.followersCount;
    } else {
      _followersCount =
          _isFollowing ? widget.followersCount - 1 : widget.followersCount + 1;
    }

    try {
      Response<dynamic> res =
          await APIService.instance.request(endpoint, DioMethod.post);
      // Assuming the API returns a JSON with an "is_following" boolean field:
      setState(() {
        _isFollowing = res.data['is_following'] as bool;
        _followersCount;
      });
    } catch (e) {
      // Handle error (for example, show a SnackBar)
      debugPrint("Error toggling follow: $e");
    }
  }
}
