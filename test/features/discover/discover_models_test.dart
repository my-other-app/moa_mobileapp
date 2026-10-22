import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:flutter_test/flutter_test.dart';

import 'discover_fixtures.dart';

void main() {
  test('an event card reads every field it shows', () {
    final e = parseEvent(eventCard(7,
        hasFee: true, fee: 250, status: 'closing_soon', distanceKm: 4.4))!;
    expect(e.id, 7);
    expect(e.startsAt, DateTime.utc(2030, 10, 24, 12, 30));
    expect(e.hasFee, isTrue);
    expect(e.fee, 250);
    expect(e.status, DiscoverEventStatus.closingSoon);
    expect(e.distanceKm, 4.4);
    expect(e.club!.name, 'Tinkerhub');
    expect(e.category!.name, 'Workshop');
    expect(e.topics.single.slug, 'development');
  });

  test('odd fields fall back rather than lose the row', () {
    final e = parseEvent({
      'id': '9',
      'name': null,
      'starts_at': 'whenever',
      'fee': 0,
      'going': -4,
      'status': 'sold_out',
      'club': 'not an object',
      'topics': 'none',
    })!;
    expect(e.id, 9);
    expect(e.name, 'Untitled event');
    expect(e.startsAt, isNull);
    expect(e.fee, isNull);
    expect(e.going, 0);
    expect(e.status, DiscoverEventStatus.upcoming);
    expect(e.club, isNull);
    expect(e.topics, isEmpty);
  });

  test('a row without an id is dropped, the list kept', () {
    final page = parseEventResults(eventsPage([
      eventCard(1),
      {'name': 'no id'},
      eventCard(2)
    ]));
    expect(page.page.items.map((e) => e.id), [1, 2]);
  });

  test('a page knows whether the server pages by cursor', () {
    expect(
        parseEventResults(eventsPage([eventCard(1)], nextCursor: 'x'))
            .page
            .cursor,
        'x');
    final last = parseEventResults(eventsPage([eventCard(1)])).page;
    expect([last.cursored, last.cursor], [true, null]);
    expect(
        parseEventResults(eventsPage([eventCard(1)], cursored: false))
            .page
            .cursored,
        isFalse);
  });

  test('the facets', () {
    final page = parseEventResults(eventsPage(const []));
    expect(page.categories.map((c) => c.name), ['Workshop', 'Talk']);
    expect(page.topics.first.upcoming, 12);
  });

  test('where: a city by connection, or nowhere', () {
    final w = parseWhere(whereTvm);
    expect(w.source, WhereSource.ip);
    expect(w.label, 'Near Thiruvananthapuram');
    expect(
        w.explanation, 'We guessed Thiruvananthapuram from your connection.');
    final none = parseWhere(whereNowhere);
    expect(none.isPlaced, isFalse);
    expect(none.label, 'Everywhere');
    expect(parseWhere(null), DiscoverWhere.unknown);
  });

  test('home: the rails, and which clubs are the near ones', () {
    final home = parseHome(homeBody());
    expect(home.thisWeek.single.name, 'Design Jam');
    expect(home.nearClubs.single.name, 'Tinkerhub');
    expect(home.moreClubs, isEmpty);
    expect(home.popularClubs, isEmpty);
    // Left out by an older server: null, so its clubs are split here.
    expect(home.clubsMore, isNull);
    expect(parseHome(homeBody(clubsMore: const [])).clubsMore, isEmpty);
    expect(
        parseHome(homeBody(clubsMore: [clubCard(6, distanceKm: 177.7)]))
            .moreClubs
            .single
            .distanceKm,
        177.7);
    expect(home.isEmpty, isFalse);
    expect(parseHome(emptyHomeBody()).isEmpty, isTrue);
    expect(parseHome(null).isEmpty, isTrue);
  });

  test('a club reads interests as names', () {
    final c = parseClub({
      'slug': 'robo',
      'interests': [
        'Coding',
        {'name': 'Robotics'},
        3,
        ''
      ],
    })!;
    expect(c.id, 0);
    expect(c.name, 'A club');
    expect(c.interests, ['Coding', 'Robotics']);
  });

  test('an event from /events/list (the following tab) as a card', () {
    final e = parseListEvent({
      'id': 4,
      'name': 'Robo Wars',
      'event_datetime': '2030-01-01T10:00:00Z',
      'duration': 2.5,
      'has_fee': true,
      'is_online': false,
      'location_name': 'CET',
      'club': {'id': 1, 'name': 'IEEE'},
      'category': {'id': 2, 'name': 'Competition'},
    })!;
    expect(e.startsAt, DateTime.utc(2030, 1, 1, 10));
    expect(e.endsAt, DateTime.utc(2030, 1, 1, 12, 30));
    expect(e.club!.name, 'IEEE');
  });

  test('a topic, or null for a body that is not one', () {
    expect(parseTopic(developmentTopicBody)!.clubs, 30);
    expect(parseTopic({'name': 'no id'}), isNull);
    expect(parseTopic([1, 2]), isNull);
  });
}
