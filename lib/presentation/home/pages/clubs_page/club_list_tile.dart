import 'package:flutter/material.dart';

import '../../widget/clubs_option_screen.dart';

class ClubListTile extends StatelessWidget {
  final String clubName;
  final String imageUrl;

  const ClubListTile({
    Key? key,
    required this.clubName,
    required this.imageUrl,
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
          title: Text(
            clubName,
            style: TextStyle(fontSize: 16),
          ),
          trailing: IconButton(
              onPressed: () => showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (_) {
                      return ClubsOptionScreen(
                        clubName: clubName,
                        imageUrl: imageUrl,
                      );
                    },
                  ),
              icon: Icon(Icons.more_vert))),
    );
  }
}
