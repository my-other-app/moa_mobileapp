import 'package:finnet/features/clubs/presentation/pages/club_profile_page.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';
import 'topic_fixtures.dart';

const _topicsJson = [
  {'id': 2, 'slug': 'development', 'name': 'Development', 'color': '#2563EB'},
  {'id': 4, 'slug': 'arts', 'name': 'Arts', 'color': '#EA580C'},
];

Map<String, dynamic> _event({
  List<Map<String, dynamic>>? topics,
  List<Map<String, dynamic>> interests = const [],
}) =>
    {
      'id': 7,
      'name': 'Hack Night',
      'slug': 'hack-night',
      'poster': null,
      'event_datetime': '2030-12-01T10:00:00Z',
      'duration': 2.5,
      'location_name': 'CET',
      'has_fee': false,
      'reg_fee': 0,
      'has_prize': false,
      'is_online': false,
      'reg_startdate': '2020-01-01T00:00:00Z',
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub', 'logo': {}},
      'category': {'id': 1, 'name': 'Workshop'},
      'additional_details': const [],
      'rating': 0,
      'total_rating': 0,
      'is_registered': false,
      'is_attended': false,
      'interests': interests,
      if (topics != null) 'topics': topics,
    };

Map<String, dynamic> _club({
  List<Map<String, dynamic>>? topics,
  List<Map<String, dynamic>> interests = const [],
}) =>
    {
      'id': 5,
      'name': 'Tinkerhub CET',
      'slug': 'tinkerhub-cet',
      'logo': null,
      'about': 'We build things.',
      'followers_count': 12,
      'interests': interests,
      if (topics != null) 'topics': topics,
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [page] inside a router, recording where a topic chip leads.
Future<List<(String, Object?)>> _pump(WidgetTester tester, Widget page) async {
  final went = <(String, Object?)>[];
  Widget record(GoRouterState state) {
    went.add((state.uri.path, state.extra));
    return const Scaffold(body: Text('explore'));
  }

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => page),
    GoRoute(path: '/events/explore', builder: (_, s) => record(s)),
    GoRoute(path: '/clubs/explore', builder: (_, s) => record(s)),
    GoRoute(path: '/topics/:slug', builder: (_, s) => record(s)),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      paymentRepositoryProvider.overrideWithValue(FakePaymentRepository()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
  return went;
}

Finder _topic(String slug) => find.byKey(ValueKey('topic-chip-$slug'));

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('an event\'s page', () {
    testWidgets('shows the topics the server sends, in their colours',
        (tester) async {
      api
        ..on('GET', '/events/info/7', _event(topics: _topicsJson))
        ..on('GET', '/interests/list', contractListBody);
      await _pump(tester, const IndividualEventPage(eventId: 7));

      expect(_topic('development'), findsOneWidget);
      expect(_topic('arts'), findsOneWidget);
      expect(
        tester.getSemantics(_topic('development')),
        isSemantics(label: 'Development topic', isButton: true),
      );
    });

    testWidgets('without them, works them out from its interests',
        (tester) async {
      api
        ..on(
            'GET',
            '/events/info/7',
            _event(interests: [
              {'id': 3, 'name': 'Web Development'},
              {'id': 6, 'name': 'Coding', 'category_id': 2},
            ]))
        ..on('GET', '/interests/list', contractListBody);
      await _pump(tester, const IndividualEventPage(eventId: 7));

      expect(_topic('development'), findsOneWidget);
      expect(_topic('arts'), findsNothing);
      // The interests themselves, beneath.
      expect(find.text('Web Development'), findsOneWidget);
      expect(find.text('Coding'), findsOneWidget);
    });

    testWidgets(
        'on today\'s one-topic server, no "Arts" on everything -- just the '
        'interests', (tester) async {
      api
        ..on(
            'GET',
            '/events/info/7',
            _event(interests: [
              {'id': 6, 'name': 'Coding'},
            ]))
        ..on('GET', '/interests/list', productionListBody);
      await _pump(tester, const IndividualEventPage(eventId: 7));

      expect(_topic('arts'), findsNothing);
      expect(find.text('Coding'), findsOneWidget);
    });

    testWidgets('a topic opens its topic page', (tester) async {
      api
        ..on('GET', '/events/info/7', _event(topics: _topicsJson))
        ..on('GET', '/interests/list', contractListBody);
      final went = await _pump(tester, const IndividualEventPage(eventId: 7));

      await tester.ensureVisible(_topic('arts'));
      await tester.pump();
      await tester.tap(_topic('arts'));
      await _settle(tester);

      expect(went.single.$1, '/topics/arts');
    });

    testWidgets('no topics and no interests draw nothing', (tester) async {
      api.on('GET', '/events/info/7', _event());
      await _pump(tester, const IndividualEventPage(eventId: 7));

      expect(find.byKey(const ValueKey('topic-tag-strip')), findsNothing);
      expect(find.text('Hack Night'), findsWidgets);
    });
  });

  // The owner's call: a club's page shows its interests, and no topics --
  // not the ones the server sends, nor any worked out from its interests.
  group('a club\'s page', () {
    testWidgets('only its interests, though the server sends its topics',
        (tester) async {
      api
        ..on(
            'GET',
            '/clubs/info/5',
            _club(topics: _topicsJson, interests: [
              {'id': 3, 'name': 'Web Development', 'category_id': 2},
            ]))
        ..on('GET', '/interests/list', contractListBody);
      await _pump(tester, const ClubProfilePage(id: 5));

      expect(find.text('Web Development'), findsOneWidget);
      expect(_topic('development'), findsNothing);
      expect(_topic('arts'), findsNothing);
      expect(find.byKey(const ValueKey('topic-tag-strip')), findsNothing);
    });

    testWidgets('nor a topic worked out from its interests', (tester) async {
      api
        ..on(
            'GET',
            '/clubs/info/5',
            _club(interests: [
              {'id': 22, 'name': 'Blockchain'},
            ]))
        ..on('GET', '/interests/list', [
          ...contractListBody,
          {
            'id': 3,
            'slug': 'deep-tech',
            'name': 'Deep Tech',
            'sort_order': 2,
            'interests': [
              {'id': 22, 'name': 'Blockchain'},
            ],
          },
        ]);
      await _pump(tester, const ClubProfilePage(id: 5));

      expect(find.text('Blockchain'), findsOneWidget);
      expect(_topic('deep-tech'), findsNothing);
      expect(find.text('Deep Tech'), findsNothing);
    });
  });
}
