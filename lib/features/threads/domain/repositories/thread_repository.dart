import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';

/// Repository interface for club Threads: posts, polls, likes and comments.
abstract class ThreadRepository {
  /// One page of a club's posts, pinned first then newest.
  Future<Result<ThreadPage>> getClubThreads(
    int clubId, {
    int offset = 0,
    int limit = 20,
  });

  /// A club's first page of posts as last kept on this phone; null when
  /// none.
  Future<ThreadPage?> savedClubThreads(int clubId, {int limit = 20});

  /// Posts from the clubs this person follows, newest first: the first
  /// page, or the one after [after] (a page's `nextCursor`).
  Future<Result<ThreadPage>> getFollowingFeed({String? after, int limit = 20});

  /// The feed's first page as last kept on this phone; null when none.
  Future<ThreadPage?> savedFollowingFeed({int limit = 20});

  /// One post. A removed post fails with a [Failure] whose code is '404'.
  Future<Result<Thread>> getThread(String threadId);

  /// Like, or take the like back. Answers with where it settled.
  Future<Result<LikeResult>> toggleLike(String threadId);

  /// Vote on a poll; voting again moves the vote. Answers with the poll.
  Future<Result<Poll>> vote(String threadId, String optionId);

  /// The comments under a post, oldest first.
  Future<Result<List<ThreadComment>>> getComments(String threadId);

  /// Comment on a post.
  Future<Result<ThreadComment>> addComment(String threadId, String body);

  /// Remove one of your own comments.
  Future<Result<void>> deleteComment(String threadId, String commentId);
}
