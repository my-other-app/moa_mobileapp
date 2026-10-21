import 'dart:async';

import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:finnet/features/home/presentation/pages/home_page.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../discover/discover_fakes.dart';
import '../discover/discover_fixtures.dart';
import '../events/events_fakes.dart';
import '../topics/topic_fixtures.dart';

class _Harness {
  _Harness(this.repo, this.went);
  final FakeDiscoverRepository repo;
  final List<String> went;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  FakeDiscoverRepository? repo,
  bool signedIn = false,
  bool settleIt = true,
}) async {
  tallScreen(tester);
  final api = useFakeApi();
  api.on(
      'GET',
      '/events/list?is_following=true&is_ended=false&offset=0&limit=10',
      {'items': []});
  final r = repo ?? FakeDiscoverRepository();
  final went = <String>[];
  Widget stub(GoRouterState s) {
    went.add(s.uri.toString());
    return Scaffold(appBar: AppBar(), body: Text('opened ${s.uri}'));
  }

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: HomePage())),
    for (final path in [
      '/events/:id',
      '/clubs/:id',
      '/threads/:id',
      '/discover/events',
      '/discover/clubs',
      '/discover/threads',
      '/topics',
      '/topics/:slug',
    ])
      GoRoute(path: path, builder: (_, s) => stub(s)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(r),
      isAuthenticatedProvider.overrideWithValue(signedIn),
      topicDirectoryProvider.overrideWith((ref) => Stream.value(catalogue)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  if (settleIt) await settle(tester);
  return _Harness(r, went);
}

Finder _rail(String name) => find.byKey(ValueKey('rail-$name'));

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 300,
      scrollable: scrollableIn('discover-home'));
  // Laid out where it was scrolled to before anything taps it.
  await tester.pump();
}

