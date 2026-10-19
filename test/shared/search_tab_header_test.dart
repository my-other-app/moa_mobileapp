import 'package:finnet/features/home/presentation/widgets/home_header.dart';
import 'package:finnet/shared/widgets/search_tab_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The main tabs' header: the search box and the tabs on one gutter, the
// tabs in equal shares of the row, at any text size.

class _Header extends StatefulWidget {
  const _Header({required this.titles});

  final List<String> titles;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> with TickerProviderStateMixin {
  late final controller =
      TabController(length: widget.titles.length, vsync: this);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HomeHeader(
        controller: controller,
        tabTitles: widget.titles,
        tabPages: [
          for (final t in widget.titles)
            ListView(primary: true, children: [Text('page $t')]),
        ],
        onSearch: (_) {},
      );
}

Future<void> _pump(WidgetTester tester, Widget child,
    {double width = 375, double text = 1}) async {
  tester.view.physicalSize = Size(width, 812) * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(text)),
        child: child,
      ),
    ),
  ));
  await tester.pump();
}

Finder _tab(int i) => find.byKey(ValueKey('home-tab-$i'));
final _search = find.byKey(const ValueKey('home-search'));

void main() {
  testWidgets('the tabs share the row equally, edge to edge with the search',
      (tester) async {
    await _pump(
        tester, const _Header(titles: ['DISCOVER', 'FOR YOU', 'FOLLOWING']));

    final search = tester.getRect(_search);
    expect(search.left, TabHeaderLayout.gutter);
    expect(search.right, 375 - TabHeaderLayout.gutter);
    expect(search.height, TabHeaderLayout.searchHeight);

    final tabs = [for (var i = 0; i < 3; i++) tester.getRect(_tab(i))];
    // One width each, one height, one line.
    expect({for (final t in tabs) t.width}, hasLength(1));
    expect(tabs.first.height, TabHeaderLayout.tabHeight);
    expect({for (final t in tabs) t.top}, hasLength(1));
    // The row starts and ends where the search box does: no space left over.
    expect(tabs.first.left, closeTo(search.left, 0.01));
    expect(tabs.last.right, closeTo(search.right, 0.01));
    // Evenly spaced, a modest gap under the search box.
    expect(tabs[1].left - tabs[0].right,
        closeTo(TabHeaderLayout.tabSpacing, 0.01));
    expect(tabs[2].left - tabs[1].right,
        closeTo(TabHeaderLayout.tabSpacing, 0.01));
    expect(tabs.first.top - search.bottom, closeTo(TabHeaderLayout.gap, 0.01));
  });

  testWidgets('a tap selects a tab', (tester) async {
    await _pump(
        tester, const _Header(titles: ['DISCOVER', 'FOR YOU', 'FOLLOWING']));
    CustomTab tab(int i) =>
        tester.widget<CustomTab>(find.byKey(ValueKey('home-tab-$i')));
    expect(tab(0).isSelected, isTrue);

    await tester.tap(_tab(2));
    await tester.pumpAndSettle();
    expect(tab(0).isSelected, isFalse);
    expect(tab(2).isSelected, isTrue);
    expect(find.text('page FOLLOWING'), findsOneWidget);
  });

  testWidgets('one tab: no tab row, the page right under the search',
      (tester) async {
    await _pump(tester, const _Header(titles: ['DISCOVER']));
    expect(_tab(0), findsNothing);
    expect(find.byType(TabBar), findsNothing);
    expect(
      tester.getTopLeft(find.text('page DISCOVER')).dy -
          tester.getBottomLeft(_search).dy,
      closeTo(TabHeaderLayout.top, 0.01),
    );
  });

  testWidgets('large text on a small phone: nothing overflows',
      (tester) async {
    for (final text in [1.35, 2.0, 3.1]) {
      await _pump(
          tester, const _Header(titles: ['DISCOVER', 'FOR YOU', 'FOLLOWING']),
          width: 320, text: text);
      expect(tester.takeException(), isNull, reason: 'text $text');
      expect(tester.getSize(_search).height, TabHeaderLayout.searchHeight);
      expect(tester.getSize(_tab(2)).height, TabHeaderLayout.tabHeight);
    }
  });

  testWidgets('the Events tab: the same header, two equal tabs',
      (tester) async {
    await _pump(
      tester,
      const SearchTabHeader(
        tabTitles: ['REGISTERED', 'PAST'],
        tabPages: [Text('registered'), Text('past')],
      ),
    );
    final search = tester.getRect(find.byType(HeaderSearchBox));
    final tabs = [
      for (final t in ['REGISTERED', 'PAST'])
        tester.getRect(find.ancestor(
            of: find.text(t), matching: find.byType(CustomTab))),
    ];
    expect(search.height, TabHeaderLayout.searchHeight);
    expect(tabs[0].width, tabs[1].width);
    expect(tabs[0].left, closeTo(search.left, 0.01));
    expect(tabs[1].right, closeTo(search.right, 0.01));
  });
}
