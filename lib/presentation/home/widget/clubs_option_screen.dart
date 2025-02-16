import 'package:flutter/material.dart';

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
              _ClubOption(
                icon: const Icon(Icons.close, color: Colors.redAccent),
                title: const Text('Unfollow'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 0),
              _ClubOption(
                icon: const Icon(Icons.notifications_off),
                title: const Text('Hide Events'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              const Divider(height: 0),
              _ClubOption(
                icon: const Icon(Icons.push_pin),
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

class _ClubOption extends StatelessWidget {
  final Widget icon;
  final Widget title;
  final VoidCallback onTap;

  const _ClubOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Row(
          spacing: 16,
          children: [
            CircleAvatar(
              backgroundColor: Color(0xffF3F3F3),
              radius: 24,
              child: icon,
            ),
            title,
          ],
        ),
      ),
    );
  }
}
