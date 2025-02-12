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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(6),
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
