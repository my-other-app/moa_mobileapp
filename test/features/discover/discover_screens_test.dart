import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/discover_routes.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/domain/repositories/thread_repository.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../topics/topic_fixtures.dart';
import 'discover_fakes.dart';
import 'discover_fixtures.dart';

class _Threads implements ThreadRepository {
  final likes = <String>[];
  final reads = <String>[];
  Result<Thread> thread = Either.left(
      const ServerFailure(message: 'Not found', code: '404'));

  @override
  Future<Result<Thread>> getThread(String threadId) async {
    reads.add(threadId);
    return thread;
  }

  @override
  Future<Result<LikeResult>> toggleLike(String threadId) async {
    likes.add(threadId);
    return Either.right(const LikeResult(liked: true, likes: 5));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

class _Harness {
  _Harness(this.repo, this.threads, this.router, this.went);
  final FakeDiscoverRepository repo;
  final _Threads threads;
  final GoRouter router;
  final List<String> went;
}

Future<_Harness> _pump(
  WidgetTester tester,
  String location, {
  FakeDiscoverRepository? repo,
  bool signedIn = false,
}) async {
  tallScreen(tester);
  final r = repo ?? FakeDiscoverRepository();
  final threads = _Threads();
  final went = <String>[];
  Widget stub(GoRouterState s) {
    went.add(s.uri.toString());
    return Scaffold(appBar: AppBar(), body: Text('opened ${s.uri}'));
  }

  final router = GoRouter(initialLocation: location, routes: [
    ...discoverRoutes,
    GoRoute(path: '/events/:id', builder: (_, s) => stub(s)),
    GoRoute(path: '/clubs/:id', builder: (_, s) => stub(s)),
    GoRoute(path: '/threads/:id', builder: (_, s) => stub(s)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(r),
      threadRepositoryProvider.overrideWithValue(threads),
      isAuthenticatedProvider.overrideWithValue(signedIn),
      topicDirectoryProvider.overrideWith((ref) => Stream.value(catalogue)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await settle(tester);
  return _Harness(r, threads, router, went);
}

void main() {
  group('find clubs', () {
    testWidgets('signed out: the clubs, counted; a card opens the club',
        (tester) async {
      final h = await _pump(tester, '/discover/clubs');

      expect(find.text('Tinkerhub'), findsOneWidget);
      expect(find.text('IEEE SB'), findsOneWidget);
      expect(h.repo.clubCalls.single.$1, ClubFilters.none);
      // The list's interests, with how many clubs pick each.
      expect(find.text('Coding 7'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('discover-club-club-1')));
      await settle(tester);
      expect(h.went.single, '/clubs/1');
    });

    testWidgets('sort and topic from the sheet; chips take them off',
        (tester) async {
      final h = await _pump(tester, '/discover/clubs');

      await tester.tap(find.byKey(const ValueKey('discover-filters')));
      await settle(tester);
      // Nearby needs a place: not offered everywhere.
      expect(find.byKey(const ValueKey('sheet-club-sort-nearby')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('sheet-club-sort-newest')));
      await tapVisible(tester, find.byKey(const ValueKey('topic-chip-arts')),
          scrollable: scrollableIn('topic-filter-row'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('sheet-apply')));
      await settle(tester);

      final f = h.repo.clubCalls.last.$1;
      expect([f.sort, f.topic], [ClubSort.newest, 'arts']);
      expect(find.text('Sort: Newest (1)'), findsOneWidget);
      // The topic's own interests become the chips.
      expect(find.byKey(const ValueKey('club-interest-15')), findsOneWidget);
      // Arts holds Photography alone: the list's Coding is not offered.
      expect(find.byKey(const ValueKey('club-interest-6')), findsNothing);

      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('filter-chip-topic')),
          matching: find.byIcon(Icons.close)));
      await settle(tester);
      expect(h.repo.clubCalls.last.$1.topic, isNull);
      expect(h.repo.clubCalls.last.$1.sort, ClubSort.newest);
    });

    testWidgets('an interest chip narrows the list', (tester) async {
      final h = await _pump(tester, '/discover/clubs?q=robo');
      await tapVisible(tester, find.byKey(const ValueKey('club-interest-6')));
      await settle(tester);
      expect(h.repo.clubCalls.last.$1.interest, 6);
      expect(h.repo.clubCalls.last.$1.q, 'robo');
    });

    testWidgets('nothing matches', (tester) async {
      final repo = FakeDiscoverRepository()
        ..onClubs = (_, __) => Either.right(parseClubResults(clubsPage(const [])));
      await _pump(tester, '/discover/clubs?topic=arts', repo: repo);
      expect(find.byKey(const ValueKey('discover-clubs-empty')), findsOneWidget);
      expect(find.text('Clear search and filters'), findsOneWidget);
    });
  });

  group('from the clubs (every club\'s posts)', () {
    testWidgets('the posts; a card opens the post', (tester) async {
      final h = await _pump(tester, '/discover/threads');
      expect(find.text('Hello from the club'), findsOneWidget);

      await tester.tap(find.text('Hello from the club'));
      await settle(tester);
      expect(h.went.single, '/threads/t-1');
    });

    testWidgets('back from a post, its card is read again', (tester) async {
      final h = await _pump(tester, '/discover/threads');
      h.threads.thread = Either.right(parseThread(threadOut('t-1', body: 'Edited'))!);
      await tester.tap(find.text('Hello from the club'));
      await settle(tester);
      h.router.pop();
      await settle(tester, 12);
      expect(h.threads.reads, ['t-1']);
      expect(find.text('Edited'), findsOneWidget);

      // Removed meanwhile: the card goes.
      h.threads.thread = Either.left(
          const ServerFailure(message: 'Not found', code: '404'));
      await tester.tap(find.text('Edited'));
      await settle(tester);
      h.router.pop();
      await settle(tester, 12);
      expect(find.text('Edited'), findsNothing);
      expect(find.byKey(const ValueKey('discover-threads-empty')), findsOneWidget);
    });

    testWidgets('signed out, a like asks to sign in and sends nothing',
        (tester) async {
      final h = await _pump(tester, '/discover/threads');
      await tester.tap(find.byKey(const ValueKey('thread-like')));
      await tester.pump();
      expect(find.text('Sign in to like posts.'), findsOneWidget);
      expect(h.threads.likes, isEmpty);
    });

    testWidgets('signed in, a like goes through and shows', (tester) async {
      final h = await _pump(tester, '/discover/threads', signedIn: true);
      await tester.tap(find.byKey(const ValueKey('thread-like')));
      await settle(tester);
      expect(h.threads.likes, ['t-1']);
      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('no posts yet', (tester) async {
      final repo = FakeDiscoverRepository()
        ..onThreads = (_) => Either.right(parseThreadsPage(threadsPage(const [])));
      await _pump(tester, '/discover/threads', repo: repo);
      expect(find.byKey(const ValueKey('discover-threads-empty')), findsOneWidget);
    });
  });

  group('topics', () {
    testWidgets('every topic as a card; a card opens its page', (tester) async {
      final h = await _pump(tester, '/topics');
      expect(find.byKey(const ValueKey('topic-card-development')), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-card-arts')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('topic-card-development')));
      await settle(tester);
      expect(h.repo.topicCalls, ['development']);
      expect(find.text('DEVELOPMENT'), findsOneWidget);
    });
  });

  group('a topic\'s page', () {
    testWidgets('the topic, its interests, its events and its clubs',
        (tester) async {
      final h = await _pump(tester, '/topics/development');

      expect(find.text('Development'), findsWidgets);
      expect(find.text('12 upcoming events · 30 clubs'), findsOneWidget);
      expect(find.byKey(const ValueKey('topic-interest-6')), findsOneWidget);
      // Events and clubs in the topic, everywhere.
      final events = h.repo.eventCalls.single.$1;
      expect([events.topic, events.interest, events.place],
          ['development', null, DiscoverPlace.everywhere]);
      expect(h.repo.clubCalls.single.$1.topic, 'development');
      expect(find.text('Hack Night'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('topic-clubs')), 300,
          scrollable: scrollableIn('topic-page'));
      expect(find.byKey(const ValueKey('topic-clubs')), findsOneWidget);
      // The other topics.
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('topic-chip-arts')), 300,
          scrollable: scrollableIn('topic-page'));
      expect(find.byKey(const ValueKey('topic-chip-arts')), findsOneWidget);
    });

    testWidgets('an interest chip narrows the events and the clubs',
        (tester) async {
      final h = await _pump(tester, '/topics/development');
      await tapVisible(tester, find.byKey(const ValueKey('topic-interest-6')));
      await settle(tester);

      expect(h.repo.eventCalls.last.$1.interest, 6);
      expect(h.repo.clubCalls.last.$1.interest, 6);
      expect(find.text('UPCOMING CODING EVENTS'), findsOneWidget);
    });

    testWidgets('?interest= in the address starts narrowed', (tester) async {
      final h = await _pump(tester, '/topics/development?interest=3');
      expect(h.repo.eventCalls.single.$1.interest, 3);
    });

    testWidgets("another topic's interest in the address is ignored",
        (tester) async {
      final h = await _pump(tester, '/topics/development?interest=15');
      expect(h.repo.eventCalls.single.$1.interest, isNull);
    });

    testWidgets('no events in it: says so, with a way on', (tester) async {
      final repo = FakeDiscoverRepository()
        ..onEvents = (_, __) => Either.right(parseEventResults(eventsPage(const [])));
      await _pump(tester, '/topics/development', repo: repo);
      expect(find.byKey(const ValueKey('topic-events-empty')), findsOneWidget);
      expect(find.text('Browse all events'), findsOneWidget);
    });

    testWidgets('a topic nobody has: the page says so', (tester) async {
      final repo = FakeDiscoverRepository()
        ..onTopic = (_) => Either.left(
            const ServerFailure(message: 'Not found', code: '404'));
      await _pump(tester, '/topics/nope', repo: repo);
      expect(find.byKey(const ValueKey('topic-missing')), findsOneWidget);
    });

    testWidgets('a server without the route: the directory has it',
        (tester) async {
      final repo = FakeDiscoverRepository()
        ..onTopic = (_) => Either.left(
            const ServerFailure(message: 'Not found', code: '404'));
      await _pump(tester, '/topics/arts', repo: repo);
      expect(find.byKey(const ValueKey('topic-missing')), findsNothing);
      expect(find.text('ARTS'), findsOneWidget);
    });

    testWidgets('offline with nothing saved: an error to retry',
        (tester) async {
      final repo = FakeDiscoverRepository()
        ..onTopic = (_) => Either.left(offline);
      final h = await _pump(tester, '/topics/zzz', repo: repo);
      expect(find.text('Try Again'), findsOneWidget);
      h.repo.onTopic = (_) => Either.right(parseTopic(developmentTopicBody)!);
      await tester.tap(find.text('Try Again'));
      await settle(tester);
      expect(find.text('DEVELOPMENT'), findsOneWidget);
    });
  });

  test('every discover screen is a discover location', () {
    for (final location in [
      '/discover/events?when=today',
      '/discover/clubs',
      '/discover/threads',
      '/topics',
      '/topics/arts?interest=15',
    ]) {
      expect(isDiscoverLocation(location), isTrue, reason: location);
    }
    expect(isDiscoverLocation('/events/3'), isFalse);
    expect(isDiscoverLocation('/profile'), isFalse);
  });

  test('the locations carry the filters', () {
    expect(findEventsLocation(const EventFilters(price: EventPrice.free)),
        '/discover/events?price=free');
    expect(
        findEventsLocation(EventFilters.none, calendar: true, month: '2026-11'),
        '/discover/events?view=calendar&month=2026-11');
    expect(clubsDirectoryLocation(const ClubFilters(topic: 'arts')),
        '/discover/clubs?topic=arts');
    expect(topicLocation('deep-tech', interest: 2), '/topics/deep-tech?interest=2');
  });
}
