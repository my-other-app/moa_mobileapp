import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_fixtures.dart';

void main() {
  group('resolveTopics', () {
    test('the payload\'s own topics win, even when empty', () {
      const declared = [Topic(id: 99, slug: 'x', name: 'X')];
      expect(
        resolveTopics(
          declared: declared,
          interests: const [Interest(id: 3, name: 'Web', categoryId: 2)],
          catalogue: catalogue,
        ),
        declared,
      );
      expect(
        resolveTopics(
          declared: const [],
          interests: const [Interest(id: 3, name: 'Web', categoryId: 2)],
          catalogue: catalogue,
        ),
        isEmpty,
      );
    });

    test('without them, from each interest\'s category_id', () {
      final topics = resolveTopics(
        interests: const [
          Interest(id: 900, name: 'Unlisted', categoryId: 4),
          Interest(id: 901, name: 'Unlisted too', categoryId: 2),
        ],
        catalogue: catalogue,
      );
      // In the catalogue's order, not the interests'.
      expect(topics.map((t) => t.slug), ['development', 'arts']);
    });

    test('without category_id, by where the catalogue lists the interest', () {
      final topics = resolveTopics(
        interests: const [
          Interest(id: 22, name: 'Blockchain'),
          Interest(id: 17, name: 'Film'),
        ],
        catalogue: catalogue,
      );
      expect(topics.map((t) => t.slug), ['deep-tech', 'arts']);
    });

    test('each topic once', () {
      final topics = resolveTopics(
        interests: const [
          Interest(id: 3, name: 'Web Development'),
          Interest(id: 6, name: 'Coding'),
          Interest(id: 13, name: 'Cybersecurity', categoryId: 2),
        ],
        catalogue: catalogue,
      );
      expect(topics, [development]);
    });

    test('a topic the catalogue does not know is left out', () {
      expect(
        resolveTopics(
          interests: const [
            Interest(id: 500, name: 'Mystery', categoryId: 77),
            Interest(id: 501, name: 'Unknown'),
          ],
          catalogue: catalogue,
        ),
        isEmpty,
      );
    });

    test('with no catalogue (it failed to load) there are none', () {
      expect(
        resolveTopics(
          interests: const [Interest(id: 3, name: 'Web', categoryId: 2)],
        ),
        isEmpty,
      );
    });
  });

  test('topicsWorthShowing: one topic holding everything is not a choice', () {
    expect(topicsWorthShowing(productionCatalogue), isFalse);
    expect(topicsWorthShowing(const []), isFalse);
    expect(topicsWorthShowing(catalogue), isTrue);
  });

  test('topicOfInterest and topicNamed', () {
    expect(topicOfInterest(22, catalogue), deepTech);
    expect(topicOfInterest(12345, catalogue), isNull);
    expect(topicNamed('arts', catalogue), arts);
    expect(topicNamed('3', catalogue), deepTech);
    expect(topicNamed(null, catalogue), isNull);
    expect(topicNamed('nope', catalogue), isNull);
  });

  test('interestsOf flattens, in topic order, each once', () {
    expect(interestsOf(catalogue).map((i) => i.id), [3, 6, 13, 2, 22, 15, 16, 17]);
  });

  group('searchTopics', () {
    test('an empty query keeps everything', () {
      expect(searchTopics(catalogue, '  '), catalogue);
    });

    test('matches interest names, any case, dropping empty topics', () {
      final found = searchTopics(catalogue, 'PHOTO');
      expect(found.map((t) => t.slug), ['arts']);
      expect(found.single.interests.map((i) => i.name), ['Photography']);
      // The topic keeps its looks.
      expect(found.single.color, '#EA580C');
    });

    test('a topic whose name matches keeps all its interests', () {
      final found = searchTopics(catalogue, 'deep');
      expect(found.single.interests, deepTech.interests);
    });

    test('nothing matching is nothing', () {
      expect(searchTopics(catalogue, 'zzz'), isEmpty);
    });
  });

  test('sortedByOrder keeps the server\'s order among equals and unordered', () {
    final items = [
      (name: 'c', order: null),
      (name: 'b', order: 2),
      (name: 'a', order: 1),
      (name: 'd', order: null),
      (name: 'e', order: 2),
    ];
    expect(
      sortedByOrder(items, (i) => i.order).map((i) => i.name),
      ['a', 'b', 'e', 'c', 'd'],
    );
  });
}
