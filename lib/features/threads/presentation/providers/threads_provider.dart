import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';

/// Posts per page -- the server's own default for `limit`.
const threadsPageSize = 20;

/// The longest comment the server accepts (`CommentCreate.body`).
const maxCommentLength = 500;

/// The signed-in person's user id, for "is this my comment".
///
/// From the profile, which loads itself on first read. Null until it has, or
/// when signed out -- either way no delete button is offered. Signed out,
/// the profile is not even asked for: reading a club's posts must not cost
/// a refused `/user/profile/me`.
final threadViewerIdProvider = Provider<int?>((ref) {
  if (!ref.watch(isAuthenticatedProvider)) return null;
  final id = int.tryParse(ref.watch(profileProvider).profile?.id ?? '');
  return (id == null || id <= 0) ? null : id;
});

/// Like and vote, shared by the club's list and the single-post page.
///
/// Both are optimistic: the post changes the moment it is tapped, then
/// settles on what the server answers -- not on the guess, which is wrong
/// exactly when the local copy was stale (a like from another device, a vote
/// moved elsewhere). A failure puts back what was there before.
///
/// One request per post per action at a time: a second tap while the first
/// is in flight is ignored rather than racing it.
mixin ThreadInteractions<S> on StateNotifier<S> {
  ThreadRepository get repository;

  /// The post with [threadId] as this notifier currently holds it.
  Thread? findThread(String threadId);

  /// Replace the held copy of [thread] (matched by id).
  void putThread(Thread thread);

  final Set<String> _inFlight = {};

  /// Toggle this person's like. Answers with the failure, if there was one.
  Future<Failure?> toggleLike(String threadId) async {
    final before = findThread(threadId);
    final key = 'like:$threadId';
    if (before == null || !_inFlight.add(key)) return null;

    putThread(before.withLikeToggled());
    final result = await repository.toggleLike(threadId);
    _inFlight.remove(key);
    if (!mounted) return null;

    final now = findThread(threadId);
    return result.fold(
      (failure) {
        if (now != null) {
          putThread(now.copyWith(liked: before.liked, likes: before.likes));
        }
        return failure;
      },
      (settled) {
        if (now != null) {
          putThread(now.copyWith(liked: settled.liked, likes: settled.likes));
        }
        return null;
      },
    );
  }

  /// Vote for [optionId]; voting again moves the vote. Answers with the
  /// failure, if there was one.
  Future<Failure?> vote(String threadId, String optionId) async {
    final before = findThread(threadId);
    final poll = before?.poll;
    final key = 'vote:$threadId';
    if (before == null || poll == null) return null;
    // Re-tapping the current choice changes nothing, so asks nothing.
    if (poll.votedOptionId == optionId || !_inFlight.add(key)) return null;

    putThread(before.copyWith(poll: poll.withVote(optionId)));
    final result = await repository.vote(threadId, optionId);
    _inFlight.remove(key);
    if (!mounted) return null;

    final now = findThread(threadId);
    return result.fold(
      (failure) {
        if (now != null) putThread(now.copyWith(poll: poll));
        return failure;
      },
      (settled) {
        if (now != null) putThread(now.copyWith(poll: settled));
        return null;
      },
    );
  }
}

// --- A club's posts -----------------------------------------------------------

/// State for a club's THREADS tab.
class ClubThreadsState {
  final List<Thread> threads;
  final bool isLoading;
  final bool isLoadingMore;

  /// Why the first page failed. Shown in place of the list.
  final String? error;

  /// Why a later page failed. Shown under the list, with a retry.
  final String? loadMoreError;
  final bool hasMore;

  /// Where the next page starts. Kept apart from `threads.length` because a
  /// page can repeat posts already shown (a new post shifts everything down
  /// one) and those are dropped -- counting the list would then ask for the
  /// same page again, forever.
  final int nextOffset;

  const ClubThreadsState({
    this.threads = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.hasMore = false,
    this.nextOffset = 0,
  });

  ClubThreadsState copyWith({
    List<Thread>? threads,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? loadMoreError,
    bool clearLoadMoreError = false,
    bool? hasMore,
    int? nextOffset,
  }) {
    return ClubThreadsState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
      hasMore: hasMore ?? this.hasMore,
      nextOffset: nextOffset ?? this.nextOffset,
    );
  }
}

/// A club's posts, pinned first then newest, loaded on first read.
///
/// Auto-disposed with the club page, so opening the club again shows what
/// it has posted since rather than a cached list.
final clubThreadsProvider = StateNotifierProvider.autoDispose
    .family<ClubThreadsNotifier, ClubThreadsState, int>((ref, clubId) {
  return ClubThreadsNotifier(ref.watch(threadRepositoryProvider), clubId);
});

