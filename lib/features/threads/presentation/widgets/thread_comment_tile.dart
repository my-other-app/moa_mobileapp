import 'package:flutter/material.dart';
import 'package:finnet/core/themes/color_resources.dart';
import 'package:finnet/core/utils/time_ago.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';

/// One comment under a post: who wrote it (with a "Club" badge when it was
/// the club), when, and what they said -- and a delete button on your own.
class ThreadCommentTile extends StatelessWidget {
  final ThreadComment comment;

  /// The club's logo, used as the avatar on the club's own replies.
  final String? clubLogoUrl;

  /// Whether to offer the delete button: only on your own comments.
  final bool canDelete;

  /// A delete is in flight; the button becomes a spinner.
  final bool isDeleting;
  final VoidCallback? onDelete;

  const ThreadCommentTile({
    super.key,
    required this.comment,
    this.clubLogoUrl,
    this.canDelete = false,
    this.isDeleting = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ThreadClubAvatar(
          name: comment.authorName,
          logoUrl: comment.isClub ? clubLogoUrl : null,
          size: 36,
          circle: true,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Text(
                    comment.authorName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ThreadCard.ink,
                    ),
                  ),
                  if (comment.isClub) const _ClubBadge(),
                  Text(
                    timeAgo(comment.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                comment.body,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: ThreadCard.ink,
                ),
              ),
            ],
          ),
        ),
        if (canDelete)
          SizedBox(
            width: 40,
            height: 40,
            child: isDeleting
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    tooltip: 'Delete comment',
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: Colors.grey[700]),
                    onPressed: onDelete,
                  ),
          ),
      ],
    );
  }
}

class _ClubBadge extends StatelessWidget {
  const _ClubBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: ColorResources.buttonColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'Club',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}
