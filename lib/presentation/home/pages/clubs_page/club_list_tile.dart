import 'package:flutter/material.dart';
import 'package:myotherapp/core/themes/app_colors.dart';

import '../../widget/clubs_option_screen.dart';

class ClubListTile extends StatelessWidget {
  final String clubName;
  final String imageUrl;

  const ClubListTile({
    super.key,
    required this.clubName,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.only(left: 4, top: 8, right: 0, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFC), // Slightly off-white
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(imageUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              clubName,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          IconButton(
            onPressed: () => showModalBottomSheet(
              backgroundColor: Colors.white,
              context: context,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              builder: (_) {
                return ClubsOptionScreen(
                  clubName: clubName,
                  imageUrl: imageUrl,
                );
              },
            ),
            icon: Icon(Icons.more_vert, color: Colors.black54),
          )
        ],
      ),
    );
  }
}
