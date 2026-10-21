import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/utils/time_ago.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/presentation/discover_routes.dart';
import 'package:finnet/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart'
    show ImageUrls;
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/entities/thread_comment.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';
import 'package:finnet/features/threads/presentation/pages/club_threads_page.dart';
import 'package:finnet/features/threads/presentation/pages/thread_detail_page.dart';
import 'package:finnet/features/threads/presentation/providers/threads_provider.dart';
import 'package:finnet/features/threads/presentation/threads_routes.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../discover/discover_fakes.dart';

// "Some posts' pages show two Like and two Comment buttons." A post's page
// must draw exactly one of each -- whatever the post holds (a photo, a
// poll, a pin) and however it was reached (a link or notification, the
// discover feed, a club's THREADS tab, the follower's feed) -- and every
// card in a list keeps its own row.

const _club = ThreadClub(id: 5, name: 'Tinkerhub CET', slug: 'tinkerhub');
const _photo = ImageUrls(
  original: 'https://media.myotherapp.in/threads/p.png',
  medium: 'https://media.myotherapp.in/threads/p.medium.png',
);
const _openPoll = Poll(
  options: [
    PollOption(id: 'fri', label: 'Friday', votes: 3, share: 75),
    PollOption(id: 'sat', label: 'Saturday', votes: 1, share: 25),
  ],
  votes: 4,
);
final _votedPoll = _openPoll.withVote('fri');

Thread _thread(
  String id, {
  String body = 'Build sprint this Friday.',
  ImageUrls? image,
  Poll? poll,
  bool pinned = false,
  bool liked = false,
  int likes = 3,
  int comments = 2,
}) =>
    Thread(
      id: id,
      club: _club,
      body: body,
      image: image,
      kind: poll == null ? ThreadKind.post : ThreadKind.poll,
      poll: poll,
      pinned: pinned,
      liked: liked,
      likes: likes,
      comments: comments,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    );

/// Every kind of post a club can make.
final _kinds = <String, Thread>{
  'a plain post': _thread('plain'),
  'a post with a photo': _thread('photo', image: _photo),
  'a photo with no text': _thread('photo-only', body: '', image: _photo),
  'a poll not yet voted on':
      _thread('poll', body: 'Which day works?', poll: _openPoll),
  'a poll voted on': _thread('voted', body: 'Which day?', poll: _votedPoll),
  'a pinned post': _thread('pinned', pinned: true),
  'a pinned poll with a photo': _thread('pinned-poll',
      body: 'Pick one', pinned: true, image: _photo, poll: _openPoll),
  'a liked post with big counts':
      _thread('liked', liked: true, likes: 12500, comments: 1340),
  'a post with nothing on it yet': _thread('quiet', likes: 0, comments: 0),
};

class _Repository implements ThreadRepository {
  _Repository(this.threads);

  final List<Thread> threads;

  Thread _byId(String id) => threads.firstWhere((t) => t.id == id);

  @override
  Future<Result<Thread>> getThread(String threadId) async =>
      Either.right(_byId(threadId));

  @override
  Future<Result<List<ThreadComment>>> getComments(String threadId) async =>
      Either.right([
        ThreadComment(
          id: 'c1',
          body: 'Count me in',
          authorId: 7,
          authorName: 'Aarav',
          createdAt: DateTime.now(),
        ),
        ThreadComment(
          id: 'c2',
          body: 'See you there',
          authorId: 9,
          authorName: 'Tinkerhub CET',
          isClub: true,
          createdAt: DateTime.now(),
        ),
      ]);

  @override
  Future<Result<ThreadPage>> getClubThreads(int clubId,
          {int offset = 0, int limit = 20}) async =>
      Either.right(ThreadPage(items: threads, total: threads.length));

  @override
  Future<Result<ThreadPage>> getFollowingFeed(
          {String? after, int limit = 20}) async =>
      Either.right(ThreadPage(items: threads, total: threads.length));

  @override
  Future<ThreadPage?> savedFollowingFeed({int limit = 20}) async => null;

  @override
  Future<ThreadPage?> savedClubThreads(int clubId, {int limit = 20}) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// No disk and no network in a test: every picture fails to load, and the
/// card draws its fallback.
class _NoPictures extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(String url,
          {String? key, Map<String, String>? headers, bool? withProgress}) =>
      Stream.error(Exception('no network in tests'));

  @override
  Future<FileInfo?> getFileFromCache(String key,
          {bool ignoreMemCache = false}) async =>
      null;
}

/// The ways into a post's page.
enum _Way { link, discoverFeed, clubTab, followingFeed }

String _start(_Way way, Thread thread) => switch (way) {
      _Way.link => '/threads/${thread.id}',
      _Way.discoverFeed => threadsFeedPath,
      _Way.clubTab => '/club',
      _Way.followingFeed => '/following/posts',
    };

