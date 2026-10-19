import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:flutter_test/flutter_test.dart';

/// Production's `/interests/list` slugs: the default tree.
const _productionInterests = [
  'web-development',
  'app-development',
  'software-engineering',
  'coding',
  'open-source',
  'cloud-devops',
  'cybersecurity',
  'data-science',
  'artificial-intelligence',
  'robotics',
  'iot-hardware',
  'blockchain',
  'vr-ar',
  'quantum-computing',
  'space-exploration',
  'ui-ux',
  'graphic-design',
  'product-design',
  'animation',
  'drawing',
  'music',
  'singing',
  'dance',
  'theatre',
  'photography',
  'film',
  'writing',
  'fashion',
  'entrepreneurship',
  'product-management',
  'marketing',
  'finance',
  'analytics',
  'gaming',
  'e-sports',
  'content-creation',
  'memes-internet-culture',
  'volunteering',
  'sustainability',
  'public-speaking',
  'debate-mun',
  'quizzing',
  'sports',
  'fitness',
  'outdoors-adventure',
];

void main() {
  group("an interest without the server's emoji gets its slug's", () {
    for (final (icon, type) in [
      (null, null),
      ('', null),
      ('', 'emoji'),
      ('string', 'string'),
      ('string', 'emoji'),
      ('https://cdn.example/coding.png', 'url'),
    ]) {
      test('icon ${icon == null ? 'null' : '"$icon"'} ($type)', () {
        final coding = Interest(
            id: 6, name: 'Coding', slug: 'coding', icon: icon, iconType: type);
        expect(coding.emoji, '⌨️');
      });
    }

    test("the server's emoji wins", () {
      const coding = Interest(
          id: 6, name: 'Coding', slug: 'coding', icon: '💻', iconType: 'emoji');
      expect(coding.emoji, '💻');
    });

    test('a payload without a slug is matched by name', () {
      expect(const Interest(id: 30, name: 'Cloud & DevOps').emoji, '☁️');
      expect(const Interest(id: 7, name: 'UI/UX').emoji, '🎨');
      expect(interestEmoji(name: 'Memes & Internet Culture'), '😂');
    });

    test('an interest the app does not know has none', () {
      expect(const Interest(id: 99, name: 'Origami', slug: 'origami').emoji,
          isNull);
    });

    test(
        'every interest production lists has one, and the same as the '
        "backend's", () {
      expect(interestEmojiBySlug.keys, unorderedEquals(_productionInterests));
      expect(interestEmojiBySlug['artificial-intelligence'], '🦾');
      expect(interestEmojiBySlug['music'], '🥁');
      expect(interestEmojiBySlug['analytics'], '📉');
      expect(interestEmojiBySlug['outdoors-adventure'], '🏕️');
    });
  });

  group("a topic without the server's emoji gets its slug's", () {
    test('the eight of the default tree', () {
      expect(topicEmojiBySlug, {
        'development': '💻',
        'deep-tech': '🔬',
        'design': '🎨',
        'arts': '🎭',
        'business': '💼',
        'gaming-media': '🎮',
        'community': '🤝',
        'sports-fitness': '⚽',
      });
    });

    test("production's placeholder, or nothing at all", () {
      const arts = Topic(
          id: 1,
          slug: 'arts',
          name: 'arts',
          icon: 'string',
          iconType: 'string');
      expect(arts.emoji, '🎭');
      expect(
          const Topic(id: 5, slug: 'deep-tech', name: 'Deep Tech').emoji, '🔬');
    });

    test("the server's emoji wins", () {
      const sports = Topic(
          id: 10,
          slug: 'sports-fitness',
          name: 'Sports & Fitness',
          icon: '🏏',
          iconType: 'emoji');
      expect(sports.emoji, '🏏');
    });
  });
}
