import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/widgets/clubs_option_screen.dart';

class ClubListTile extends StatelessWidget {
  final int clubId;
  final String clubName;
  final String imageUrl;
  final String clubSlug;
  final bool isPinned;
  final bool isHidden;
  final VoidCallback? onActionCompleted;

  const ClubListTile({
    super.key,
    required this.clubName,
    required this.imageUrl,
    required this.clubSlug,
    required this.clubId,
    this.isPinned = false,
    this.isHidden = false,
    this.onActionCompleted,
  });

  void _showOptionsBottomSheet(BuildContext context) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      backgroundColor: Colors.white,
      context: context,
      // As tall as its options, not capped at 9/16 of the screen.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return ClubsOptionScreen(
          clubName: clubName,
          imageUrl: imageUrl,
          clubId: clubId,
          isPinned: isPinned,
          isHidden: isHidden,
        );
      },
    );

    // If action was successful, notify parent to refresh
    if (result != null &&
        result['success'] == true &&
        onActionCompleted != null) {
      onActionCompleted!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        context.push('/clubs/$clubId', extra: {
          'clubSlug': clubSlug,
          'clubName': clubName,
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.only(left: 20, top: 8, right: 10, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            // Whole when it is not square (a wordmark), on white.
            ClubLogo(
              url: imageUrl,
              size: 36,
              radius: 6,
              fallback: Container(
                width: 36,
                height: 36,
                color: Colors.grey[200],
                child: const Icon(Icons.group, size: 20),
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
              onPressed: () => _showOptionsBottomSheet(context),
              icon: const Icon(Icons.more_vert, color: Colors.black54),
            )
          ],
        ),
      ),
    );
  }
}
