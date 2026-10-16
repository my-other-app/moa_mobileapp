import 'dart:async';

import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';
import 'package:finnet/features/threads/presentation/providers/threads_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _club = ThreadClub(id: 5, name: 'Tinkerhub CET');

Thread _thread(String id, {bool liked = false, int likes = 0, Poll? poll}) =>
    Thread(
      id: id,
      club: _club,
      body: 'Post $id',
      kind: poll == null ? ThreadKind.post : ThreadKind.poll,
      poll: poll,
      liked: liked,
      likes: likes,
      createdAt: DateTime(2026, 10, 16),
    );

ThreadComment _comment(String id, {int? authorId}) => ThreadComment(
      id: id,
      body: 'Comment $id',
      authorId: authorId,
      authorName: 'A',
      createdAt: DateTime(2026, 10, 16),
    );

class _FakeRepository implements ThreadRepository {
  final List<({int offset, int limit})> pageCalls = [];
  final Map<int, Result<ThreadPage>> pages = {};
  Result<Thread> thread = Either.right(_thread('t1'));
  Result<List<ThreadComment>> comments = Either.right(const []);

  /// Held open until the test completes it, so the optimistic state can be
  /// looked at before the server "answers".
  Completer<Result<LikeResult>>? like;
  Completer<Result<Poll>>? voteAnswer;
  Result<ThreadComment> added = Either.right(_comment('new', authorId: 1));
  Result<void> deleted = Either.right(null);
  int addCalls = 0;

  @override
  Future<Result<ThreadPage>> getClubThreads(int clubId,
      {int offset = 0, int limit = 20}) async {
    pageCalls.add((offset: offset, limit: limit));
    return pages[offset] ??
        Either.right(ThreadPage(offset: offset, limit: limit));
  }

  @override
  Future<Result<Thread>> getThread(String threadId) async => thread;

  @override
  Future<Result<LikeResult>> toggleLike(String threadId) =>
      (like ??= Completer()).future;

  @override
  Future<Result<Poll>> vote(String threadId, String optionId) =>
      (voteAnswer ??= Completer()).future;

  @override
  Future<Result<List<ThreadComment>>> getComments(String threadId) async =>
      comments;

  @override
  Future<Result<ThreadComment>> addComment(String threadId, String body) async {
    addCalls++;
    return added;
  }

  @override
  Future<Result<void>> deleteComment(String threadId, String commentId) async =>
      deleted;
}

