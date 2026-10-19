import 'package:finnet/features/home/presentation/pages/home_page_tabs/for_you_events_page.dart';
import 'package:finnet/features/topics/presentation/widgets/browse_by_topic_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';
import 'topic_fixtures.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<List<(String, Object?)>> _pump(WidgetTester tester, Widget body) async {
  final went = <(String, Object?)>[];
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => Scaffold(body: body)),
    GoRoute(
      path: '/topics',
      builder: (_, state) {
        went.add((state.uri.path, state.extra));
        return const Scaffold(body: Text('topics'));
      },
      routes: [
        GoRoute(
          path: ':slug',
          builder: (_, state) {
            went.add((state.uri.path, state.extra));
            return const Scaffold(body: Text('a topic'));
          },
        ),
      ],
    ),
  ]);
  await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
  return went;
}

const _event = {
  'id': 7,
  'name': 'Hack Night',
  'slug': 'hack-night',
  'event_datetime': '2030-12-01T10:00:00Z',
  'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub'},
};

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets("a tile's emoji large, and a glimpse of its interests' emoji",
      (tester) async {
    api.on('GET', '/interests/topics', contractTopicsBody);
    await _pump(tester, const BrowseByTopicRow());

    final dev = find.byKey(const ValueKey('browse-topic-development'));
    expect(find.descendant(of: dev, matching: find.text('💻')), findsOneWidget);
    // Web Development and Coding came without emoji: the app's own.
    expect(
        tester
            .widget<Text>(
                find.byKey(const ValueKey('browse-topic-emoji-development')))
            .data,
        '🌐 ⌨️');
    // Arts came without its emoji, too.
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('browse-topic-arts')),
            matching: find.text('🎭')),
        findsOneWidget);
  });

  testWidgets("a card per topic, counted; a tap opens the topic's page",
      (tester) async {
    api.on('GET', '/interests/topics', contractTopicsBody);
    final went = await _pump(tester, const BrowseByTopicRow());

    expect(find.text('BROWSE BY TOPIC'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('browse-topic-development')), findsOneWidget);
    expect(find.text('12 upcoming'), findsOneWidget);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('browse-topic-development'))),
      isSemantics(
          label: 'Development, 12 upcoming events',
          isButton: true,
          hasTapAction: true),
    );

    await tester.tap(find.byKey(const ValueKey('browse-topic-arts')));
    await _settle(tester);
    expect(went.single.$1, '/topics/arts');
  });

  testWidgets('large text still fits the cards', (tester) async {
    api.on('GET', '/interests/topics', contractTopicsBody);
    await _pump(
      tester,
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: const BrowseByTopicRow(),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('12 upcoming'), findsOneWidget);
  });

  testWidgets('"See all" opens every topic', (tester) async {
    api.on('GET', '/interests/topics', contractTopicsBody);
    final went = await _pump(tester, const BrowseByTopicRow());

    await tester.tap(find.byKey(const ValueKey('browse-by-topic-all')));
    await _settle(tester);
    expect(went.single.$1, '/topics');
  });

  testWidgets('without counts (the /interests/list fallback) still shows',
      (tester) async {
    api.on('GET', '/interests/list', contractListBody);
    await _pump(tester, const BrowseByTopicRow());

    expect(
        find.byKey(const ValueKey('browse-topic-development')), findsOneWidget);
    expect(find.textContaining('upcoming'), findsNothing);
  });

  testWidgets('nothing on the one-topic server, or when topics fail',
      (tester) async {
    api.on('GET', '/interests/list', productionListBody);
    await _pump(tester, const BrowseByTopicRow());
    expect(find.byKey(const ValueKey('browse-by-topic')), findsNothing);
  });

  testWidgets('on the For You feed, above the events', (tester) async {
    api
      ..on('GET', '/interests/topics', contractTopicsBody)
      ..on('GET', '/events/for-you?offset=0&limit=10', {
        'items': [_event],
      });
    await _pump(tester, const ForYouEventsPage());

    expect(find.byKey(const ValueKey('browse-by-topic')), findsOneWidget);
    expect(find.text('Hack Night'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('BROWSE BY TOPIC')).dy,
      lessThan(tester.getTopLeft(find.text('Hack Night')).dy),
    );
  });

  testWidgets('an empty feed still offers the topics', (tester) async {
    api
      ..on('GET', '/interests/topics', contractTopicsBody)
      ..on('GET', '/events/for-you?offset=0&limit=10', {'items': []});
    await _pump(tester, const ForYouEventsPage());

    expect(find.byKey(const ValueKey('browse-by-topic')), findsOneWidget);
    expect(find.text('Nothing to show on the feed'), findsOneWidget);
  });
}
