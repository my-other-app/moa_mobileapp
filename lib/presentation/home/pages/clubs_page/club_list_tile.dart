import 'package:flutter/material.dart';

class ClubListTile extends StatelessWidget {
  final String clubName;
  final String imageUrl;
  final void Function(String value) onMenuSelected;

  const ClubListTile({
    Key? key,
    required this.clubName,
    required this.imageUrl,
    required this.onMenuSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFC), // Slightly off-white
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E1E1E)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: NetworkImage(imageUrl),
        ),
        title: Text(clubName),
        trailing: PopupMenuButton<String>(
          onSelected: onMenuSelected,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'option1',
              child: Text('Option 1'),
            ),
            const PopupMenuItem(
              value: 'option2',
              child: Text('Option 2'),
            ),
          ],
          child: const Icon(Icons.more_vert),
        ),
      ),
    );
  }
}
