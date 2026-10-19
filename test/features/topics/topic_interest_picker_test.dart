import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_interest_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'topic_fixtures.dart';

/// Holds the selection the way a page does.
class _Harness extends StatefulWidget {
  final List<Topic> topics;
  final Set<int> initial;
  final int max;
  final VoidCallback? onLimit;

  const _Harness({
    required this.topics,
    this.initial = const {},
    this.max = 5,
    this.onLimit,
  });

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late final Set<int> selected = {...widget.initial};

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: TopicInterestPicker(
            topics: widget.topics,
            selectedIds: selected,
            maxSelected: widget.max,
            onLimitReached: widget.onLimit,
            onToggle: (Interest i) => setState(() {
              if (!selected.remove(i.id)) selected.add(i.id);
            }),
          ),
        ),
      ),
    );
  }
}

Finder _chip(int id) => find.byKey(ValueKey('interest-chip-$id'));
Finder _header(String slug) => find.byKey(ValueKey('topic-header-$slug'));
String _count(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('interest-count'))).data!;

void main() {
  testWidgets('one section per topic, its interests under it', (tester) async {
    await tester.pumpWidget(const _Harness(topics: catalogue));

    expect(_header('development'), findsOneWidget);
    expect(_header('deep-tech'), findsOneWidget);
    expect(_header('arts'), findsOneWidget);
    expect(find.text('Development'), findsOneWidget);
    for (final id in [3, 6, 13, 2, 22, 15, 16, 17]) {
      expect(_chip(id), findsOneWidget);
    }
    // Sections in the catalogue's order.
    final devY = tester.getTopLeft(_header('development')).dy;
    final artsY = tester.getTopLeft(_header('arts')).dy;
    expect(devY, lessThan(artsY));
    // Coding sits under Development, before Arts begins.
    expect(tester.getTopLeft(_chip(6)).dy, lessThan(artsY));
  });

  testWidgets(
      'with the one-topic server, no "arts" section: just the interests',
      (tester) async {
    await tester.pumpWidget(const _Harness(topics: productionCatalogue));

    expect(_header('arts'), findsNothing);
    expect(find.text('Arts'), findsNothing);
    for (final id in [6, 7, 15, 16]) {
      expect(_chip(id), findsOneWidget);
    }
    // The emoji is drawn with the name.
    expect(find.text('💻'), findsOneWidget);
  });

  testWidgets('search narrows across every topic', (tester) async {
    await tester.pumpWidget(const _Harness(topics: catalogue));

    await tester.enterText(
        find.byKey(const ValueKey('interest-search')), 'photo');
    await tester.pump();

    expect(_chip(15), findsOneWidget);
    expect(_chip(16), findsNothing);
    expect(_chip(6), findsNothing);
    expect(_header('arts'), findsOneWidget);
    expect(_header('development'), findsNothing);

    // A topic's name finds all of it.
    await tester.enterText(
        find.byKey(const ValueKey('interest-search')), 'deep tech');
    await tester.pump();
    expect(_chip(2), findsOneWidget);
    expect(_chip(22), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('interest-search')), 'zzz');
    await tester.pump();
    expect(find.text('No interests match "zzz".'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(_chip(3), findsOneWidget);
  });

  testWidgets('select and deselect, with the count', (tester) async {
    await tester.pumpWidget(const _Harness(topics: catalogue, initial: {16}));
    expect(_count(tester), '1 of 5 selected');
    expect(find.text('1 selected'), findsOneWidget); // under Arts

    await tester.tap(_chip(6));
    await tester.pump();
    expect(_count(tester), '2 of 5 selected');

    await tester.tap(_chip(16));
    await tester.pump();
    expect(_count(tester), '1 of 5 selected');
    expect(
      tester.getSemantics(_chip(6)),
      isSemantics(
        label: 'Coding, Development',
        isButton: true,
        isSelected: true,
        hasTapAction: true,
      ),
    );
    expect(
      tester.getSemantics(_chip(16)),
      isSemantics(isSelected: false),
    );
  });

  testWidgets('past the limit nothing more is chosen, and the page is told',
      (tester) async {
    var told = 0;
    await tester.pumpWidget(_Harness(
      topics: catalogue,
      initial: const {3, 6},
      max: 2,
      onLimit: () => told++,
    ));
    expect(_count(tester), '2 of 2 selected');

    await tester.tap(_chip(15));
    await tester.pump();

    expect(told, 1);
    expect(_count(tester), '2 of 2 selected');
    expect(
      tester.getSemantics(_chip(15)),
      isSemantics(isSelected: false, hint: 'Limit reached'),
    );

    // Taking one off makes room again.
    await tester.tap(_chip(3));
    await tester.pump();
    await tester.tap(_chip(15));
    await tester.pump();
    expect(_count(tester), '2 of 2 selected');
    expect(told, 1);
  });

  testWidgets('past the limit a chip fades, but never looks chosen',
      (tester) async {
    await tester.pumpWidget(const _Harness(
      topics: catalogue,
      initial: {3, 6},
      max: 2,
    ));

    BoxDecoration pill(int id) => tester
        .widget<AnimatedContainer>(find.descendant(
            of: _chip(id), matching: find.byType(AnimatedContainer)))
        .decoration! as BoxDecoration;
    double opacity(int id) => tester
        .widget<Opacity>(
            find.descendant(of: _chip(id), matching: find.byType(Opacity)))
        .opacity;

    expect(pill(15).color, AppColors.softGrey);
    expect(opacity(15), lessThan(1));
    expect(pill(6).color, AppColors.paleYellow);
    expect(opacity(6), 1);
  });

  testWidgets("a chip without the server's emoji has the app's",
      (tester) async {
    await tester.pumpWidget(const _Harness(topics: catalogue));

    // Web Development and Artificial Intelligence came without one.
    expect(find.descendant(of: _chip(3), matching: find.text('🌐')),
        findsOneWidget);
    expect(find.descendant(of: _chip(2), matching: find.text('🦾')),
        findsOneWidget);
  });

  testWidgets('section headers are headers to a screen reader', (tester) async {
    await tester.pumpWidget(const _Harness(topics: catalogue, initial: {6}));

    expect(
      tester.getSemantics(find
          .ancestor(
              of: _header('development'), matching: find.byType(Semantics))
          .first),
      isSemantics(isHeader: true, label: 'Development, 1 selected'),
    );
  });

  testWidgets('dark theme draws it without trouble', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: SingleChildScrollView(
          child: TopicInterestPicker(
            topics: catalogue,
            selectedIds: const {6},
            maxSelected: 5,
            onToggle: (_) {},
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(_chip(6), findsOneWidget);
  });
}
