import 'dart:async';

import 'package:finnet/shared/utils/latest_search.dart';
import 'package:finnet/shared/widgets/custom_search_delegate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../features/events/events_fakes.dart';

/// The server behind a search: each endpoint's answer arrives when the test
/// says.
class _Server {
  final asked = <String>[];
  final _pending = <String, Completer<List<dynamic>>>{};

  Future<List<dynamic>> fetch(String endpoint) {
    asked.add(endpoint);
    return (_pending[endpoint] = Completer<List<dynamic>>()).future;
  }

  void answer(String endpoint, List<dynamic> items) =>
      _pending.remove(endpoint)!.complete(items);

  void refuse(String endpoint, Object error) =>
      _pending.remove(endpoint)!.completeError(error);
}

Map<String, dynamic> _event(int id, String name) => {
      'id': id,
      'name': name,
      'club': {'id': 3, 'name': 'Tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
    };

/// A page with a search button, the way a tab opens the search; records
/// where a result leads.
Future<List<(String, Object?)>> _open(
    WidgetTester tester, SearchDelegate<String> delegate) async {
  final pushed = <(String, Object?)>[];
  Widget opened(GoRouterState state) {
    pushed.add((state.uri.toString(), state.extra));
    return const Scaffold(body: Text('opened'));
  }

  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: TextButton(
          onPressed: () => showSearch(context: context, delegate: delegate),
          child: const Text('search'),
        ),
      ),
    ),
    GoRoute(path: '/events/:id', builder: (_, state) => opened(state)),
    GoRoute(path: '/clubs/:id', builder: (_, state) => opened(state)),
  ]);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.tap(find.text('search'));
  await tester.pumpAndSettle();
  return pushed;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

