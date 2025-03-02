import 'package:flutter/material.dart';
import 'package:myotherapp/common/widgets/custom_option_tile.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';

class ClubsOptionScreen extends StatelessWidget {
  final String clubName;
  final String imageUrl;
  final int clubId;
  const ClubsOptionScreen({
    super.key,
    required this.clubName,
    required this.imageUrl,
    required this.clubId,
  });

  Future<void> _unfollowClub(BuildContext context) async {
    try {
      await APIService.instance.request(
        '/clubs/unfollow/$clubId',
        DioMethod.post,
      );
      // You can inspect res.data if needed.
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Optionally handle error
      print("Error unfollowing club: $e");
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _pinClub(BuildContext context) async {
    try {
      await APIService.instance.request(
        '/clubs/pin/$clubId',
        DioMethod.post,
      );
      // You can inspect res.data if needed.
      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      // Optionally handle error
      print("Error pinning club: $e");
      if (context.mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(imageUrl),
              ),
              const SizedBox(height: 8),
              Text(
                clubName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              CustomOptionTile(
                leadingImageName: AssetResources.unfollow,
                title: const Text('Unfollow'),
                onTap: () {
                  print("id on button $clubId");
                  _unfollowClub(context);
                },
              ),
              const Divider(height: 0),
              CustomOptionTile(
                leadingImageName: AssetResources.hideevents,
                title: const Text('Hide Events'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 0),
              CustomOptionTile(
                leadingImageName: AssetResources.pinit,
                title: const Text('Pin It'),
                onTap: () {
                  _pinClub(context);
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
