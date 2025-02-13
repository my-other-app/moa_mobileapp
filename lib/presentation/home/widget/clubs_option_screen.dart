import 'package:flutter/material.dart';

class ClubsOptionScreen extends StatelessWidget {
  final String clubName;
  final String imageUrl;
  const ClubsOptionScreen(
      {super.key, required this.clubName, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Same content as before
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(imageUrl),
                ),
                const SizedBox(width: 16),
                Text(
                  clubName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // ... the rest of your ListTiles
          // Example actions
          ListTile(
            leading: const Icon(Icons.close, color: Colors.redAccent),
            title: const Text('Unfollow'),
            onTap: () {
              // Handle action
              Navigator.pop(context);
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.notifications_off),
            title: const Text('Hide Events'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.push_pin),
            title: const Text('Pin It'),
            onTap: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