ProviderContainer _container(_FakeRepository repository) {
  final container = ProviderContainer(overrides: [
    threadRepositoryProvider.overrideWithValue(repository),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Lets the notifier's self-started load finish.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group("a club's posts", () {
    test('load themselves on first read', () async {
      final repo = _FakeRepository()
        ..pages[0] = Either.right(ThreadPage(
          items: [_thread('t1'), _thread('t2')],
          total: 2,
        ));
      final container = _container(repo);
      final sub = container.listen(clubThreadsProvider(5), (_, __) {});
      addTearDown(sub.close);

      expect(container.read(clubThreadsProvider(5)).isLoading, isTrue);
      await _settle();

      final state = container.read(clubThreadsProvider(5));
      expect(state.isLoading, isFalse);
      expect(state.threads.map((t) => t.id), ['t1', 't2']);
      expect(state.hasMore, isFalse);
      expect(repo.pageCalls.single, (offset: 0, limit: threadsPageSize));
    });

    test('a failed first load is an error, not an empty club', () async {
      final repo = _FakeRepository()
        ..pages[0] = Either.left(const NetworkFailure(message: 'offline'));
      final container = _container(repo);
      final sub = container.listen(clubThreadsProvider(5), (_, __) {});
      addTearDown(sub.close);
      await _settle();

      final state = container.read(clubThreadsProvider(5));
      expect(state.error, 'offline');
      expect(state.threads, isEmpty);
    });

    test('load more asks for the next offset and drops repeats', () async {
      final repo = _FakeRepository()
        ..pages[0] = Either.right(ThreadPage(
          items: [_thread('t1'), _thread('t2')],
          total: 4,
          limit: 2,
        ))
        // A new post shifted everything down one: t2 arrives again.
        ..pages[2] = Either.right(ThreadPage(
          items: [_thread('t2'), _thread('t3')],
          total: 4,
          limit: 2,
          offset: 2,
        ));
      final container = _container(repo);
      final sub = container.listen(clubThreadsProvider(5), (_, __) {});
      addTearDown(sub.close);
      await _settle();

      await container.read(clubThreadsProvider(5).notifier).loadMore();

      final state = container.read(clubThreadsProvider(5));
      expect(repo.pageCalls.last.offset, 2);
      expect(state.threads.map((t) => t.id), ['t1', 't2', 't3']);
      // The next page starts after what the server sent, not after what was
      // kept -- or the same page would be asked for again.
      expect(state.nextOffset, 4);
    });

    test('a failed load more keeps the list and offers a retry', () async {
      final repo = _FakeRepository()
        ..pages[0] = Either.right(ThreadPage(
          items: [_thread('t1')],
          total: 3,
          limit: 1,
        ))
        ..pages[1] = Either.left(const ServerFailure(message: 'boom'));
      final container = _container(repo);
      final sub = container.listen(clubThreadsProvider(5), (_, __) {});
      addTearDown(sub.close);
      await _settle();

      await container.read(clubThreadsProvider(5).notifier).loadMore();

      final state = container.read(clubThreadsProvider(5));
      expect(state.threads.map((t) => t.id), ['t1']);
      expect(state.loadMoreError, 'boom');
      expect(state.hasMore, isTrue);
    });
  });

  group('liking is optimistic, then settles on the server', () {
    Future<(ProviderContainer, _FakeRepository)> listWith(Thread t) async {
      final repo = _FakeRepository()
        ..pages[0] = Either.right(ThreadPage(items: [t], total: 1));
      final container = _container(repo);
      final sub = container.listen(clubThreadsProvider(5), (_, __) {});
      addTearDown(sub.close);
      await _settle();
      return (container, repo);
    }

    test('flips at once, then takes the count the server answers', () async {
      final (container, repo) = await listWith(_thread('t1', likes: 4));
      final notifier = container.read(clubThreadsProvider(5).notifier);

      final pending = notifier.toggleLike('t1');
      var t = container.read(clubThreadsProvider(5)).threads.single;
      expect(t.liked, isTrue);
      expect(t.likes, 5);

      // Someone else liked it meanwhile: the server's count wins.
      repo.like!.complete(Either.right(const LikeResult(liked: true, likes: 7)));
      expect(await pending, isNull);

      t = container.read(clubThreadsProvider(5)).threads.single;
      expect(t.liked, isTrue);
      expect(t.likes, 7);
    });

    test('a failure puts back what was there and is reported', () async {
      final (container, repo) =
          await listWith(_thread('t1', liked: true, likes: 3));
      final notifier = container.read(clubThreadsProvider(5).notifier);

      final pending = notifier.toggleLike('t1');
      expect(container.read(clubThreadsProvider(5)).threads.single.liked,
          isFalse);

      repo.like!.complete(Either.left(const AuthFailure(code: '401')));
      expect(await pending, isA<AuthFailure>());

      final t = container.read(clubThreadsProvider(5)).threads.single;
      expect(t.liked, isTrue);
      expect(t.likes, 3);
    });

    test('a second tap while the first is in flight is ignored', () async {
      final (container, repo) = await listWith(_thread('t1'));
      final notifier = container.read(clubThreadsProvider(5).notifier);

      final first = notifier.toggleLike('t1');
      final second = notifier.toggleLike('t1');
      expect(await second, isNull);
      expect(container.read(clubThreadsProvider(5)).threads.single.likes, 1);

      repo.like!.complete(Either.right(const LikeResult(liked: true, likes: 1)));
      await first;
    });
  });

  group('voting', () {
    const poll = Poll(
      options: [
        PollOption(id: 'a', label: 'A', votes: 1, share: 50),
        PollOption(id: 'b', label: 'B', votes: 1, share: 50),
      ],
      votes: 2,
      votedOptionId: 'a',
    );

    test('moves the vote at once, then takes the server poll', () async {
      final repo = _FakeRepository()
        ..pages[0] = Either.right(
            ThreadPage(items: [_thread('t1', poll: poll)], total: 1));
      final container = _container(repo);
      final sub = container.listen(clubThreadsProvider(5), (_, __) {});
      addTearDown(sub.close);
      await _settle();
      final notifier = container.read(clubThreadsProvider(5).notifier);

      final pending = notifier.vote('t1', 'b');
      var p = container.read(clubThreadsProvider(5)).threads.single.poll!;
      expect(p.votedOptionId, 'b');
      expect(p.votes, 2);
      expect(p.options.map((o) => o.votes), [0, 2]);

      const settled = Poll(
        options: [
          PollOption(id: 'a', label: 'A', votes: 3, share: 60),
          PollOption(id: 'b', label: 'B', votes: 2, share: 40),
        ],
        votes: 5,
        votedOptionId: 'b',
      );
      repo.voteAnswer!.complete(Either.right(settled));
      await pending;

      p = container.read(clubThreadsProvider(5)).threads.single.poll!;
      expect(p, settled);
    });

    test('a failed vote restores the poll as it was', () async {
      final repo = _FakeRepository()
        ..pages[0] = Either.right(
            ThreadPage(items: [_thread('t1', poll: poll)], total: 1));
      final container = _container(repo);
      final sub = container.listen(clubThreadsProvider(5), (_, __) {});
      addTearDown(sub.close);
      await _settle();

      final pending =
          container.read(clubThreadsProvider(5).notifier).vote('t1', 'b');
      repo.voteAnswer!
          .complete(Either.left(const ServerFailure(message: 'nope')));
      expect(await pending, isA<ServerFailure>());

      expect(container.read(clubThreadsProvider(5)).threads.single.poll, poll);
    });
  });

  group("a post's own page", () {
    test('loads the post and its comments', () async {
      final repo = _FakeRepository()
        ..comments = Either.right([_comment('c1'), _comment('c2')]);
      final container = _container(repo);
      final sub = container.listen(threadDetailProvider('t1'), (_, __) {});
      addTearDown(sub.close);
      await _settle();

      final state = container.read(threadDetailProvider('t1'));
      expect(state.thread?.id, 't1');
      expect(state.comments.map((c) => c.id), ['c1', 'c2']);
      expect(state.isRemoved, isFalse);
    });

    test('a 404 means the post was removed', () async {
      final repo = _FakeRepository()
        ..thread = Either.left(
            const ServerFailure(message: 'Post not found', code: '404'))
        ..comments = Either.left(
            const ServerFailure(message: 'Post not found', code: '404'));
      final container = _container(repo);
      final sub = container.listen(threadDetailProvider('gone'), (_, __) {});
      addTearDown(sub.close);
      await _settle();

      final state = container.read(threadDetailProvider('gone'));
      expect(state.isRemoved, isTrue);
      expect(state.error, isNull);
    });

    test('any other failure is an error to retry', () async {
      final repo = _FakeRepository()
        ..thread = Either.left(const NetworkFailure(message: 'offline'));
      final container = _container(repo);
      final sub = container.listen(threadDetailProvider('t1'), (_, __) {});
      addTearDown(sub.close);
      await _settle();

      final state = container.read(threadDetailProvider('t1'));
      expect(state.isRemoved, isFalse);
      expect(state.error, 'offline');
    });

    test('a comment is checked before it is sent', () async {
      final repo = _FakeRepository();
      final container = _container(repo);
      final sub = container.listen(threadDetailProvider('t1'), (_, __) {});
      addTearDown(sub.close);
      await _settle();
      final notifier = container.read(threadDetailProvider('t1').notifier);

      expect(await notifier.addComment('   '), isA<ValidationFailure>());
      expect(
        await notifier.addComment('x' * (maxCommentLength + 1)),
        isA<ValidationFailure>(),
      );
      expect(repo.addCalls, 0);
    });

    test('a posted comment appears and bumps the count everywhere', () async {
      final repo = _FakeRepository()
        ..pages[0] = Either.right(ThreadPage(items: [_thread('t1')], total: 1));
      final container = _container(repo);
      final list = container.listen(clubThreadsProvider(5), (_, __) {});
      final detail = container.listen(threadDetailProvider('t1'), (_, __) {});
      addTearDown(list.close);
      addTearDown(detail.close);
      await _settle();

      final failure = await container
          .read(threadDetailProvider('t1').notifier)
          .addComment('  Count me in  ');

      expect(failure, isNull);
      final state = container.read(threadDetailProvider('t1'));
      expect(state.comments.single.id, 'new');
      expect(state.thread!.comments, 1);
      // The club's list behind this page shows it too.
      expect(container.read(clubThreadsProvider(5)).threads.single.comments, 1);
    });

    test('deleting a comment removes it and lowers the count', () async {
      final repo = _FakeRepository()
        ..thread = Either.right(Thread(
          id: 't1',
          club: _club,
          body: 'b',
          comments: 2,
          createdAt: DateTime(2026, 10, 16),
        ))
        ..comments = Either.right(
            [_comment('c1', authorId: 1), _comment('c2', authorId: 2)]);
      final container = _container(repo);
      final sub = container.listen(threadDetailProvider('t1'), (_, __) {});
      addTearDown(sub.close);
      await _settle();

      final failure = await container
          .read(threadDetailProvider('t1').notifier)
          .deleteComment('c1');

      expect(failure, isNull);
      final state = container.read(threadDetailProvider('t1'));
      expect(state.comments.map((c) => c.id), ['c2']);
      expect(state.thread!.comments, 1);
      expect(state.deleting, isEmpty);
    });

    test('a refused delete keeps the comment and reports why', () async {
      final repo = _FakeRepository()
        ..comments = Either.right([_comment('c1', authorId: 1)])
        ..deleted = Either.left(
            const AuthFailure(message: 'Not yours', code: '403'));
      final container = _container(repo);
      final sub = container.listen(threadDetailProvider('t1'), (_, __) {});
      addTearDown(sub.close);
      await _settle();

      final failure = await container
          .read(threadDetailProvider('t1').notifier)
          .deleteComment('c1');

      expect(failure?.message, 'Not yours');
      expect(container.read(threadDetailProvider('t1')).comments, hasLength(1));
    });

    test('a like on the post page reaches the club list behind it', () async {
      final repo = _FakeRepository()
        ..pages[0] = Either.right(ThreadPage(items: [_thread('t1')], total: 1));
      final container = _container(repo);
      final list = container.listen(clubThreadsProvider(5), (_, __) {});
      final detail = container.listen(threadDetailProvider('t1'), (_, __) {});
      addTearDown(list.close);
      addTearDown(detail.close);
      await _settle();

      final pending =
          container.read(threadDetailProvider('t1').notifier).toggleLike('t1');
      repo.like!.complete(Either.right(const LikeResult(liked: true, likes: 1)));
      await pending;

      final listed = container.read(clubThreadsProvider(5)).threads.single;
      expect(listed.liked, isTrue);
      expect(listed.likes, 1);
    });
  });
}
