import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/themes/color_resources.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/presentation/providers/moderation_provider.dart';
import 'package:finnet/features/threads/presentation/providers/threads_provider.dart';
import 'package:finnet/features/threads/presentation/widgets/moderation_actions.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_comment_tile.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_feedback.dart';
import 'package:finnet/shared/widgets/confirmation_dialog.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';

/// One club post with its comments -- `/threads/:threadId`.
///
/// Opened from a card on the club's page and from a `club_thread`
/// notification, push or in-app. The post may have been removed between the
/// notification and the tap; that is said plainly rather than shown as an
/// error.
class ThreadDetailPage extends ConsumerStatefulWidget {
  final String threadId;

  const ThreadDetailPage({super.key, required this.threadId});

  @override
  ConsumerState<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends ConsumerState<ThreadDetailPage> {
  final _composer = TextEditingController();

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  ThreadDetailNotifier get _notifier =>
      ref.read(threadDetailProvider(widget.threadId).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(threadDetailProvider(widget.threadId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'POST',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _body(state),
    );
  }

  Widget _body(ThreadDetailState state) {
    if (state.isRemoved) return const _RemovedPost();

    final thread = state.thread;
    if (thread == null) {
      if (state.error != null) {
        return ErrorView(message: state.error, onRetry: _notifier.load);
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: const [ShimmerThreadCard()],
      );
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: ThreadCard.ink,
            onRefresh: _notifier.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                ThreadCard(
                  thread: thread,
                  expanded: true,
                  onLike: _like,
                  onVote: _vote,
                  onClubTap: () => _openClub(thread),
                  onReport: () => reportContent(
                    context,
                    ref,
                    target: ReportTarget.thread(thread.id),
                    what: 'post',
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  thread.comments > 0
                      ? 'COMMENTS (${thread.comments})'
                      : 'COMMENTS',
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'BebasNeue',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                _comments(state, thread),
              ],
            ),
          ),
        ),
        _Composer(
          controller: _composer,
          isPosting: state.isPosting,
          onSend: _send,
        ),
      ],
    );
  }

  Widget _comments(ThreadDetailState state, Thread thread) {
    if (state.commentsLoading && state.comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: ThreadCard.ink,
            ),
          ),
        ),
      );
    }
    if (state.commentsError != null && state.comments.isEmpty) {
      return ErrorView(
        compact: true,
        message: state.commentsError,
        onRetry: _notifier.load,
      );
    }
    // Blocked people's comments go the moment the block is confirmed; the
    // refetch that follows has the server leave them out for good. The
    // club's own replies speak for the club and are never hidden here.
    final hidden = ref.watch(moderationProvider.select((s) => s.hiddenUserIds));
    final comments = state.comments
        .where((c) => c.isClub || !hidden.contains(c.authorId))
        .toList();

    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No comments yet. Start the conversation.',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      );
    }

    final viewerId = ref.watch(threadViewerIdProvider);
    return Column(
      children: [
        for (final comment in comments) ...[
          ThreadCommentTile(
            key: ValueKey('comment-${comment.id}'),
            comment: comment,
            clubLogoUrl: thread.club.logoUrl,
            canDelete: comment.isBy(viewerId),
            isDeleting: state.deleting.contains(comment.id),
            onDelete: () => _confirmDelete(comment),
            onReport: () => reportContent(
              context,
              ref,
              target: ReportTarget.comment(comment.id),
              what: 'comment',
            ),
            onBlock: comment.authorCanBeBlocked ? () => _block(comment) : null,
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }

  void _openClub(Thread thread) {
    if (thread.club.id <= 0) return;
    context.push('/clubs/${thread.club.id}', extra: {
      'clubSlug': thread.club.slug ?? '',
      'clubName': thread.club.name,
    });
  }

  Future<void> _like() async {
    final thread = ref.read(threadDetailProvider(widget.threadId)).thread;
    if (thread == null) return;
    if (!ensureSignedIn(context, ref, 'Sign in to like posts.')) return;
    final failure = await _notifier.toggleLike(thread.id);
    if (failure != null && mounted) showThreadFailure(context, ref, failure);
  }

  Future<void> _vote(String optionId) async {
    final thread = ref.read(threadDetailProvider(widget.threadId)).thread;
    if (thread == null) return;
    if (!ensureSignedIn(context, ref, 'Sign in to vote.')) return;
    final failure = await _notifier.vote(thread.id, optionId);
    if (failure != null && mounted) showThreadFailure(context, ref, failure);
  }

  Future<void> _send() async {
    if (!ensureSignedIn(context, ref, 'Sign in to comment.')) return;
    final failure = await _notifier.addComment(_composer.text);
    if (!mounted) return;
    if (failure != null) {
      showThreadFailure(context, ref, failure);
      return;
    }
    _composer.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _confirmDelete(ThreadComment comment) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ConfirmationDialog(
        title: 'DELETE COMMENT?',
        message: 'This removes your comment for everyone.',
        confirmText: 'DELETE',
        onConfirm: () {
          Navigator.of(dialogContext).pop();
          _delete(comment);
        },
        onCancel: () => Navigator.of(dialogContext).pop(),
      ),
    );
  }

  Future<void> _block(ThreadComment comment) async {
    final blocked = await confirmAndBlock(
      context,
      ref,
      userId: comment.authorId!,
      name: comment.authorName,
      avatarUrl: comment.authorAvatarUrl,
    );
    if (blocked && mounted) await _notifier.load();
  }

  Future<void> _delete(ThreadComment comment) async {
    final failure = await _notifier.deleteComment(comment.id);
    if (failure != null && mounted) showThreadFailure(context, ref, failure);
  }
}

/// The comment box pinned under the post.
///
/// Signed out, it is a button to sign in instead -- there is nothing to type
/// into that could be sent.
class _Composer extends ConsumerWidget {
  final TextEditingController controller;
  final bool isPosting;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.isPosting,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isAuthenticatedProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SafeArea(
        top: false,
        child: signedIn
            ? _field()
            : SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => showSignInPrompt(
                    context,
                    ref,
                    'Sign in to comment.',
                  ),
                  child: const Text('SIGN IN TO COMMENT'),
                ),
              ),
      ),
    );
  }

  Widget _field() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final canSend = value.text.trim().isNotEmpty && !isPosting;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('comment-field'),
                controller: controller,
                // Read-only rather than disabled while sending, so the
                // keyboard stays up if it fails and needs another go.
                readOnly: isPosting,
                minLines: 1,
                maxLines: 4,
                maxLength: maxCommentLength,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.newline,
                // The counter only once it matters, rather than "0/500"
                // under every empty box.
                buildCounter: (context,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    currentLength > maxCommentLength - 50
                        ? Text('$currentLength/$maxCommentLength')
                        : null,
                decoration: InputDecoration(
                  hintText: 'Add a comment…',
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: ThreadCard.ink),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: ThreadCard.ink),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: ThreadCard.ink, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: IconButton(
                key: const ValueKey('comment-send'),
                tooltip: 'Post comment',
                onPressed: canSend ? onSend : null,
                style: IconButton.styleFrom(
                  backgroundColor: ColorResources.buttonColor,
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: isPosting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 20),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The post was deleted by the club -- most often between a notification
/// arriving and someone tapping it.
class _RemovedPost extends StatelessWidget {
  const _RemovedPost();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.speaker_notes_off_outlined,
                size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'This post was removed',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontFamily: 'BebasNeue',
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'The club has taken it down.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/clubs');
                }
              },
              child: const Text('GO BACK'),
            ),
          ],
        ),
      ),
    );
  }
}
