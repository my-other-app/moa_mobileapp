import 'dart:async';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/threads/data/datasources/thread_remote_datasource.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';
import 'package:finnet/features/threads/presentation/pages/club_threads_page.dart';
import 'package:finnet/features/threads/presentation/pages/following_threads_page.dart';
import 'package:finnet/features/threads/presentation/pages/thread_detail_page.dart';
import 'package:finnet/features/threads/presentation/providers/threads_provider.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_share.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

Thread _post(String id, {String body = 'Build sprint this Friday.'}) => Thread(
      id: id,
      club: const ThreadClub(id: 5, name: 'Tinkerhub CET', slug: 'tinkerhub'),
      body: body,
      likes: 3,
      createdAt: DateTime.now(),
    );

Map<String, dynamic> _postJson(String id) => {
      'id': id,
      'club': {'id': 5, 'name': 'Tinkerhub CET', 'slug': 'tinkerhub'},
      'body': 'Post $id',
      'image': null,
      'kind': 'post',
      'poll': null,
      'pinned': false,
      'notify_followers': false,
      'likes': 0,
      'comments': 0,
      'views': 1,
      'liked': false,
      'created_at': '2026-10-18T10:00:00+05:30',
    };

class _FakeRepository implements ThreadRepository {
  final feedCalls = <String?>[];
  final pages = <String?, Result<ThreadPage>>{};
  ThreadPage? saved;
  Result<ThreadPage> clubPage = Either.right(const ThreadPage());
  int likes = 0;

  @override
  Future<Result<ThreadPage>> getFollowingFeed(
      {String? after, int limit = 20}) async {
    feedCalls.add(after);
    return pages[after] ?? Either.right(const ThreadPage());
  }

  @override
  Future<ThreadPage?> savedFollowingFeed({int limit = 20}) async => saved;

  @override
  Future<Result<ThreadPage>> getClubThreads(int clubId,
          {int offset = 0, int limit = 20}) async =>
      clubPage;

  @override
  Future<Result<Thread>> getThread(String threadId) async =>
      Either.right(_post(threadId));

  @override
  Future<Result<List<ThreadComment>>> getComments(String threadId) async =>
      Either.right(const []);