Future<void> _answered(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  group('event search (Home and My events)', () {
    testWidgets(
        'sends one request once typing pauses, for the tab, with the query '
        'encoded', (tester) async {
      final server = _Server();
      await _open(tester,
          EventSearchDelegate(filterType: 'registered', fetch: server.fetch));
      expect(find.text('Search for registered events'), findsOneWidget);

      await _type(tester, 'C');
      await tester.pump(const Duration(milliseconds: 100));
      await _type(tester, 'C++');
      await tester.pump(const Duration(milliseconds: 100));
      await _type(tester, 'C++ & AI');
      await tester.pump(const Duration(milliseconds: 299));
      expect(server.asked, isEmpty, reason: 'not a request per keystroke');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1));
      expect(server.asked,
          [eventSearchEndpoint('C++ & AI', filterType: 'registered')]);
      expect(server.asked.single, contains('search=C%2B%2B+%26+AI'));
      expect(server.asked.single, contains('is_registered=true'));

      server.answer(server.asked.single, [_event(7, 'Prompting with C++')]);
      await _answered(tester);
      expect(find.text('Prompting with C++'), findsOneWidget);
      expect(find.text('Tinkerhub'), findsOneWidget);
    });

    testWidgets(
        'answers out of order: the results are always the latest query\'s',
        (tester) async {
      final server = _Server();
      await _open(tester, EventSearchDelegate(fetch: server.fetch));

      await _type(tester, 'ro');
      await tester.pump(searchDebounce);
      await _type(tester, 'robot');
      await tester.pump(searchDebounce);
      final ro = eventSearchEndpoint('ro');
      final robot = eventSearchEndpoint('robot');
      expect(server.asked, [ro, robot]);

      server.answer(robot, [_event(7, 'Robot Wars')]);
      await _answered(tester);
      server.answer(ro, [_event(8, 'Rowing Club Meetup')]);
      await _answered(tester);

      expect(find.text('Robot Wars'), findsOneWidget);
      expect(find.text('Rowing Club Meetup'), findsNothing);
    });

    testWidgets(
        'while the next query is on its way, the last results stay under a '
        'thin bar', (tester) async {
      final server = _Server();
      await _open(tester, EventSearchDelegate(fetch: server.fetch));
      await _type(tester, 'robot');
      await tester.pump(searchDebounce);
      server.answer(server.asked.last, [_event(7, 'Robot Wars')]);
      await _answered(tester);

      await _type(tester, 'robots');
      await tester.pump(searchDebounce);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('Robot Wars'), findsOneWidget);

      server.answer(server.asked.last, [_event(9, 'Robots at Dawn')]);
      await _answered(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Robots at Dawn'), findsOneWidget);
      expect(find.text('Robot Wars'), findsNothing);
    });

    testWidgets("the keyboard's search key sends at once", (tester) async {
      final server = _Server();
      await _open(tester, EventSearchDelegate(fetch: server.fetch));
      await _type(tester, 'robot');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      await tester.pump(Duration.zero);

      expect(server.asked, [eventSearchEndpoint('robot')]);
      await tester.pump(const Duration(seconds: 1));
      expect(server.asked, hasLength(1));
    });

    testWidgets('nothing found says so', (tester) async {
      final server = _Server();
      await _open(tester, EventSearchDelegate(fetch: server.fetch));
      await _type(tester, 'xyzzy');
      await tester.pump(searchDebounce);
      server.answer(server.asked.single, const []);
      await _answered(tester);

      expect(find.text('No events found for "xyzzy"'), findsOneWidget);
    });

    testWidgets('a failure says so in words, and Retry searches again',
        (tester) async {
      final server = _Server();
      await _open(tester, EventSearchDelegate(fetch: server.fetch));
      await _type(tester, 'robot');
      await tester.pump(searchDebounce);
      // An answer that isn't JSON, say.
      server.refuse(server.asked.single, const FormatException('Unexpected <'));
      await _answered(tester);

      expect(find.text('Search failed. Please try again.'), findsOneWidget);
      expect(find.textContaining('Unexpected'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pump(Duration.zero);
      expect(server.asked, hasLength(2));
      server.answer(server.asked.last, [_event(7, 'Robot Wars')]);
      await _answered(tester);
      expect(find.text('Robot Wars'), findsOneWidget);
    });

    testWidgets('a result opens its event', (tester) async {
      final server = _Server();
      final pushed =
          await _open(tester, EventSearchDelegate(fetch: server.fetch));
      await _type(tester, 'robot');
      await tester.pump(searchDebounce);
      server.answer(server.asked.single, [_event(7, 'Robot Wars')]);
      await _answered(tester);

      await tester.tap(find.text('Robot Wars'));
      await tester.pumpAndSettle();
      expect(pushed.single.$1, '/events/7');
    });

    testWidgets('closed while typing pauses: nothing is sent', (tester) async {
      final server = _Server();
      await _open(tester, EventSearchDelegate(fetch: server.fetch));
      await _type(tester, 'ro');
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(server.asked, isEmpty);
      expect(find.text('search'), findsOneWidget);
    });

    testWidgets('clearing the query goes back to the prompt', (tester) async {
      final server = _Server();
      await _open(tester, EventSearchDelegate(fetch: server.fetch));
      await _type(tester, 'robot');
      await tester.pump(searchDebounce);
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      server.answer(server.asked.single, [_event(7, 'Robot Wars')]);
      await _answered(tester);

      expect(find.text('Search for  events'), findsOneWidget);
      expect(find.text('Robot Wars'), findsNothing);
    });

    testWidgets("by default it asks the app's API for the items",
        (tester) async {
      final api = useFakeApi()
        ..on('GET', eventSearchEndpoint('robot', filterType: 'following'), {
          'items': [_event(7, 'Robot Wars')]
        });
      await _open(tester, EventSearchDelegate(filterType: 'following'));
      await _type(tester, 'robot');
      await tester.pump(searchDebounce);
      await _answered(tester);
      await tester.pump(const Duration(milliseconds: 50));

      expect(api.requests.single.path, contains('is_following=true'));
      expect(find.text('Robot Wars'), findsOneWidget);
    });
  });

  group('club search (the Clubs tab)', () {
    testWidgets(
        'one request once typing pauses; a club opens with its id, slug and '
        'name', (tester) async {
      final server = _Server();
      final pushed =
          await _open(tester, ClubSearchDelegate(fetch: server.fetch));
      expect(find.text('Search for clubs'), findsOneWidget);

      await _type(tester, 'tin');
      await tester.pump(const Duration(milliseconds: 100));
      await _type(tester, 'tinker');
      await tester.pump(searchDebounce);
      expect(server.asked, [clubSearchEndpoint('tinker')]);

      server.answer(server.asked.single, [
        {
          'id': 3,
          'name': 'Tinkerhub CET',
          'slug': 'tinkerhub-cet',
          'followers_count': 12,
          'logo': null,
        },
      ]);
      await _answered(tester);
      expect(find.text('Tinkerhub CET'), findsOneWidget);
      expect(find.text('12 followers'), findsOneWidget);

      await tester.tap(find.text('Tinkerhub CET'));
      await tester.pumpAndSettle();
      expect(pushed.single.$1, '/clubs/3');
      expect(pushed.single.$2, {
        'clubId': 3,
        'clubSlug': 'tinkerhub-cet',
        'clubname': 'Tinkerhub CET',
      });
    });

    testWidgets('answers out of order: the latest query\'s clubs show',
        (tester) async {
      final server = _Server();
      await _open(tester, ClubSearchDelegate(fetch: server.fetch));
      await _type(tester, 'ti');
      await tester.pump(searchDebounce);
      await _type(tester, 'tinker');
      await tester.pump(searchDebounce);

      server.answer(clubSearchEndpoint('tinker'), [
        {'id': 3, 'name': 'Tinkerhub CET', 'followers_count': 12},
      ]);
      await _answered(tester);
      server.answer(clubSearchEndpoint('ti'), [
        {'id': 4, 'name': 'Tiara Dance Crew', 'followers_count': 40},
      ]);
      await _answered(tester);

      expect(find.text('Tinkerhub CET'), findsOneWidget);
      expect(find.text('Tiara Dance Crew'), findsNothing);
    });

    testWidgets('nothing found says so', (tester) async {
      final server = _Server();
      await _open(tester, ClubSearchDelegate(fetch: server.fetch));
      await _type(tester, 'xyzzy');
      await tester.pump(searchDebounce);
      server.answer(server.asked.single, const []);
      await _answered(tester);

      expect(find.text('No clubs found for "xyzzy"'), findsOneWidget);
    });
  });
}
