import 'package:finnet/features/clubs/presentation/pages/explore_more_clubs_page.dart';
import 'package:finnet/features/events/presentation/pages/explore_events_page.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_fixtures.dart';

void main() {
  group('TopicFilter as interest_ids', () {
    test('no filter sends nothing', () {
      expect(TopicFilter.none.interestIds, isNull);
      expect(TopicFilter.none.queryParameters, isEmpty);
      expect(TopicFilter.none.isActive, isFalse);
    });

    test('a topic sends every interest under it', () {
      const f = TopicFilter(topic: development);
      expect(f.interestIds, [3, 6, 13]);
      expect(f.queryParameters, {'interest_ids': '3,6,13'});
      expect(f.label, 'Development');
    });

    test('an interest sends just itself', () {
      const f = TopicFilter(
          topic: development, interest: Interest(id: 6, name: 'Coding'));
      expect(f.queryParameters, {'interest_ids': '6'});
      expect(f.label, 'Coding');
    });

    test('a topic with no interests matches nothing, and asks nothing', () {
      const empty = TopicFilter(
          topic: Topic(id: 9, slug: 'community', name: 'Community'));
      expect(empty.matchesNothing, isTrue);
      expect(empty.queryParameters, isEmpty);
    });
  });

  group('TopicFilter.resolve', () {
    test('a topic by slug or by id', () {
      expect(TopicFilter.resolve(catalogue, topicRef: 'deep-tech').topic,
          deepTech);
      expect(TopicFilter.resolve(catalogue, topicRef: '4').topic, arts);
    });

    test('an interest brings its topic', () {
      final f = TopicFilter.resolve(catalogue, interestId: 22);
      expect(f.topic, deepTech);
      expect(f.interest!.name, 'Blockchain');
    });

    test('the interest wins when the two disagree', () {
      final f = TopicFilter.resolve(catalogue,
          topicRef: 'arts', interestId: 6);
      expect(f.topic, development);
      expect(f.interest!.id, 6);
    });

    test('names that match nothing are ignored', () {
      expect(
          TopicFilter.resolve(catalogue, topicRef: 'nope', interestId: 999),
          TopicFilter.none);
    });

    test('with the one-topic server there is no topic, only the interest', () {
      final f = TopicFilter.resolve(productionCatalogue,
          topicRef: 'arts', interestId: 7);
      expect(f.topic, isNull);
      expect(f.interest!.name, 'UI/UX');
      expect(f.queryParameters, {'interest_ids': '7'});
    });
  });

  group('the explore queries use only the endpoints\' own parameters', () {
    test('/events/list: upcoming, paged, filtered, searched', () {
      expect(exploreEventsQuery(), {
        'is_ended': false,
        'offset': 0,
        'limit': 10,
      });
      expect(
        exploreEventsQuery(
          filter: const TopicFilter(topic: development),
          search: '  react ',
          offset: 20,
        ),
        {
          'is_ended': false,
          'offset': 20,
          'limit': 10,
          'interest_ids': '3,6,13',
          'search': 'react',
        },
      );
      // No `topic` or `interest`: /events/list does not have them.
      final q = exploreEventsQuery(
          filter: const TopicFilter(topic: development));
      expect(q.containsKey('topic'), isFalse);
      expect(q.containsKey('interest'), isFalse);
    });

    test('/clubs/list: college, filter, search', () {
      expect(exploreClubsQuery(), isEmpty);
      expect(
        exploreClubsQuery(
          organizationId: 12,
          filter: const TopicFilter(
              topic: arts, interest: Interest(id: 16, name: 'Music')),
          search: 'band',
        ),
        {'org_id': 12, 'interest_ids': '16', 'search': 'band'},
      );
    });
  });
}