Future<void> _frames(WidgetTester tester, [int count = 12]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Open [thread]'s page the [way] a reader would, and leave it on screen.
Future<void> _open(WidgetTester tester, _Way way, Thread thread,
    {bool signedIn = false}) async {
  // The follower's feed is a signed-in reader's; every other way in is
  // open to anyone.
  signedIn = signedIn || way == _Way.followingFeed;
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  AppImageCaches.debugOverride(public: _NoPictures(), private: _NoPictures());
  addTearDown(AppImageCaches.debugOverride);

  final repo = _Repository([thread]);
  final discover = FakeDiscoverRepository()
    ..onThreads = (_) => Either.right(DiscoverPage<Thread>(
          items: [thread],
          total: 1,
        ));
  final router = GoRouter(initialLocation: _start(way, thread), routes: [
    ...discoverRoutes,
    ...threadsRoutes,
    GoRoute(
      path: '/club',
      builder: (_, __) => const Scaffold(
        body: ClubThreadsPage(clubId: 5, clubName: 'Tinkerhub CET'),
      ),
    ),
    GoRoute(
      path: '/threads/:threadId',
      builder: (_, state) =>
          ThreadDetailPage(threadId: state.pathParameters['threadId']!),
    ),
    GoRoute(
        path: '/clubs/:id',
        builder: (_, __) => const Scaffold(body: Text('club'))),
  ]);
  addTearDown(router.dispose);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      threadRepositoryProvider.overrideWithValue(repo),
      discoverRepositoryProvider.overrideWithValue(discover),
      isAuthenticatedProvider.overrideWithValue(signedIn),
      threadViewerIdProvider.overrideWithValue(signedIn ? 42 : null),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _frames(tester);

  if (way != _Way.link) {
    // The list shows the post as a card, with its own row.
    _expectOneRow(tester, of: find.byType(ThreadCard));
    // Opened from its card, as a reader would: a tap on when it was posted
    // (the name and logo open the club; a poll's options vote).
    await tester.tap(find.descendant(
        of: find.byType(ThreadCard),
        matching: find.text(timeAgo(thread.createdAt))));
    await _frames(tester, 20);
  }
  expect(find.byType(ThreadDetailPage), findsOneWidget);
}

/// Exactly one like and one comment control inside [of]: by key, by icon
/// and by what a screen reader hears -- so a second row from anywhere
/// (another card, a wrapper with its own bar) is caught.
void _expectOneRow(WidgetTester tester, {required Finder of}) {
  Finder inside(Finder f) => find.descendant(of: of, matching: f);

  expect(inside(find.byKey(const ValueKey('thread-like'))), findsOneWidget,
      reason: 'one like button');
  expect(inside(find.byKey(const ValueKey('thread-comments'))), findsOneWidget,
      reason: 'one comment button');
  final hearts = inside(find.byIcon(Icons.favorite)).evaluate().length +
      inside(find.byIcon(Icons.favorite_border)).evaluate().length;
  expect(hearts, 1, reason: 'one heart');
  expect(inside(find.byIcon(Icons.chat_bubble_outline)), findsOneWidget,
      reason: 'one speech bubble');
  expect(inside(find.bySemanticsLabel(RegExp(r'^(Like|Unlike), \d'))),
      findsOneWidget,
      reason: 'a screen reader hears one Like');
  expect(
      inside(find.bySemanticsLabel(RegExp(r'^Comments, \d'))), findsOneWidget,
      reason: 'a screen reader hears one Comments');
}

void main() {
  for (final way in _Way.values) {
    group('opened from ${way.name}', () {
      _kinds.forEach((kind, thread) {
        testWidgets('$kind: one like and one comment control', (tester) async {
          final semantics = tester.ensureSemantics();
          await _open(tester, way, thread);

          _expectOneRow(tester, of: find.byType(ThreadDetailPage));
          // The post itself is drawn once on its page.
          expect(
              find.descendant(
                  of: find.byType(ThreadDetailPage),
                  matching: find.byType(ThreadCard)),
              findsOneWidget);
          semantics.dispose();
        });
      });
    });
  }

  testWidgets('signed in, the page still has one row and one comment box',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, _Way.link, _kinds['a pinned poll with a photo']!,
        signedIn: true);

    _expectOneRow(tester, of: find.byType(ThreadDetailPage));
    expect(find.byKey(const ValueKey('comment-field')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets("the page's comment button opens the comment box",
      (tester) async {
    await _open(tester, _Way.link, _kinds['a plain post']!, signedIn: true);

    final field = find.byKey(const ValueKey('comment-field'));
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isFalse);
    await tester.tap(find.byKey(const ValueKey('thread-comments')));
    await tester.pump();
    expect(tester.widget<TextField>(field).focusNode!.hasFocus, isTrue);
  });

  testWidgets("signed out, the page's comment button asks to sign in",
      (tester) async {
    await _open(tester, _Way.link, _kinds['a plain post']!);

    await tester.tap(find.byKey(const ValueKey('thread-comments')));
    await _frames(tester);
    expect(find.text('Sign in to comment.'), findsOneWidget);
  });

  testWidgets('every card in a list keeps its own row', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    AppImageCaches.debugOverride(public: _NoPictures(), private: _NoPictures());
    addTearDown(AppImageCaches.debugOverride);

    final threads = [_kinds['a plain post']!, _kinds['a poll voted on']!];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        threadRepositoryProvider.overrideWithValue(_Repository(threads)),
        isAuthenticatedProvider.overrideWithValue(false),
        threadViewerIdProvider.overrideWithValue(null),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ClubThreadsPage(clubId: 5, clubName: 'Tinkerhub CET'),
        ),
      ),
    ));
    await _frames(tester);

    for (final t in threads) {
      _expectOneRow(tester, of: find.byKey(ValueKey(t.id)));
    }
    semantics.dispose();
  });
}
