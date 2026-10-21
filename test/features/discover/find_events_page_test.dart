import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/data/repositories/discover_repository_impl.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/presentation/discover_routes.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../topics/topic_fixtures.dart';
import 'discover_fakes.dart';
import 'discover_fixtures.dart';

class _Harness {
  _Harness(this.repo, this.router, this.went);
  final FakeDiscoverRepository repo;
  final GoRouter router;
  final List<String> went;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  String location = '/discover/events',
  FakeDiscoverRepository? repo,
  bool signedIn = false,
}) async {
  tallScreen(tester);
  final r = repo ?? FakeDiscoverRepository();
  final went = <String>[];
  final router = GoRouter(initialLocation: location, routes: [
    ...discoverRoutes,
    GoRoute(
      path: '/events/:id',
      builder: (_, s) {
        went.add(s.uri.toString());
        return Scaffold(
            appBar: AppBar(), body: Text('event ${s.pathParameters['id']}'));
      },
    ),
    GoRoute(
      path: '/clubs/:id',
      builder: (_, s) {
        went.add(s.uri.toString());
        return const Scaffold(body: Text('club'));
      },
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      discoverRepositoryProvider.overrideWithValue(r),
      // Signed out unless a test says otherwise: these screens need no one.
      isAuthenticatedProvider.overrideWithValue(signedIn),
      topicDirectoryProvider.overrideWith((ref) => Stream.value(catalogue)),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await settle(tester);
  return _Harness(r, router, went);
}

EventFilters _last(FakeDiscoverRepository repo) => repo.eventCalls.last.$1;

void main() {
  testWidgets('signed out: the events, counted; a row opens the event',
      (tester) async {
    final h = await _pump(tester);

    expect(find.text('Hack Night'), findsOneWidget);
    expect(find.text('Design Jam'), findsOneWidget);
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('discover-events-count')))
            .textSpan!
            .toPlainText(),
        '2 events');
    // Everywhere, from the first page.
    expect(h.repo.eventCalls.single.$1, EventFilters.none);
    expect(h.repo.eventCalls.single.$2, const PageRequest.first());

    await tester.tap(find.byKey(const ValueKey('discover-event-1')));
    await settle(tester);
    expect(h.went, ['/events/1']);
  });

  testWidgets('filters from the address are chips; a chip takes itself off',
      (tester) async {
    final h = await _pump(tester,
        location:
            '/discover/events?when=this_week&price=free&topic=development&interest=6');

    final first = _last(h.repo);
    expect([first.when, first.price, first.topic, first.interest],
        [EventWhen.thisWeek, EventPrice.free, 'development', 6]);
    expect(find.byKey(const ValueKey('filter-chip-when')), findsOneWidget);
    expect(find.text('This week'), findsWidgets);
    expect(find.text('Development'), findsWidgets);
    // The topic's interests, with the chosen one on.
    expect(
        find.byKey(const ValueKey('discover-interest-chips')), findsOneWidget);

    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('filter-chip-price')),
        matching: find.byIcon(Icons.close)));
    await settle(tester);

    final next = _last(h.repo);
    expect(next.price, isNull);
    expect(next.when, EventWhen.thisWeek);
    expect(find.byKey(const ValueKey('filter-chip-price')), findsNothing);

    // Removing the topic takes its interest with it.
    await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('filter-chip-topic')),
        matching: find.byIcon(Icons.close)));
    await settle(tester);
    expect([_last(h.repo).topic, _last(h.repo).interest], [null, null]);
  });

  testWidgets('the sheet edits a draft; Show results applies it',
      (tester) async {
    final h = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('discover-filters')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sheet-price-free')));
    await tester.tap(find.byKey(const ValueKey('sheet-format-online')));
    await tester.tap(find.byKey(const ValueKey('sheet-when-thisWeekend')));
    await tester.pump();
    // Nothing is asked until it is applied.
    expect(h.repo.eventCalls, hasLength(1));

    await tester.tap(find.byKey(const ValueKey('sheet-apply')));
    await settle(tester);

    final f = _last(h.repo);
    expect([f.price, f.format, f.when],
        [EventPrice.free, EventFormat.online, EventWhen.thisWeekend]);
    expect(find.text('Filters (3)'), findsOneWidget);
    expect(find.byKey(const ValueKey('filter-chip-format')), findsOneWidget);
  });

  testWidgets('closing the sheet changes nothing', (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('discover-filters')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sheet-price-paid')));
    await tester.tapAt(const Offset(10, 10)); // the scrim
    await settle(tester);
    expect(h.repo.eventCalls, hasLength(1));
    expect(find.byKey(const ValueKey('filter-chip-price')), findsNothing);
  });

  testWidgets('back from an event finds the filters as they were',
      (tester) async {
    final h = await _pump(tester, location: '/discover/events?price=paid');
    await tester.enterText(
        find.byKey(const ValueKey('discover-search')), 'robots');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    final calls = h.repo.eventCalls.length;
    expect(_last(h.repo).q, 'robots');

    await tester.tap(find.byKey(const ValueKey('discover-event-1')));
    await settle(tester);
    expect(find.text('event 1'), findsOneWidget);

    h.router.pop();
    await settle(tester);

    expect(find.byKey(const ValueKey('filter-chip-price')), findsOneWidget);
    expect(find.text('robots'), findsOneWidget);
    // The list was kept, not asked for again.
    expect(h.repo.eventCalls, hasLength(calls));
  });

  testWidgets('the order: relevance only with words, distance only near',
      (tester) async {
    final h = await _pump(tester);
    await tester.tap(find.byKey(const ValueKey('discover-sort')));
    await settle(tester);

    expect(find.byKey(const ValueKey('discover-sort-relevance')), findsNothing);
    final distance = tester.widget<PopupMenuItem<EventSort>>(
        find.byKey(const ValueKey('discover-sort-distance')));
    expect(distance.enabled, isFalse);

    await tester.tap(find.byKey(const ValueKey('discover-sort-popular')));
    await settle(tester);
    expect(_last(h.repo).sort, EventSort.popular);
  });

  testWidgets('near is by connection: the server names the city',
      (tester) async {
    final h = await _pump(tester);
    expect(find.text('Everywhere'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('discover-where')));
    await settle(tester);
    expect(find.text('We guessed Thiruvananthapuram from your connection.'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('discover-where-near')));
    await settle(tester);

    final f = _last(h.repo);
    expect(f.place, DiscoverPlace.near);
    expect(f.eventsQuery().containsKey('radius_km'), isFalse);
    expect(find.text('Near Thiruvananthapuram'), findsOneWidget);
  });

  testWidgets("near, but the server couldn't place anyone: not called near",
      (tester) async {
    // Without a place the server drops the radius: the list is everything.
    final repo = FakeDiscoverRepository()
      ..onEvents = (_, __) => Either.right(parseEventResults(eventsPage([
            eventCard(1, name: 'Hack Night'),
            eventCard(2, name: 'Design Jam'),
          ], where: whereNowhere)));
    await _pump(tester, repo: repo, location: '/discover/events?near=1');

    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('discover-events-count')))
            .textSpan!
            .toPlainText(),
        '2 events');
    expect(find.text('Near you'), findsNothing);
    expect(find.text('Everywhere'), findsOneWidget);
  });

  testWidgets('nothing near the place: says where, and offers everywhere',
      (tester) async {
    final repo = FakeDiscoverRepository()
      ..onEvents = (f, __) => Either.right(parseEventResults(eventsPage(
          f.isNear
              ? const []
              : [eventCard(3, name: 'Rust Webinar', online: true)],
          where: {...whereTvm, 'city': 'Mumbai'})));
    final h =
        await _pump(tester, repo: repo, location: '/discover/events?near=1');

    expect(find.text('NOTHING NEAR MUMBAI YET'), findsOneWidget);
    await tester.tap(find.text('Show everywhere'));
    await settle(tester);

    expect(_last(h.repo).place, DiscoverPlace.everywhere);
    expect(find.text('Rust Webinar'), findsOneWidget);
  });

  testWidgets('nothing matches: a way to clear the filters', (tester) async {
    final repo = FakeDiscoverRepository()
      ..onEvents = (f, __) => Either.right(parseEventResults(eventsPage(
          f.activeCount > 0 ? const [] : [eventCard(1, name: 'Hack Night')])));
    final h = await _pump(tester,
        repo: repo, location: '/discover/events?price=paid');

    expect(find.byKey(const ValueKey('discover-events-empty')), findsOneWidget);
    await tester.tap(find.text('Clear search and filters'));
    await settle(tester);

    expect(_last(h.repo).price, isNull);
    expect(find.text('Hack Night'), findsOneWidget);
  });

  testWidgets('offline with nothing saved: an error and a retry',
      (tester) async {
    final repo = FakeDiscoverRepository()
      ..onEvents = (_, __) => Either.left(offline);
    await _pump(tester, repo: repo);

    expect(find.text('Try Again'), findsOneWidget);
    repo.onEvents = (_, __) => Either.right(
        parseEventResults(eventsPage([eventCard(1, name: 'Back')])));
    await tester.tap(find.text('Try Again'));
    await settle(tester);
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('the next page follows the cursor as the list scrolls',
      (tester) async {
    final repo = FakeDiscoverRepository()
      ..onEvents = (_, page) => Either.right(parseEventResults(page.isFirst
          ? eventsPage([eventCard(1)], total: 2, nextCursor: 'c1')
          : eventsPage([eventCard(2, name: 'Second page')], total: 2)));
    await _pump(tester, repo: repo);

    expect(repo.eventCalls.map((c) => c.$2),
        [const PageRequest.first(), const PageRequest.after('c1')]);
    expect(find.text('Second page'), findsOneWidget);
  });

  group('the calendar', () {
    FakeDiscoverRepository busy() => FakeDiscoverRepository()
      ..onCalendar = (_, month) => Either.right(CalendarMonth(
            month: month,
            days: month == '2030-10'
                ? const {'2030-10-24': 2, '2030-10-25': 1}
                : const {},
          ));

    testWidgets('dots on busy days; the first busy day lists its events',
        (tester) async {
      final h = await _pump(tester,
          repo: busy(),
          location: '/discover/events?view=calendar&month=2030-10&price=free');

      expect(find.byKey(const ValueKey('discover-calendar')), findsOneWidget);
      expect(h.repo.calendarCalls.single.$2, '2030-10');
      expect(h.repo.calendarCalls.single.$1.price, EventPrice.free);
      expect(find.byKey(const ValueKey('calendar-dot-2030-10-24')),
          findsOneWidget);
      expect(find.byKey(const ValueKey('calendar-dot-2030-10-25')),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('calendar-dot-2030-10-26')), findsNothing);

      final day = h.repo.eventCalls.last.$1;
      expect([day.from, day.to, day.price],
          ['2030-10-24', '2030-10-24', EventPrice.free]);
      expect(find.text('2 events'), findsOneWidget);
    });

    testWidgets('a tapped day lists that day; the arrows change month',
        (tester) async {
      final h = await _pump(tester,
          repo: busy(),
          location: '/discover/events?view=calendar&month=2030-10');

      await tester.tap(find.byKey(const ValueKey('calendar-day-2030-10-25')));
      await settle(tester);
      expect(h.repo.eventCalls.last.$1.from, '2030-10-25');

      await tester.tap(find.byKey(const ValueKey('calendar-next')));
      await settle(tester);
      expect(h.repo.calendarCalls.last.$2, '2030-11');
      expect(find.text('NOTHING ON IN NOVEMBER'), findsOneWidget);
    });

    testWidgets('the toggle switches between list and calendar',
        (tester) async {
      final h = await _pump(tester, repo: busy());
      expect(
          find.byKey(const ValueKey('discover-events-list')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('discover-view-toggle')));
      await settle(tester);
      expect(find.byKey(const ValueKey('discover-calendar')), findsOneWidget);
      expect(h.repo.calendarCalls, isNotEmpty);
    });
  });
}
