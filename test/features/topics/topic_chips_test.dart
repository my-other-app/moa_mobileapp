import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/topic_filter.dart';
import 'package:finnet/features/topics/presentation/widgets/interest_tags.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_filter_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_fixtures.dart';

/// The pill under [finder].
BoxDecoration _pill(WidgetTester tester, Finder finder) => tester
    .widget<AnimatedContainer>(find
        .descendant(of: finder, matching: find.byType(AnimatedContainer))
        .first)
    .decoration! as BoxDecoration;

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: child)),
    ));

void main() {
  group('the explore filters, in the Interests look', () {
    testWidgets('the chosen topic and interest: yellow with an ink edge',
        (tester) async {
      await _pump(
        tester,
        TopicFilterBar(
          topics: catalogue,
          filter: TopicFilter(
              topic: development, interest: development.interests[1]),
          onChanged: (_) {},
        ),
      );

      final topic = find.byKey(const ValueKey('topic-chip-development'));
      expect(_pill(tester, topic).color, AppColors.paleYellow);
      expect((_pill(tester, topic).border! as Border).top.color, AppColors.ink);
      final other = find.byKey(const ValueKey('topic-chip-arts'));
      expect(_pill(tester, other).color, AppColors.softGrey);
      expect(find.descendant(of: topic, matching: find.text('💻')),
          findsOneWidget);
      // Arts came without an emoji: its slug's.
      expect(find.descendant(of: other, matching: find.text('🎭')),
          findsOneWidget);

      final coding = find.byKey(const ValueKey('interest-filter-6'));
      expect(_pill(tester, coding).color, AppColors.paleYellow);
      // Each interest its emoji. An icon without `icon_type: emoji` is not
      // trusted, so Coding has the app's emoji for its name.
      expect(find.descendant(of: coding, matching: find.text('⌨️')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('interest-filter-3')),
              matching: find.text('🌐')),
          findsOneWidget);
    });

    testWidgets('"All" and the college, in the same look', (tester) async {
      await _pump(
        tester,
        TopicFilterBar(
          topics: catalogue,
          filter: TopicFilter.none,
          leading: [
            PlainFilterChip(label: 'IIT Madras', selected: true, onTap: () {}),
          ],
          onChanged: (_) {},
        ),
      );

      expect(
          _pill(tester, find.byKey(const ValueKey('topic-filter-all'))).color,
          AppColors.paleYellow);
      expect(_pill(tester, find.byType(PlainFilterChip)).color,
          AppColors.paleYellow);
    });
  });

  testWidgets('interest tags: each its emoji and name on a pastel',
      (tester) async {
    await _pump(
      tester,
      const InterestTags(interests: [
        Interest(id: 3, name: 'Web Development', slug: 'web-development'),
        Interest(id: 16, name: 'Music', icon: '🎵', iconType: 'emoji'),
        Interest(id: 99, name: 'Origami'),
      ]),
    );

    expect(find.byType(InterestTag), findsNWidgets(3));
    expect(find.text('🌐'), findsOneWidget);
    expect(find.text('🎵'), findsOneWidget);
    // One the app does not know: just its name.
    expect(
        find.descendant(
            of: find.widgetWithText(InterestTag, 'Origami'),
            matching: find.byType(Text)),
        findsOneWidget);
    final colours = [
      for (final tag
          in tester.widgetList<InterestTag>(find.byType(InterestTag)))
        tag.color,
    ];
    expect(colours, InterestTag.pastels.take(3).toList());
  });
}
