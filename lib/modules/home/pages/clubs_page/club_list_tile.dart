import 'package:flutter/material.dart';
import 'package:myotherapp/core/themes/app_colors.dart';
import 'package:myotherapp/features/clubs/presentation/pages/club_individual_page.dart';

import '../../custom_widgets/clubs_option_screen.dart';

class ClubListTile extends StatelessWidget {
  final int clubId;
  final String clubName;
  final String imageUrl;
  final String clubSlug;
  const ClubListTile({
    super.key,
    required this.clubName,
    required this.imageUrl,
    required this.clubSlug,
    required this.clubId,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ClubIndividualPage(
                    clubId: clubId,
                    clubSlug: clubSlug,
                    clubname: clubName,
                  )),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.only(left: 20, top: 8, right: 10, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFC), // Slightly off-white
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                imageUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
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
                    clubId: clubId,
                  );
                },
              ),
              icon: Icon(Icons.more_vert, color: Colors.black54),
            )
          ],
        ),
      ),
    );
  }
}