void main() {
  group('signed out', () {
    testWidgets('DISCOVER alone, with every rail the server sent',
        (tester) async {
      final h = await _pump(tester);

      // No FOR YOU or FOLLOWING: they are about the person.
      expect(find.byKey(const ValueKey('home-tab-0')), findsNothing);
      expect(find.text('FOR YOU'), findsNothing);
      // Placed by connection: the server named the city, on the pill at
      // the top; the near rails under it say "near you".
      expect(find.text('Near Thiruvananthapuram'), findsOneWidget);
      expect(find.text('EVENTS NEAR YOU'), findsOneWidget);
      expect(find.text('Hack Night'), findsOneWidget);
      // Then the topics, and the rest of the rails in order.
      await _scrollTo(tester, find.byKey(const ValueKey('browse-by-topic')));
      await _scrollTo(tester, _rail('this-week'));
      // Clubs with a distance are the near ones.
      await _scrollTo(tester, find.text('CLUBS NEAR YOU'));
      await _scrollTo(tester, _rail('online'));
      await _scrollTo(tester, _rail('popular'));
      await _scrollTo(tester, _rail('threads'));
      expect(find.text('Hello from the club'), findsOneWidget);

      // Nothing about the person is asked for.
      expect(_rail('following'), findsNothing);
      expect(h.repo.followingCalls, 0);
      expect(h.repo.homeCalls, hasLength(1));
    });

    testWidgets('cards open the event and the club; See all opens the list',
        (tester) async {
      final h = await _pump(tester);

      await tester.tap(find.byKey(const ValueKey('discover-event-1')));
      await settle(tester);
      expect(h.went.last, '/events/1');
      await tester.pageBack();
      await settle(tester, 16);

      await _scrollTo(tester, _rail('this-week'));
      await tester.tap(find.descendant(
          of: _rail('this-week'), matching: find.text('See all')));
      await settle(tester);
      expect(h.went.last, '/discover/events?when=this_week');
      await tester.pageBack();
      await settle(tester, 16);

      await _scrollTo(
          tester, find.byKey(const ValueKey('discover-club-club-5')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('discover-club-club-5')));
      await settle(tester);
      expect(h.went.last, '/clubs/5');
    });

    testWidgets('near you: See all is near, closest first', (tester) async {
      final h = await _pump(tester);
      await tester.tap(
          find.descendant(of: _rail('near'), matching: find.text('See all')));
      await settle(tester);
      expect(h.went.last, '/discover/events?sort=distance&near=1');
    });

    testWidgets('the place line offers everywhere instead', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('discover-home-where')));
      await settle(tester);
      expect(find.text('We guessed Thiruvananthapuram from your connection.'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('discover-where-everywhere')));
      await settle(tester);
      expect(h.went.last, '/discover/events');
    });

    testWidgets('a city picked on the pill: the page is about it',
        (tester) async {
      final h = await _pump(tester);
      expect(h.repo.homeAts.single, isNull);

      await tester.tap(find.byKey(const ValueKey('discover-home-where')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('discover-where-city-kochi')));
      await settle(tester);

      // Read again about Kochi, and named for it; nowhere else opened.
      expect(h.repo.homeAts.last, (lat: 9.982, lng: 76.3));
      expect(find.text('Near Kochi'), findsOneWidget);
      expect(h.went, isEmpty);

      await tester.tap(find.byKey(const ValueKey('discover-home-where')));
      await settle(tester);
      expect(find.text('You picked Kochi.'), findsOneWidget);
      expect(find.text("Use my connection's guess"), findsOneWidget);
    });

    testWidgets('guess again: asked without a point, and the guess kept',
        (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('discover-home-where')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('discover-where-city-kochi')));
      await settle(tester);
      expect(find.text('Near Kochi'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('discover-home-where')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('discover-where-guess')));
      await settle(tester);

      expect(h.repo.homeAts.last, isNull);
      expect(find.text('Near Thiruvananthapuram'), findsOneWidget);
    });

    testWidgets('the top: the counts the server sent, and quick ways in',
        (tester) async {
      final h = await _pump(tester);
      expect(find.text("WHAT'S ON"), findsOneWidget);
      expect(find.text('40 upcoming events · 12 clubs'), findsOneWidget);

      for (final (chip, location) in [
        ('today', '/discover/events?when=today'),
        ('weekend', '/discover/events?when=this_weekend'),
        ('free', '/discover/events?price=free'),
        ('online', '/discover/events?type=online'),
        ('near', '/discover/events?sort=distance&near=1'),
        ('calendar', '/discover/events?view=calendar'),
      ]) {
        await tapVisible(tester, find.byKey(ValueKey('discover-quick-$chip')),
            scrollable: scrollableIn('discover-home-quick'));
        await settle(tester);
        expect(h.went.last, location, reason: chip);
        await tester.pageBack();
        await settle(tester, 16);
      }
    });

    testWidgets('search opens Find events, ready to type', (tester) async {
      final h = await _pump(tester);
      await tester.tap(find.byKey(const ValueKey('home-search')));
      await settle(tester);
      expect(h.went.last, '/discover/events?focus=search');
    });

    testWidgets('a post opens; its club opens', (tester) async {
      final h = await _pump(tester);
      await _scrollTo(tester, find.text('Hello from the club'));
      await tester.tap(find.text('Hello from the club'));
      await settle(tester);
      expect(h.went.last, '/threads/t-1');
    });
  });

  group('signed in', () {
    testWidgets('DISCOVER, FOR YOU and FOLLOWING; the followed clubs rail',
        (tester) async {
      final h = await _pump(tester, signedIn: true);

      expect(find.text('DISCOVER'), findsOneWidget);
      expect(find.text('FOR YOU'), findsOneWidget);
      expect(find.text('FOLLOWING'), findsOneWidget);
      expect(_rail('following'), findsOneWidget);
      expect(find.text('Followed Meetup'), findsOneWidget);
      expect(h.repo.followingCalls, 1);
    });

    testWidgets("the followed clubs' See all is the FOLLOWING tab",
        (tester) async {
      await _pump(tester, signedIn: true);
      await tester.tap(find.descendant(
          of: _rail('following'), matching: find.text('See all')));
      await settle(tester, 12);
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabs.controller!.index, 2);
    });
  });

  group('states', () {
    testWidgets('loading: the rails\' shapes', (tester) async {
      final repo = FakeDiscoverRepository()..hold = Completer<void>();
      await _pump(tester, repo: repo, settleIt: false);
      await tester.pump();
      expect(
          find.byKey(const ValueKey('discover-home-loading')), findsOneWidget);
      repo.hold!.complete();
      await settle(tester);
      expect(find.text('Hack Night'), findsOneWidget);
    });

    testWidgets('empty: it says so, with a way on', (tester) async {
      final repo = FakeDiscoverRepository()
        ..homeResult = Either.right(parseHome(emptyHomeBody()));
      final h = await _pump(tester, repo: repo);

      expect(find.byKey(const ValueKey('discover-home-empty')), findsOneWidget);
      expect(_rail('near'), findsNothing);
      expect(_rail('this-week'), findsNothing);
      // Placed nowhere: everywhere.
      expect(find.text('Everywhere'), findsOneWidget);
      await tester.tap(find.text('Browse all events'));
      await settle(tester);
      expect(h.went.last, '/discover/events');
    });

    testWidgets('an error with nothing saved: a retry that works',
        (tester) async {
      final repo = FakeDiscoverRepository()..homeResult = Either.left(offline);
      await _pump(tester, repo: repo);

      expect(find.byKey(const ValueKey('discover-home-error')), findsOneWidget);
      repo.homeResult = Either.right(parseHome(homeBody()));
      await tester.tap(find.text('Try Again'));
      await settle(tester);
      expect(find.text('Hack Night'), findsOneWidget);
    });

    testWidgets('offline with a saved copy: the copy, no error',
        (tester) async {
      final repo = FakeDiscoverRepository()
        ..savedHomeValue = parseHome(
            homeBody(near: [eventCard(9, name: 'Saved Night', distanceKm: 1)]))
        ..homeResult = Either.left(offline);
      await _pump(tester, repo: repo);

      expect(find.text('Saved Night'), findsOneWidget);
      expect(find.byKey(const ValueKey('discover-home-error')), findsNothing);
    });

    testWidgets('a saved copy is drawn first, then the fresh one',
        (tester) async {
      final repo = FakeDiscoverRepository()
        ..savedHomeValue = parseHome(
            homeBody(near: [eventCard(9, name: 'Saved Night', distanceKm: 1)]))
        ..hold = Completer<void>();
      await _pump(tester, repo: repo);
      expect(find.text('Saved Night'), findsOneWidget);

      repo.hold!.complete();
      await settle(tester);
      expect(find.text('Saved Night'), findsNothing);
      expect(find.text('Hack Night'), findsOneWidget);
    });

    testWidgets('the near rail holds only what is near the place',
        (tester) async {
      // A server that pads "near" with an event 178 km off and an online
      // one: neither is near anyone.
      final repo = FakeDiscoverRepository()
        ..homeResult = Either.right(parseHome(homeBody(near: [
          eventCard(1, name: 'Hack Night', distanceKm: 3.2),
          eventCard(7, name: 'Kochi Meetup', distanceKm: 178),
          eventCard(8, name: 'Online Hour', online: true),
        ])));
      await _pump(tester, repo: repo);

      expect(
          find.descendant(of: _rail('near'), matching: find.text('Hack Night')),
          findsOneWidget);
      expect(
          find.descendant(
              of: _rail('near'), matching: find.text('Kochi Meetup')),
          findsNothing);
      expect(
          find.descendant(
              of: _rail('near'), matching: find.text('Online Hour')),
          findsNothing);
    });

    testWidgets('clubs further than near are under More clubs, not near you',
        (tester) async {
      // What the server sends: the nearest few, however far.
      final repo = FakeDiscoverRepository()
        ..homeResult = Either.right(parseHome(homeBody(clubs: [
          clubCard(5, name: 'Tinkerhub', distanceKm: 2.1),
          clubCard(6, name: 'Borrow Checkers Kochi', distanceKm: 177.7),
          clubCard(7, name: 'Kandal Kootam', distanceKm: 414.9),
        ])));
      await _pump(tester, repo: repo);

      await _scrollTo(tester, find.text('CLUBS NEAR YOU'));
      expect(
          find.descendant(
              of: _rail('clubs'),
              matching: find.byKey(const ValueKey('discover-club-club-5'))),
          findsOneWidget);
      expect(
          find.descendant(
              of: _rail('clubs'),
              matching: find.byKey(const ValueKey('discover-club-club-6'))),
          findsNothing);
      await _scrollTo(tester, find.text('MORE CLUBS'));
      expect(
          find.descendant(
              of: _rail('more-clubs'),
              matching: find.byKey(const ValueKey('discover-club-club-6'))),
          findsOneWidget);
    });

    testWidgets('no club near: no "Clubs near you" at all', (tester) async {
      final repo = FakeDiscoverRepository()
        ..homeResult = Either.right(parseHome(homeBody(clubs: [
          clubCard(6, name: 'Borrow Checkers Kochi', distanceKm: 1074.4),
        ])));
      await _pump(tester, repo: repo);

      await _scrollTo(tester, find.text('MORE CLUBS'));
      expect(find.text('CLUBS NEAR YOU'), findsNothing);
    });

    testWidgets('not placed: no near rail, the clubs are the popular ones',
        (tester) async {
      final repo = FakeDiscoverRepository()
        ..homeResult = Either.right(parseHome(homeBody(
          where: whereNowhere,
          clubs: [clubCard(5, name: 'Tinkerhub')],
        )));
      await _pump(tester, repo: repo);
      expect(_rail('near'), findsNothing);
      await _scrollTo(tester, find.text('POPULAR CLUBS'));
      // Not placed: nothing near to offer.
      expect(find.byKey(const ValueKey('discover-quick-near')), findsNothing);
    });
  });
}
