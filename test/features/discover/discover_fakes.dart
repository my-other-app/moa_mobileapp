import 'dart:async';

import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/discover/domain/repositories/discover_repository.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'discover_fixtures.dart';

const offline = NetworkFailure(message: 'No internet connection.');

/// Answers as the server would, from the fixtures; every call is kept.
class FakeDiscoverRepository implements DiscoverRepository {
  Result<DiscoverHome> homeResult = Either.right(parseHome(homeBody()));
  DiscoverHome? savedHomeValue;

  /// Held until completed: the screen stays loading.
  Completer<void>? hold;

  Result<EventResults> Function(EventFilters, PageRequest) onEvents =
      (_, __) => Either.right(parseEventResults(eventsPage([
            eventCard(1, name: 'Hack Night'),
            eventCard(2, name: 'Design Jam'),
          ])));
  Result<CalendarMonth> Function(EventFilters, String) onCalendar =
      (_, month) => Either.right(CalendarMonth(month: month));
  Result<ClubResults> Function(ClubFilters, PageRequest) onClubs =
      (_, __) => Either.right(parseClubResults(clubsPage([
            clubCard(1, name: 'Tinkerhub'),
            clubCard(2, name: 'IEEE SB'),
          ])));
  Result<DiscoverPage<Thread>> Function(PageRequest) onThreads =
      (_) => Either.right(parseThreadsPage(threadsPage([threadOut('t-1')])));
  Result<Topic> Function(String) onTopic =
      (slug) => Either.right(parseTopic(developmentTopicBody)!);
  Result<List<DiscoverEvent>> following = Either.right([
    parseListEvent({
      'id': 50,
      'name': 'Followed Meetup',
      'event_datetime': '2030-01-01T10:00:00Z',
      'club': {'id': 9, 'name': 'GDG'},
    })!,
  ]);

  final homeCalls = <int>[];
  final eventCalls = <(EventFilters, PageRequest)>[];
  final calendarCalls = <(EventFilters, String)>[];
  final clubCalls = <(ClubFilters, PageRequest)>[];
  final threadCalls = <PageRequest>[];
  final topicCalls = <String>[];
  int followingCalls = 0;

  Future<void> _wait() async {
    final h = hold;
    if (h != null) await h.future;
  }

  @override
  Future<Result<DiscoverHome>> home() async {
    homeCalls.add(homeCalls.length);
    await _wait();
    return homeResult;
  }

  @override
  Future<DiscoverHome?> savedHome() async => savedHomeValue;

  @override
  Future<Result<EventResults>> events(
      EventFilters filters, PageRequest page) async {
    eventCalls.add((filters, page));
    await _wait();
    return onEvents(filters, page);
  }

  @override
  Future<EventResults?> savedEvents(EventFilters filters) async => null;

  @override
  Future<Result<CalendarMonth>> calendar(
      EventFilters filters, String month) async {
    calendarCalls.add((filters, month));
    await _wait();
    return onCalendar(filters, month);
  }

  @override
  Future<CalendarMonth?> savedCalendar(
          EventFilters filters, String month) async =>
      null;

  @override
  Future<Result<ClubResults>> clubs(
      ClubFilters filters, PageRequest page) async {
    clubCalls.add((filters, page));
    await _wait();
    return onClubs(filters, page);
  }

  @override
  Future<ClubResults?> savedClubs(ClubFilters filters) async => null;

  @override
  Future<Result<DiscoverPage<Thread>>> threads(PageRequest page) async {
    threadCalls.add(page);
    await _wait();
    return onThreads(page);
  }

  @override
  Future<DiscoverPage<Thread>?> savedThreads() async => null;

  @override
  Future<Result<Topic>> topic(String slug) async {
    topicCalls.add(slug);
    await _wait();
    return onTopic(slug);
  }

  @override
  Future<Topic?> savedTopic(String slug) async => null;

  @override
  Future<Result<List<DiscoverEvent>>> followingEvents({int limit = 10}) async {
    followingCalls++;
    await _wait();
    return following;
  }

  @override
  Future<List<DiscoverEvent>?> savedFollowingEvents({int limit = 10}) async =>
      null;
}

/// A few frames: the self-started loads finish and are drawn. Not
/// pumpAndSettle: the loading skeletons shimmer forever.
Future<void> settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// A tall phone, so lists show more than their first rows.
void tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
}

/// Tap [target] once it is on screen: scrolled into view along
/// [scrollable] (for a lazily built list), else by its nearest scrollables.
/// The test font draws every letter a full square, so rows of chips run
/// wider than a phone.
Future<void> tapVisible(
  WidgetTester tester,
  Finder target, {
  Finder? scrollable,
  double delta = 150,
}) async {
  if (scrollable != null) {
    await tester.scrollUntilVisible(target, delta, scrollable: scrollable);
  } else {
    await tester.ensureVisible(target);
  }
  await tester.pump();
  await tester.tap(target);
}

/// The scrollable inside the widget with [key].
Finder scrollableIn(String key) => find
    .descendant(
        of: find.byKey(ValueKey(key)), matching: find.byType(Scrollable))
    .first;
