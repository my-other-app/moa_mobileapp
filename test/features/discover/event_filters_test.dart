import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the events query', () {
    test('no filters: everywhere (radius 0), the first page', () {
      expect(EventFilters.none.eventsQuery(), {
        'radius_km': 0,
        'offset': 0,
        'limit': discoverPageSize,
      });
    });

    test('every filter goes as the API names it', () {
      const filters = EventFilters(
        q: '  rust  ',
        when: EventWhen.thisWeek,
        format: EventFormat.online,
        price: EventPrice.free,
        category: 2,
        topic: 'Development',
        interest: 6,
        sort: EventSort.popular,
      );
      expect(filters.eventsQuery(), {
        'q': 'rust',
        'category': 2,
        'topic': 'development',
        'interest': 6,
        'type': 'online',
        'price': 'free',
        'radius_km': 0,
        'when': 'this_week',
        'sort': 'popular',
        'offset': 0,
        'limit': discoverPageSize,
      });
    });

    test('picked days replace "when", put in order', () {
      const filters = EventFilters(
          when: EventWhen.today, from: '2026-11-03', to: '2026-11-01');
      final q = filters.eventsQuery();
      expect(q['from'], '2026-11-01');
      expect(q['to'], '2026-11-03');
      expect(q.containsKey('when'), isFalse);
    });

    test('a span over a year, or a day that is not one, is dropped', () {
      expect(
          const EventFilters(from: '2026-01-01', to: '2027-06-01')
              .eventsQuery()
              .containsKey('from'),
          isFalse);
      expect(
          const EventFilters(from: '2026-02-30')
              .eventsQuery()
              .containsKey('from'),
          isFalse);
      // One end alone is that day.
      final one = const EventFilters(from: '2026-11-05').eventsQuery();
      expect([one['from'], one['to']], ['2026-11-05', '2026-11-05']);
    });

    test('near the person: no point, and the radius only when picked', () {
      const near = EventFilters(place: DiscoverPlace.near);
      expect(near.eventsQuery().containsKey('radius_km'), isFalse);
      expect(near.eventsQuery().containsKey('lat'), isFalse);
      expect(near.copyWith(radiusKm: 25).eventsQuery()['radius_km'], 25);
      // A radius that is not offered is dropped.
      expect(near.copyWith(radiusKm: 30).eventsQuery().containsKey('radius_km'),
          isFalse);
    });

    test('everywhere drops a radius and an order by distance', () {
      final f = const EventFilters(place: DiscoverPlace.near)
          .copyWith(radiusKm: 10, sort: EventSort.distance)
          .withPlace(DiscoverPlace.everywhere);
      expect(f.radiusKm, isNull);
      expect(f.sort, isNull);
      expect(f.eventsQuery()['radius_km'], 0);
    });

    test('relevance only with words', () {
      expect(const EventFilters(sort: EventSort.relevance).normalized().sort,
          isNull);
      expect(
          const EventFilters(q: 'ai', sort: EventSort.relevance)
              .normalized()
              .sort,
          EventSort.relevance);
    });

    test('search words are cut to what the server takes', () {
      final long = 'a' * 150;
      expect(EventFilters(q: long).eventsQuery()['q'], 'a' * 100);
    });

    test('a bad topic slug is dropped rather than sent', () {
      expect(
          const EventFilters(topic: 'not a slug!')
              .eventsQuery()
              .containsKey('topic'),
          isFalse);
    });

    test('a later page goes by cursor, with no offset', () {
      final q = EventFilters.none.eventsQuery(const PageRequest.after('abc'));
      expect(q['after'], 'abc');
      expect(q.containsKey('offset'), isFalse);
    });

    test('the calendar: the month and the filters, without when or order', () {
      const filters = EventFilters(
        when: EventWhen.today,
        sort: EventSort.popular,
        price: EventPrice.paid,
        topic: 'arts',
      );
      expect(filters.calendarQuery('2026-11'), {
        'month': '2026-11',
        'topic': 'arts',
        'price': 'paid',
        'radius_km': 0,
      });
    });
  });

  group('the filter state', () {
    test('a "when" preset takes picked days off, and the other way', () {
      final days = EventFilters.none.withDays('2026-11-01', '2026-11-02');
      expect(days.activeKeys, [EventFilterKey.dates]);
      final preset = days.withWhen(EventWhen.today);
      expect(preset.activeKeys, [EventFilterKey.when]);
      expect(preset.from, isNull);
    });

    test('chips, in order; removing one leaves the rest', () {
      const filters = EventFilters(
        q: 'jam',
        when: EventWhen.thisWeekend,
        price: EventPrice.free,
        topic: 'development',
        interest: 6,
        sort: EventSort.date,
      );
      expect(filters.activeKeys, [
        EventFilterKey.when,
        EventFilterKey.price,
        EventFilterKey.topic,
        EventFilterKey.interest,
      ]);
      expect(filters.activeCount, 4);
      final noPrice = filters.without(EventFilterKey.price);
      expect(noPrice.price, isNull);
      expect(noPrice.when, EventWhen.thisWeekend);
    });

    test('removing the topic takes its interest with it', () {
      const filters = EventFilters(topic: 'development', interest: 6);
      final f = filters.without(EventFilterKey.topic);
      expect([f.topic, f.interest], [null, null]);
      expect(filters.withTopic('arts').interest, isNull);
    });

    test('clear keeps the words, the order and the place', () {
      const filters = EventFilters(
        q: 'jam',
        price: EventPrice.paid,
        format: EventFormat.inPerson,
        sort: EventSort.popular,
        place: DiscoverPlace.near,
        radiusKm: 25,
      );
      final f = filters.cleared();
      expect(f.activeCount, 0);
      expect([f.q, f.sort, f.place],
          ['jam', EventSort.popular, DiscoverPlace.near]);
    });

    test('a calendar day is the same search for that day', () {
      const filters = EventFilters(
          when: EventWhen.thisMonth,
          sort: EventSort.popular,
          price: EventPrice.free);
      final day = filters.forDay('2026-11-14');
      expect([day.from, day.to, day.when, day.sort],
          ['2026-11-14', '2026-11-14', null, null]);
      expect(day.price, EventPrice.free);
    });

    test('equal filters are equal (one list per set)', () {
      expect(const EventFilters(q: ' x ').normalized(),
          const EventFilters(q: 'x').normalized());
    });
  });

  group('the address', () {
    test('round trips', () {
      const filters = EventFilters(
        q: 'robots',
        from: '2026-11-01',
        to: '2026-11-07',
        format: EventFormat.inPerson,
        price: EventPrice.paid,
        category: 5,
        topic: 'deep-tech',
        interest: 22,
        sort: EventSort.distance,
        radiusKm: 50,
        place: DiscoverPlace.near,
      );
      final params = filters.toParams();
      expect(params, {
        'q': 'robots',
        'from': '2026-11-01',
        'to': '2026-11-07',
        'type': 'in_person',
        'price': 'paid',
        'category': '5',
        'topic': 'deep-tech',
        'interest': '22',
        'sort': 'distance',
        'radius_km': '50',
        'near': '1',
      });
      expect(EventFilters.fromParams(params), filters.normalized());
    });

    test('anything unknown is dropped', () {
      final f = EventFilters.fromParams({
        'when': 'someday',
        'type': 'hybrid',
        'price': 'cheap',
        'category': 'abc',
        'interest': '-3',
        'radius_km': '7',
        'sort': 'loudest',
      });
      expect(f, EventFilters.none);
    });

    test("the website's near=lat,lng and sort=distance mean near the person",
        () {
      expect(EventFilters.fromParams({'near': '8.52,76.94'}).isNear, isTrue);
      final f = EventFilters.fromParams({'sort': 'distance'});
      expect([f.isNear, f.sort], [true, EventSort.distance]);
    });

    test('locationWith builds the screen address', () {
      expect(locationWith('/discover/events', const {}), '/discover/events');
      expect(
          locationWith('/discover/events',
              const EventFilters(when: EventWhen.thisWeek).toParams()),
          '/discover/events?when=this_week');
    });
  });

  group('the sort choices', () {
    test('relevance with words; distance switched off everywhere', () {
      expect(eventSortChoices(EventFilters.none), [
        (EventSort.date, true),
        (EventSort.distance, false),
        (EventSort.popular, true),
      ]);
      expect(
          eventSortChoices(
                  const EventFilters(q: 'x', place: DiscoverPlace.near))
              .map((c) => c.$1),
          [
            EventSort.relevance,
            EventSort.date,
            EventSort.distance,
            EventSort.popular
          ]);
    });
  });

  group('the clubs query', () {
    test('defaults: everywhere, popular left to the server', () {
      expect(const ClubFilters(sort: ClubSort.popular).clubsQuery(), {
        'radius_km': 0,
        'offset': 0,
        'limit': discoverPageSize,
      });
    });

    test('nearby needs near; topic, interest and radius go along', () {
      expect(
          const ClubFilters(sort: ClubSort.nearby).normalized().sort, isNull);
      const near = ClubFilters(
        q: 'robo',
        topic: 'deep-tech',
        interest: 2,
        sort: ClubSort.nearby,
        radiusKm: 25,
        place: DiscoverPlace.near,
      );
      expect(near.clubsQuery(const PageRequest.after('c2')), {
        'q': 'robo',
        'topic': 'deep-tech',
        'interest': 2,
        'radius_km': 25,
        'sort': 'nearby',
        'after': 'c2',
        'limit': discoverPageSize,
      });
    });

    test('chips and the address', () {
      const f = ClubFilters(topic: 'arts', interest: 15, sort: ClubSort.newest);
      expect(f.activeKeys, [ClubFilterKey.topic, ClubFilterKey.interest]);
      expect(f.without(ClubFilterKey.topic).interest, isNull);
      expect(ClubFilters.fromParams(f.toParams()), f.normalized());
      expect(ClubFilters.fromParams({'sort': 'nearby'}).isNear, isTrue);
    });
  });
}