/// Notifier for a club's posts: paging, refresh, likes and votes.
class ClubThreadsNotifier extends StateNotifier<ClubThreadsState>
    with ThreadInteractions<ClubThreadsState> {
  ClubThreadsNotifier(this.repository, this.clubId)
      : super(const ClubThreadsState(isLoading: true)) {
    load();
  }

  @override
  final ThreadRepository repository;
  final int clubId;

  ClubThreadsState _firstPage(ThreadPage page) => ClubThreadsState(
        threads: page.items,
        hasMore: page.hasMore,
        nextOffset: page.offset + page.items.length,
      );

  /// Load the first page, replacing whatever was there.
  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result =
        await repository.getClubThreads(clubId, limit: threadsPageSize);
    if (!mounted) return;
    result.fold(
      (failure) =>
          state = state.copyWith(isLoading: false, error: failure.message),
      (page) => state = _firstPage(page),
    );
  }

  /// Pull to refresh. Keeps the posts on screen until the new ones arrive,
  /// and answers with the failure message, if any, for a snackbar -- a
  /// failed refresh should not blank a list that was fine.
  Future<String?> refresh() async {
    if (state.threads.isEmpty) {
      await load();
      return null;
    }
    final result =
        await repository.getClubThreads(clubId, limit: threadsPageSize);
    if (!mounted) return null;
    return result.fold(
      (failure) => failure.message,
      (page) {
        state = _firstPage(page);
        return null;
      },
    );
  }

  /// Load the next page, if there is one and nothing is loading.
  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);

    final result = await repository.getClubThreads(
      clubId,
      offset: state.nextOffset,
      limit: threadsPageSize,
    );
    if (!mounted) return;
    result.fold(
      (failure) => state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: failure.message,
      ),
      (page) {
        final seen = {for (final t in state.threads) t.id};
        state = state.copyWith(
          isLoadingMore: false,
          threads: [
            ...state.threads,
            ...page.items.where((t) => seen.add(t.id)),
          ],
          hasMore: page.hasMore,
          nextOffset: page.offset + page.items.length,
        );
      },
    );
  }

  /// Take in a post changed elsewhere -- liked or commented on from its own
  /// page -- so the list does not show it as it was.
  void upsert(Thread thread) => putThread(thread);

  /// Drop a post the server says is gone.
  void remove(String threadId) {
    if (!state.threads.any((t) => t.id == threadId)) return;
    state = state.copyWith(
      threads: state.threads.where((t) => t.id != threadId).toList(),
    );
  }

  @override
  Thread? findThread(String threadId) {
    for (final t in state.threads) {
      if (t.id == threadId) return t;
    }
    return null;
  }

  @override
  void putThread(Thread thread) {
    final index = state.threads.indexWhere((t) => t.id == thread.id);
    if (index == -1) return;
    final threads = List<Thread>.of(state.threads)..[index] = thread;
    state = state.copyWith(threads: threads);
  }
}

// --- One post -----------------------------------------------------------------

/// State for a post's own page: the post, then its comments.
class ThreadDetailState {
  final Thread? thread;
  final bool isLoading;

  /// Why the post could not be loaded (other than being removed).
  final String? error;

  /// The server answered 404: the club deleted it.
  final bool isRemoved;

  final List<ThreadComment> comments;
  final bool commentsLoading;
  final String? commentsError;

  /// A comment is on its way.
  final bool isPosting;

  /// Comments with a delete in flight.
  final Set<String> deleting;

  const ThreadDetailState({
    this.thread,
    this.isLoading = false,
    this.error,
    this.isRemoved = false,
    this.comments = const [],
    this.commentsLoading = false,
    this.commentsError,
    this.isPosting = false,
    this.deleting = const {},
  });

  ThreadDetailState copyWith({
    Thread? thread,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool? isRemoved,
    List<ThreadComment>? comments,
    bool? commentsLoading,
    String? commentsError,
    bool clearCommentsError = false,
    bool? isPosting,
    Set<String>? deleting,
  }) {
    return ThreadDetailState(
      thread: thread ?? this.thread,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isRemoved: isRemoved ?? this.isRemoved,
      comments: comments ?? this.comments,
      commentsLoading: commentsLoading ?? this.commentsLoading,
      commentsError:
          clearCommentsError ? null : (commentsError ?? this.commentsError),
      isPosting: isPosting ?? this.isPosting,
      deleting: deleting ?? this.deleting,
    );
  }
}

/// One post and its comments, by id -- what a card tap and a tapped
/// notification open. Loaded on first read.
final threadDetailProvider = StateNotifierProvider.autoDispose
    .family<ThreadDetailNotifier, ThreadDetailState, String>((ref, threadId) {
  return ThreadDetailNotifier(
    ref,
    ref.watch(threadRepositoryProvider),
    threadId,
  );
});