  @override
  Future<Result<LikeResult>> toggleLike(String threadId) async {
    likes++;
    return Either.right(const LikeResult(liked: true, likes: 4));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// What would have gone to the share sheet.
class _Shared {
  final texts = <String>[];
  final subjects = <String?>[];

  ThreadSharer get sharer => (text, {subject, origin}) async {
        texts.add(text);
        subjects.add(subject);
      };
}

Future<void> _pump(
  WidgetTester tester,
  Widget page, {
  required _FakeRepository repo,
  required bool signedIn,
  _Shared? shared,
}) async {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => page),
    GoRoute(
        path: '/auth/onboarding',
        builder: (_, __) => const Scaffold(body: Text('sign-in screen'))),
    GoRoute(
        path: '/clubs/explore',
        builder: (_, __) => const Scaffold(body: Text('explore'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      threadRepositoryProvider.overrideWithValue(repo),
      isAuthenticatedProvider.overrideWithValue(signedIn),
      threadViewerIdProvider.overrideWithValue(signedIn ? 42 : null),
      if (shared != null) threadSharerProvider.overrideWithValue(shared.sharer),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  // Not pumpAndSettle: the loading skeleton shimmers forever.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('GET /threads/feed', () {
    late RouteAdapter api;
    late ThreadRemoteDataSource source;

    setUp(() {
      api = useFakeApi();
      source = ThreadRemoteDataSourceImpl(APIService.instance.dio,
          cache: ApiCache(
              shared: MemoryCacheStore(), personal: MemoryCacheStore()));
    });

    test('the first page, kept encrypted; the next by its cursor', () async {
      api.on('GET', '/threads/feed', {
        'items': [_postJson('a'), _postJson('b')],
        'total': 30,
        'limit': 2,
        'offset': 0,
        'next_cursor': 'cur-1',
      });

      final first = await source.getFollowingFeed(limit: 2);
      expect(first.items.map((t) => t.id), ['a', 'b']);
      expect(first.nextCursor, 'cur-1');
      final sent = api.requests.last;
      expect(sent.queryParameters, {'limit': 2});
      expect(CachePolicy.of(sent)?.scope, CacheScope.personal);

      await source.getFollowingFeed(after: 'cur-1', limit: 2);
      final next = api.requests.last;
      expect(next.queryParameters, {'limit': 2, 'after': 'cur-1'});
      expect(CachePolicy.of(next), isNull);
    });
  });

  group('the following feed', () {
    test('signed out, it asks for nothing', () async {
      final repo = _FakeRepository();
      final container = ProviderContainer(overrides: [
        threadRepositoryProvider.overrideWithValue(repo),
        isAuthenticatedProvider.overrideWithValue(false),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(followingThreadsProvider, (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      expect(repo.feedCalls, isEmpty);
      expect(container.read(followingThreadsProvider).isLoading, isFalse);
    });

    test('pages by cursor until there is none', () async {
      final repo = _FakeRepository()
        ..pages[null] = Either.right(ThreadPage(
            items: [_post('a'), _post('b')], total: 3, nextCursor: 'c1'))
        ..pages['c1'] =
            Either.right(ThreadPage(items: [_post('b'), _post('c')], total: 3));
      final container = ProviderContainer(overrides: [
        threadRepositoryProvider.overrideWithValue(repo),
        isAuthenticatedProvider.overrideWithValue(true),
      ]);
      addTearDown(container.dispose);
      final sub = container.listen(followingThreadsProvider, (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);

      expect(container.read(followingThreadsProvider).hasMore, isTrue);
      await container.read(followingThreadsProvider.notifier).loadMore();

      final state = container.read(followingThreadsProvider);
      expect(repo.feedCalls, [null, 'c1']);
      // A post on both pages is listed once.
      expect(state.threads.map((t) => t.id), ['a', 'b', 'c']);
      expect(state.hasMore, isFalse);
    });

    testWidgets('signed out, the page asks to sign in', (tester) async {
      final repo = _FakeRepository();
      await _pump(tester, const FollowingThreadsPage(),
          repo: repo, signedIn: false);

      expect(find.byKey(const ValueKey('following-posts-signed-out')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('following-posts-sign-in')));
      await tester.pumpAndSettle();
      expect(find.text('sign-in screen'), findsOneWidget);
      expect(repo.feedCalls, isEmpty);
    });

    testWidgets('the kept page shows first, then the fresh one',
        (tester) async {
      final fresh = Completer<Result<ThreadPage>>();
      final repo = _HeldRepository(fresh)
        ..saved = ThreadPage(items: [_post('old', body: 'Kept post')]);
      await _pump(tester, const FollowingThreadsPage(),
          repo: repo, signedIn: true);

      expect(find.text('Kept post'), findsOneWidget);

      fresh.complete(Either.right(
          ThreadPage(items: [_post('new', body: 'Fresh post')], total: 1)));
      await tester.pump();
      await tester.pump();
      expect(find.text('Fresh post'), findsOneWidget);
      expect(find.text('Kept post'), findsNothing);
    });

    testWidgets('nothing yet: a way to find clubs to follow', (tester) async {
      await _pump(tester, const FollowingThreadsPage(),
          repo: _FakeRepository(), signedIn: true);

      expect(
          find.byKey(const ValueKey('following-posts-empty')), findsOneWidget);
      expect(find.text('EXPLORE CLUBS'), findsOneWidget);
    });
  });

  group('sharing a post', () {
    test('the post on the website, with its first line', () {
      expect(threadShareUrl('2b1c-uuid'),
          'https://myotherapp.in/threads/2b1c-uuid');
      final text = threadShareText(
          _post('t1', body: '\nBuild sprint this Friday.\nBring a laptop.'));
      expect(
          text,
          'Build sprint this Friday.\n\n'
          'Tinkerhub CET on MyOtherApp: https://myotherapp.in/threads/t1');
      expect(threadShareText(_post('t2', body: '')),
          'Tinkerhub CET on MyOtherApp: https://myotherapp.in/threads/t2');
    });

    testWidgets('from a card in the feed', (tester) async {
      final shared = _Shared();
      final repo = _FakeRepository()
        ..pages[null] = Either.right(ThreadPage(items: [_post('t1')]));
      await _pump(tester, const FollowingThreadsPage(),
          repo: repo, signedIn: true, shared: shared);

      await tester.tap(find.byKey(const ValueKey('thread-share')));
      await tester.pump();

      expect(shared.texts.single, contains('https://myotherapp.in/threads/t1'));
      expect(shared.subjects.single, 'A post from Tinkerhub CET');
    });

    testWidgets("from the post's own page", (tester) async {
      final shared = _Shared();
      await _pump(tester, const ThreadDetailPage(threadId: 't9'),
          repo: _FakeRepository(), signedIn: false, shared: shared);

      await tester.tap(find.byKey(const ValueKey('thread-detail-share')));
      await tester.pump();

      expect(shared.texts.single, contains('https://myotherapp.in/threads/t9'));
    });
  });

  group("signed out, a club's posts", () {
    testWidgets('read as anyone, and liking asks to sign in first',
        (tester) async {
      final repo = _FakeRepository()
        ..clubPage = Either.right(
            ThreadPage(items: [_post('t1', body: 'Open to all')], total: 1));
      await _pump(
        tester,
        const Scaffold(
          body: ClubThreadsPage(clubId: 5, clubName: 'Tinkerhub CET'),
        ),
        repo: repo,
        signedIn: false,
      );

      expect(find.text('Open to all'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('thread-like')));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to like posts.'), findsOneWidget);
      expect(repo.likes, 0);
    });
  });
}

/// Holds the fresh first page until the test lets it through.
class _HeldRepository extends _FakeRepository {
  _HeldRepository(this.fresh);

  final Completer<Result<ThreadPage>> fresh;

  @override
  Future<Result<ThreadPage>> getFollowingFeed({String? after, int limit = 20}) {
    feedCalls.add(after);
    return fresh.future;
  }
}
