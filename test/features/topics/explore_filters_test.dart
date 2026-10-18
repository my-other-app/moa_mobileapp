import 'package:finnet/features/clubs/presentation/pages/explore_more_clubs_page.dart';
import 'package:finnet/features/events/presentation/pages/explore_events_page.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';
import 'topic_fixtures.dart';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Map<String, dynamic> _page(List<Map<String, dynamic>> items) =>
    {'items': items, 'total': items.length};

const _event = {
  'id': 7,
  'name': 'Hack Night',
  'slug': 'hack-night',
  'poster': null,
  'event_datetime': '2030-12-01T10:00:00Z',
  'duration': 2,
  'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub'},
  'category': {'id': 1, 'name': 'Workshop'},
};

Future<void> _pump(WidgetTester tester, Widget page,
    {FakeProfileRepository? profiles}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider
          .overrideWithValue(profiles ?? FakeProfileRepository()),
    ],
    child: MaterialApp(home: page),
  ));
  await _settle(tester);
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  Map<String, dynamic> lastQuery(String path) =>
      api.sent('GET', path).last.queryParameters;

  group('explore events', () {
    testWidgets('opened on a topic: asks for its interests, upcoming',
        (tester) async {
      api
        ..on('GET', '/interests/topics', contractTopicsBody)
        ..on('GET', '/events/list', _page([_event]));

      await _pump(tester, const ExploreEventsPage(initialTopic: 'development'));

      // One request, made once the topics were known.
      expect(api.sent('GET', '/events/list'), hasLength(1));
      final q = lastQuery('/events/list');
      expect(q['interest_ids'], '3,6');
      expect(q['is_ended'], false);
      expect(q['offset'], 0);
      expect(q.containsKey('topic'), isFalse);
      expect(find.text('Hack Night'), findsOneWidget);
      // The chosen topic is on, with its count; its interests below.
      expect(find.byKey(const ValueKey('topic-chip-development')),
          findsOneWidget);
      expect(
        tester.getSemantics(
            find.byKey(const ValueKey('topic-chip-development'))),
        isSemantics(isSelected: true, label: 'Development topic, 12 upcoming'),
      );
      expect(find.byKey(const ValueKey('interest-filter-6')), findsOneWidget);
    });

    testWidgets('an interest narrows it; All clears it', (tester) async {
      api
        ..on('GET', '/interests/topics', contractTopicsBody)
        ..on('GET', '/events/list', _page([_event]));
      await _pump(tester, const ExploreEventsPage(initialTopic: 'development'));

      await tester.tap(find.byKey(const ValueKey('interest-filter-6')));
      await _settle(tester);
      expect(lastQuery('/events/list')['interest_ids'], '6');

      // Tapping it again goes back to the whole topic.
      await tester.tap(find.byKey(const ValueKey('interest-filter-6')));
      await _settle(tester);
      expect(lastQuery('/events/list')['interest_ids'], '3,6');

      await tester.tap(find.byKey(const ValueKey('topic-filter-all')));
      await _settle(tester);
      expect(lastQuery('/events/list').containsKey('interest_ids'), isFalse);
      expect(find.byKey(const ValueKey('interest-filter-6')), findsNothing);
    });

    testWidgets('another topic swaps the second row', (tester) async {
      api
        ..on('GET', '/interests/topics', contractTopicsBody)
        ..on('GET', '/events/list', _page([_event]));
      await _pump(tester, const ExploreEventsPage());
      expect(lastQuery('/events/list').containsKey('interest_ids'), isFalse);

      await tester.tap(find.byKey(const ValueKey('topic-chip-arts')));
      await _settle(tester);

      expect(lastQuery('/events/list')['interest_ids'], '15');
      expect(find.byKey(const ValueKey('interest-filter-15')), findsOneWidget);
      expect(find.byKey(const ValueKey('interest-filter-6')), findsNothing);
    });

    testWidgets(
        'on a server without /interests/topics: no topic row, the '
        'interests from /interests/list', (tester) async {
      api
        ..on('GET', '/interests/list', productionListBody)
        ..on('GET', '/events/list', _page([_event]));
      await _pump(tester, const ExploreEventsPage());

      expect(api.sent('GET', '/interests/topics'), hasLength(1));
      expect(find.byKey(const ValueKey('topic-chip-arts')), findsNothing);
      expect(find.byKey(const ValueKey('topic-filter-all')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('interest-filter-7')));
      await _settle(tester);
      expect(lastQuery('/events/list')['interest_ids'], '7');
    });

    testWidgets('nothing under the topic: says so, offers to clear',
        (tester) async {
      api
        ..on('GET', '/interests/topics', contractTopicsBody)
        ..on('GET', '/events/list', _page(const []));
      await _pump(tester, const ExploreEventsPage(initialTopic: 'arts'));

      expect(find.text('No upcoming events in Arts yet'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await _settle(tester);
      expect(lastQuery('/events/list').containsKey('interest_ids'), isFalse);
      expect(find.text('No upcoming events yet'), findsOneWidget);
    });

    testWidgets('a failed list offers a retry', (tester) async {
      api
        ..on('GET', '/interests/topics', contractTopicsBody)
        ..on('GET', '/events/list', {'message': 'Down for a moment'},
            status: 503)
        ..on('GET', '/events/list', _page([_event]));
      await _pump(tester, const ExploreEventsPage());

      expect(find.text('Try Again'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      await _settle(tester);
      expect(find.text('Hack Night'), findsOneWidget);
    });

    testWidgets('topics that fail to load leave the list unfiltered',
        (tester) async {
      api.on('GET', '/events/list', _page([_event]));
      await _pump(tester, const ExploreEventsPage(initialTopic: 'development'));

      expect(api.sent('GET', '/events/list'), hasLength(1));
      expect(lastQuery('/events/list').containsKey('interest_ids'), isFalse);
      expect(find.text('Hack Night'), findsOneWidget);
    });
  });

  group('explore clubs', () {
    testWidgets('opened on a topic: /clubs/list with its interests',
        (tester) async {
      api
        ..on('GET', '/interests/topics', contractTopicsBody)
        ..on('GET', '/clubs/list', _page(const []));
      await _pump(
          tester, const ExploreMoreClubsPage(initialTopic: 'development'));

      expect(api.sent('GET', '/clubs/list'), hasLength(1));
      expect(lastQuery('/clubs/list'), {'interest_ids': '3,6'});
      expect(find.text('No clubs in Development yet'), findsOneWidget);
      // The topic chip counts clubs here.
      expect(
        tester.getSemantics(
            find.byKey(const ValueKey('topic-chip-development'))),
        isSemantics(label: 'Development topic, 30 clubs'),
      );
    });

    testWidgets('the college and a topic together', (tester) async {
      api
        ..on('GET', '/interests/topics', contractTopicsBody)
        ..on('GET', '/clubs/list', _page(const []));
      final profiles = FakeProfileRepository()
        ..profile = const UserProfile(
          id: 'u-1',
          fullName: 'Asha',
          email: 'asha@example.com',
          organization: Organization(id: 12, name: 'CET'),
        );
      await _pump(tester, const ExploreMoreClubsPage(), profiles: profiles);

      await tester.tap(find.text('CET'));
      await _settle(tester);
      expect(lastQuery('/clubs/list'), {'org_id': 12});

      await tester.tap(find.byKey(const ValueKey('topic-chip-arts')));
      await _settle(tester);
      expect(lastQuery('/clubs/list'), {'org_id': 12, 'interest_ids': '15'});
    });

    testWidgets('opened on an interest, on the one-topic server',
        (tester) async {
      api
        ..on('GET', '/interests/list', productionListBody)
        ..on('GET', '/clubs/list', _page(const []));
      await _pump(tester, const ExploreMoreClubsPage(initialInterestId: 16));

      expect(lastQuery('/clubs/list'), {'interest_ids': '16'});
      expect(find.text('No clubs in Music yet'), findsOneWidget);
    });
  });
}
