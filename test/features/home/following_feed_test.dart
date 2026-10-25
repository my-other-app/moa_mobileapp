import 'package:finnet/features/home/presentation/pages/home_page_tabs/following_events_page.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

const _firstPage =
    '/events/list?is_following=true&is_ended=false&offset=0&limit=10';
const _secondPage =
    '/events/list?is_following=true&is_ended=false&offset=10&limit=10';

Map<String, dynamic> _event(int id, {String? name, String club = 'Tinkerhub'}) =>
    {
      'id': id,
      'name': name ?? 'Event $id',
      'slug': 'event-$id',
      'event_datetime': '2030-12-01T10:00:00Z',
      'club': {'id': 3, 'name': club, 'slug': 'tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'is_online': false,
      'has_fee': false,
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The Following tab inside a router, recording where it goes.
Future<List<String>> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final went = <String>[];
  Widget stub(GoRouterState state) {
    went.add(state.uri.path);
    return Scaffold(body: Text('opened ${state.uri.path}'));
  }

  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(body: FollowingEventsPage()),
    ),
    GoRoute(path: '/clubs/explore', builder: (_, s) => stub(s)),
    GoRoute(path: '/events/:id', builder: (_, s) => stub(s)),
  ]);
  await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
  return went;
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets(
      'shows upcoming events from the clubs the person follows, with their '
      'club', (tester) async {
    api.on('GET', _firstPage, {
      'items': [
        _event(1, name: 'Hack Night', club: 'Tinkerhub'),
        _event(2, name: 'Circuit Clinic', club: 'Circuit Society'),
      ],
    });
    await _pump(tester);

    expect(api.sent('GET', _firstPage), hasLength(1));
    expect(find.text('Hack Night'), findsOneWidget);
    expect(find.text('Circuit Clinic'), findsOneWidget);
    expect(find.text('Tinkerhub'), findsOneWidget);
    expect(find.text('Circuit Society'), findsOneWidget);
  });

  testWidgets("a card's button opens its event", (tester) async {
    api.on('GET', _firstPage, {
      'items': [_event(9, name: 'Hack Night')],
    });
    final went = await _pump(tester);

    await tester.tap(find.text('TAKE A CLOSER LOOK OF THE EVENT'));
    await _settle(tester);

    expect(went, ['/events/9']);
  });

  testWidgets(
      'following no club (or none with events): the way to find clubs',
      (tester) async {
    api.on('GET', _firstPage, {'items': []});
    final went = await _pump(tester);

    expect(find.textContaining('You are not following any clubs'),
        findsOneWidget);
    await tester.tap(find.text('VIEW CLUBS'));
    await _settle(tester);

    expect(went, ['/clubs/explore']);
  });

  testWidgets('a failure shows the error; Try Again loads the events',
      (tester) async {
    api
      ..on('GET', _firstPage, {'message': 'Boom'}, status: 500)
      ..on('GET', _firstPage, {
        'items': [_event(1, name: 'Hack Night')],
      });
    await _pump(tester);

    expect(find.byType(ErrorView), findsOneWidget);
    await tester.tap(find.text('Try Again'));
    await _settle(tester);

    expect(find.byType(ErrorView), findsNothing);
    expect(find.text('Hack Night'), findsOneWidget);
  });

  testWidgets('a full page asks for the next one at the end of the list',
      (tester) async {
    api
      ..on('GET', _firstPage, {
        'items': [for (var i = 1; i <= 10; i++) _event(i)],
      })
      ..on('GET', _secondPage, {
        'items': [_event(11, name: 'The eleventh')],
      });
    await _pump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -30000));
    await _settle(tester);
    expect(api.sent('GET', _secondPage), hasLength(1));

    await tester.drag(find.byType(ListView), const Offset(0, -30000));
    await _settle(tester);
    expect(find.text('The eleventh'), findsOneWidget);
  });
}
