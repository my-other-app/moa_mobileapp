import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../../../core/resources/asset_resources.dart';
import 'svg_icon.dart';

class ClubsOptionScreen extends StatelessWidget {
  final String clubName;
  final String imageUrl;
  const ClubsOptionScreen(
      {super.key, required this.clubName, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(imageUrl),
                ),
                const SizedBox(width: 16),
                Text(
                  clubName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFF3F3F3),
              child: SvgIcon(
                svgIconPath: AssetResources.unfollow,
              ),
            ),
            title: const Text('Unfollow',
                style: TextStyle(
                  fontSize: 16,
                )),
            onTap: () {
              // Handle action
              Navigator.pop(context);
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFF3F3F3),
              child: SvgPicture.asset(
                AssetResources.hideevents,
              ),
            ),
            title: const Text('Hide Events',
                style: TextStyle(
                  fontSize: 16,
                )),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFF3F3F3),
              child: SvgIcon(
                svgIconPath: AssetResources.pinit,
              ),
            ),
            title: const Text('Pin It',
                style: TextStyle(
                  fontSize: 16,
                )),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
