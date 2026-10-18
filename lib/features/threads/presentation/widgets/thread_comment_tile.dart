import 'package:flutter/material.dart';
import 'package:finnet/core/themes/color_resources.dart';
import 'package:finnet/core/utils/time_ago.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';

/// One comment under a post: who wrote it (with a "Club" badge when it was
/// the club), when, and what they said -- a delete button on your own, and
/// on anyone else's a "…" menu to report it or block its author.
class ThreadCommentTile extends StatelessWidget {
  final ThreadComment comment;

  /// The club's logo, used as the avatar on the club's own replies.
  final String? clubLogoUrl;

  /// Whether to offer the delete button: only on your own comments.
  final bool canDelete;

  /// A delete is in flight; the button becomes a spinner.
  final bool isDeleting;
  final VoidCallback? onDelete;

  /// Report this comment. Offered in the "…" menu on others' comments.
  final VoidCallback? onReport;

  /// Block its author. Offered alongside report when the author is a person
  /// (not the club) -- the caller passes null otherwise.
  final VoidCallback? onBlock;

  const ThreadCommentTile({
    super.key,
    required this.comment,
    this.clubLogoUrl,
    this.canDelete = false,
    this.isDeleting = false,
    this.onDelete,
    this.onReport,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ThreadClubAvatar(
          name: comment.authorName,
          logoUrl: comment.isClub ? clubLogoUrl : comment.authorAvatarUrl,
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
          )
        // Never on your own comment: there is nothing to report or block.
        else if (onReport != null || onBlock != null)
          _CommentMenu(
            authorName: comment.authorName,
            onReport: onReport,
            onBlock: onBlock,
          ),
      ],
    );
  }
}

enum _CommentAction { report, block }

/// The "…" on someone else's comment.
class _CommentMenu extends StatelessWidget {
  final String authorName;
  final VoidCallback? onReport;
  final VoidCallback? onBlock;

  const _CommentMenu({
    required this.authorName,
    this.onReport,
    this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: PopupMenuButton<_CommentAction>(
        key: const ValueKey('comment-more'),
        tooltip: 'More options',
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_horiz, size: 20, color: Colors.grey[700]),
        color: Colors.white,
        onSelected: (action) {
          switch (action) {
            case _CommentAction.report:
              onReport?.call();
            case _CommentAction.block:
              onBlock?.call();
          }
        },
        itemBuilder: (_) => [
          if (onReport != null)
            const PopupMenuItem(
              value: _CommentAction.report,
              child: Text('Report comment'),
            ),
          if (onBlock != null)
            PopupMenuItem(
              value: _CommentAction.block,
              child: Text('Block $authorName'),
            ),
        ],
      ),
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
