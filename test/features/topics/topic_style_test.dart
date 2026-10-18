import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('an icon is drawn as text only when it is an emoji', () {
    test('an emoji the server calls one', () {
      expect(interestGlyph('💻', 'emoji'), '💻');
      expect(interestGlyph(' 🎨 ', 'emoji'), '🎨');
    });

    test('never a word, a URL or an untyped icon', () {
      // Production's topic carries the placeholder "string".
      expect(interestGlyph('string', 'string'), isNull);
      expect(interestGlyph('string', 'emoji'), isNull);
      expect(interestGlyph('string', null), isNull);
      expect(interestGlyph('abc', 'emoji'), isNull);
      expect(interestGlyph('url', 'url'), isNull);
      expect(interestGlyph('https://cdn.example/icon.png', 'url'), isNull);
      expect(interestGlyph('💻', 'url'), isNull);
      expect(interestGlyph('💻', null), isNull);
      expect(interestGlyph('', 'emoji'), isNull);
      expect(interestGlyph(null, 'emoji'), isNull);
    });

    for (final (icon, type) in [
      ('string', 'string'),
      ('string', null),
      ('abc', 'emoji'),
      ('https://cdn.example/a.png', 'url'),
    ]) {
      testWidgets('a topic with icon "$icon" ($type) gets the built-in icon',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: TopicIcon(
            topic: Topic(
              id: 1,
              slug: 'arts',
              name: 'arts',
              icon: icon,
              iconType: type,
            ),
          ),
        ));

        expect(find.text(icon), findsNothing);
        expect(find.byIcon(Icons.palette_outlined), findsOneWidget);
      });
    }

    testWidgets('an emoji topic draws its emoji', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: TopicIcon(
          topic: Topic(
            id: 2,
            slug: 'development',
            name: 'Development',
            icon: '💻',
            iconType: 'emoji',
          ),
        ),
      ));

      expect(find.text('💻'), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
    });
  });

  test('colours: the server\'s, else the default for the slug', () {
    expect(parseHexColor('#2563EB'), const Color(0xFF2563EB));
    expect(parseHexColor('2563eb'), const Color(0xFF2563EB));
    expect(parseHexColor('#abc'), const Color(0xFFAABBCC));
    expect(parseHexColor('blue'), isNull);
    expect(
      topicColor(const Topic(id: 1, slug: 'arts', name: 'arts')),
      const Color(0xFFEA580C),
    );
    expect(
      topicColor(const Topic(
          id: 1, slug: 'arts', name: 'Arts', color: '#123456')),
      const Color(0xFF123456),
    );
  });
}
