import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/features/clubs/data/models/club_models.dart';
import 'package:finnet/features/clubs/presentation/pages/club_profile_page.dart'
    show ClubInfo;
import 'package:finnet/features/events/data/models/event_models.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';
import 'package:finnet/features/topics/data/models/topic_model.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_fixtures.dart';

void main() {
  group('/interests/list from production (no topic fields)', () {
    final topics = TopicModel.listFromJson(productionListBody);

    test('reads its one category with every interest', () {
      expect(topics, hasLength(1));
      final arts = topics.single;
      expect(arts.id, 1);
      expect(arts.name, 'arts');
      expect(arts.interests.map((i) => i.name),
          ['Coding', 'UI/UX', 'Photography', 'Music']);
    });

    test('makes a slug from the name, and capitals for the label', () {
      expect(topics.single.slug, 'arts');
      expect(topics.single.label, 'Arts');
    });

    test('leaves colour, order and counts unset', () {
      final arts = topics.single;
      expect(arts.color, isNull);
      expect(arts.sortOrder, isNull);
      expect(arts.upcomingEvents, isNull);
      expect(arts.clubs, isNull);
    });

    test('files each interest under the topic it was listed in', () {
      expect(topics.single.interests.map((i) => i.categoryId).toSet(), {1});
    });
  });

  group('/interests/list from the contract', () {
    final topics = TopicModel.listFromJson(contractListBody);

    test('orders topics by sort_order', () {
      expect(topics.map((t) => t.slug), ['development', 'arts', 'community']);
    });

    test('orders interests by sort_order inside each topic', () {
      final arts = topics.firstWhere((t) => t.slug == 'arts');
      expect(arts.interests.map((i) => i.name), ['Photography', 'Music']);
    });

    test('reads slug, colour, description and icon', () {
      final dev = topics.first;
      expect(dev.slug, 'development');
      expect(dev.color, '#2563EB');
      expect(dev.description, 'Build software');
      expect(dev.icon, '💻');
      expect(dev.iconType, 'emoji');
      expect(dev.label, 'Development');
    });

    test('reads interest slug, category and order', () {
      final web = topics.first.interests.first;
      expect(web.slug, 'web-development');
      expect(web.categoryId, 2);
      expect(web.sortOrder, 1);
    });

    test('keeps a topic with no interests', () {
      expect(topics.last.slug, 'community');
      expect(topics.last.interests, isEmpty);
    });
  });

  group('/interests/topics', () {
    final topics = TopicModel.listFromJson(contractTopicsBody);

    test('reads the counts', () {
      expect(topics.first.upcomingEvents, 12);
      expect(topics.first.clubs, 30);
      expect(topics.first.interests.first.upcomingEvents, 4);
    });

    test('an interest there without category_id is its topic\'s', () {
      expect(topics.first.interests.map((i) => i.categoryId).toSet(), {2});
    });
  });

  group('tolerance', () {
    test('a paginated envelope is read from items', () {
      expect(
        TopicModel.listFromJson({
          'items': [
            {'id': 1, 'name': 'Arts'},
          ],
        }),
        hasLength(1),
      );
    });

    test('anything without an id, or not an object, is skipped', () {
      expect(
        TopicModel.listFromJson([
          {'name': 'No id'},
          'junk',
          {'id': 3.0, 'name': 'Design'},
        ]).map((t) => t.id),
        [3],
      );
    });

    test('a body that is not a list reads as none', () {
      expect(TopicModel.listFromJson(null), isEmpty);
      expect(TopicModel.listFromJson('oops'), isEmpty);
    });

    test('slugify matches the server', () {
      expect(slugify('Gaming & Media'), 'gaming-media');
      expect(slugify(' Deep Tech '), 'deep-tech');
      expect(slugify('Sports & Fitness'), 'sports-fitness');
    });

    test('a topic answers to its slug or its id', () {
      const t = Topic(id: 5, slug: 'business', name: 'Business');
      expect(t.isNamedBy('business'), isTrue);
      expect(t.isNamedBy('BUSINESS'), isTrue);
      expect(t.isNamedBy('5'), isTrue);
      expect(t.isNamedBy('arts'), isFalse);
      expect(t.isNamedBy(''), isFalse);
    });
  });

  group('InterestModel', () {
    test('without the new fields', () {
      final i = InterestModel.fromJson(
              {'id': 6, 'name': 'Coding', 'icon': '💻', 'icon_type': 'emoji'})
          .toEntity();
      expect(i.id, 6);
      expect(i.slug, isNull);
      expect(i.categoryId, isNull);
      expect(i.sortOrder, isNull);
    });

    test('with them, numbers in any shape', () {
      final i = InterestModel.fromJson({
        'id': 6.0,
        'name': 'Coding',
        'slug': 'coding',
        'category_id': 2,
        'sort_order': 4.0,
      }).toEntity();
      expect(i.id, 6);
      expect(i.slug, 'coding');
      expect(i.categoryId, 2);
      expect(i.sortOrder, 4);
    });

    test('its own category_id wins over the topic it is listed in', () {
      final i = InterestModel.fromJson(
          {'id': 6, 'name': 'Coding', 'category_id': 2},
          categoryId: 9);
      expect(i.categoryId, 2);
    });
  });

  group('topics on events and clubs', () {
    const topicsJson = [
      {'id': 2, 'slug': 'development', 'name': 'Development', 'color': '#2563EB'},
      {'id': 4, 'slug': 'arts', 'name': 'Arts', 'color': '#EA580C'},
    ];

    test('declaredIn: absent is null, present is read in order', () {
      expect(TopicModel.declaredIn({'id': 1}), isNull);
      expect(TopicModel.declaredIn({'topics': null}), isNull);
      expect(TopicModel.declaredIn({'topics': []}), isEmpty);
      expect(
        TopicModel.declaredIn({'topics': topicsJson})!.map((t) => t.slug),
        ['development', 'arts'],
      );
    });

    test('an event from the app\'s models', () {
      final without = EventModel.fromJson({'id': 1, 'name': 'Talk'});
      expect(without.toEntity().topics, isNull);
      expect(without.toListItem().topics, isNull);

      final withTopics = EventModel.fromJson({
        'id': 1,
        'name': 'Talk',
        'interests': [
          {'id': 3, 'name': 'Web Development', 'category_id': 2},
        ],
        'topics': topicsJson,
      });
      final event = withTopics.toEntity();
      expect(event.topics!.map((t) => t.color), ['#2563EB', '#EA580C']);
      expect(event.interests.single.categoryId, 2);
      expect(withTopics.toListItem().topics, hasLength(2));
      expect(withTopics.toJson()['topics'], hasLength(2));
    });

    test('a club from the app\'s models', () {
      final without = ClubModel.fromJson({'id': 1, 'name': 'Tinkerhub'});
      expect(without.toEntity().topics, isNull);
      expect(without.toListItem().topics, isNull);

      final club = ClubModel.fromJson(
          {'id': 1, 'name': 'Tinkerhub', 'topics': topicsJson}).toEntity();
      expect(club.topics!.map((t) => t.name), ['Development', 'Arts']);
    });

    test('the event page\'s EventInfo', () {
      final info = EventInfo.fromJson({
        'id': 7,
        'interests': [
          {'id': 3, 'name': 'Web Development', 'category_id': 2},
          {'id': 15, 'name': 'Photography'},
        ],
      });
      expect(info.topics, isNull);
      expect(info.interests.first.toEntity().categoryId, 2);
      expect(info.interests.last.toEntity().categoryId, isNull);
      expect(info.interests.last.toEntity().icon, isNull);

      expect(
          EventInfo.fromJson({'id': 7, 'topics': topicsJson}).topics,
          hasLength(2));
    });

    test('the club page\'s ClubInfo', () {
      final info = ClubInfo.fromJson({
        'id': 5,
        'interests': [
          {'id': 3, 'name': 'Web Development', 'category_id': 2},
        ],
      });
      expect(info.topics, isNull);
      expect(info.interests.single.toEntity().categoryId, 2);
      expect(ClubInfo.fromJson({'id': 5, 'topics': topicsJson}).topics,
          hasLength(2));
    });
  });
}