/// Notifier for a post's page: the post, its comments, and what a reader
/// can do there.
class ThreadDetailNotifier extends StateNotifier<ThreadDetailState>
    with ThreadInteractions<ThreadDetailState> {
  ThreadDetailNotifier(this._ref, this.repository, this.threadId)
      : super(const ThreadDetailState(isLoading: true, commentsLoading: true)) {
    load();
  }

  final Ref _ref;
  @override
  final ThreadRepository repository;
  final String threadId;

  /// Load (or reload) the post and its comments together.
  ///
  /// A reload keeps the post on screen while it runs; only the first load
  /// shows a skeleton.
  Future<void> load() async {
    state = state.copyWith(
      isLoading: state.thread == null,
      clearError: true,
      commentsLoading: true,
      clearCommentsError: true,
    );

    final threadCall = repository.getThread(threadId);
    final commentsCall = repository.getComments(threadId);
    final threadResult = await threadCall;
    final commentsResult = await commentsCall;
    if (!mounted) return;

    final removed = threadResult.fold(
      (failure) => failure.code == '404',
      (_) => false,
    );
    if (removed) {
      _markRemoved();
      return;
    }

    threadResult.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        // Kept quiet when a post is already showing: a failed refresh is not
        // a reason to replace it with an error screen.
        error: state.thread == null ? failure.message : null,
      ),
      (thread) {
        state = state.copyWith(isLoading: false, thread: thread);
        _syncToList(thread);
      },
    );
    commentsResult.fold(
      (failure) => state = state.copyWith(
        commentsLoading: false,
        commentsError: failure.message,
      ),
      (comments) =>
          state = state.copyWith(commentsLoading: false, comments: comments),
    );
  }

  /// Post a comment. Answers with the failure, if there was one; the text
  /// is checked here first so an empty or over-long one never leaves.
  Future<Failure?> addComment(String text) async {
    final body = text.trim();
    if (body.isEmpty) {
      return const ValidationFailure(message: 'Write something first.');
    }
    // Code points, as the server counts them, not UTF-16 units.
    if (body.runes.length > maxCommentLength) {
      return const ValidationFailure(
        message: 'Keep it under $maxCommentLength characters.',
      );
    }
    if (state.isPosting) return null;

    state = state.copyWith(isPosting: true);
    final result = await repository.addComment(threadId, body);
    if (!mounted) return null;

    return result.fold(
      (failure) {
        state = state.copyWith(isPosting: false);
        if (failure.code == '404') _markRemoved();
        return failure;
      },
      (comment) {
        final thread = state.thread?.copyWith(
          comments: (state.thread?.comments ?? 0) + 1,
        );
        state = state.copyWith(
          isPosting: false,
          comments: [...state.comments, comment],
          thread: thread,
        );
        if (thread != null) _syncToList(thread);
        return null;
      },
    );
  }

  /// Delete one of this person's comments. Answers with the failure, if any.
  Future<Failure?> deleteComment(String commentId) async {
    if (state.deleting.contains(commentId)) return null;
    state = state.copyWith(deleting: {...state.deleting, commentId});

    final result = await repository.deleteComment(threadId, commentId);
    if (!mounted) return null;

    final deleting = {...state.deleting}..remove(commentId);
    return result.fold(
      (failure) {
        state = state.copyWith(deleting: deleting);
        return failure;
      },
      (_) {
        final current = state.thread;
        final thread = current?.copyWith(
          comments: math.max(0, current.comments - 1),
        );
        state = state.copyWith(
          deleting: deleting,
          comments: state.comments.where((c) => c.id != commentId).toList(),
          thread: thread,
        );
        if (thread != null) _syncToList(thread);
        return null;
      },
    );
  }

  @override
  Thread? findThread(String id) => state.thread?.id == id ? state.thread : null;

  @override
  void putThread(Thread thread) {
    state = state.copyWith(thread: thread);
    _syncToList(thread);
  }

  void _markRemoved() {
    final clubId = state.thread?.club.id;
    state = const ThreadDetailState(isRemoved: true);
    // If the club's list is open behind this page, it should not keep
    // offering a post that no longer exists.
    if (clubId != null) {
      final list = clubThreadsProvider(clubId);
      if (_ref.exists(list)) _ref.read(list.notifier).remove(threadId);
    }
  }

  /// Tell the club's list, if it is open, how this post looks now.
  void _syncToList(Thread thread) {
    final list = clubThreadsProvider(thread.club.id);
    if (_ref.exists(list)) _ref.read(list.notifier).upsert(thread);
  }
}
