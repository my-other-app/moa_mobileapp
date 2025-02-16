import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:myotherapp/common/views/custom_option_tile.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';

class ClubsOptionScreen extends StatelessWidget {
  final String clubName;
  final String imageUrl;
  const ClubsOptionScreen(
      {super.key, required this.clubName, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: NetworkImage(imageUrl),
              ),
              Text(
                clubName,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          Column(
            children: [
              CustomOptionTile(
                icon: SvgPicture.asset(
                  AssetResources.unfollow,
                ),
                title: const Text('Unfollow'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 0),
              CustomOptionTile(
                icon: SvgPicture.asset(
                  AssetResources.hideevents,
                ),
                title: const Text('Hide Events'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 0),
              CustomOptionTile(
                icon: SvgPicture.asset(
                  AssetResources.pinit,
                ),
                title: const Text('Pin It'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          )
        ],
      ),
    );
  }
}
