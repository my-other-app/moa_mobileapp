import 'package:finnet/features/home/presentation/pages/home_page_tabs/for_you_events_page.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

const _firstPage = '/events/for-you?offset=0&limit=10';
const _secondPage = '/events/for-you?offset=10&limit=10';

Map<String, dynamic> _event(int id, {String? name}) => {
      'id': id,
      'name': name ?? 'Event $id',
      'slug': 'event-$id',
      'event_datetime': '2030-12-01T10:00:00Z',
      'club': {'id': 3, 'name': 'Tinkerhub', 'slug': 'tinkerhub'},
      'category': {'id': 1, 'name': 'Tech'},
      'is_online': false,
      'has_fee': false,
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The For You tab inside a router, recording the events it opens.
Future<List<String>> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1080, 2400)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final opened = <String>[];
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const Scaffold(body: ForYouEventsPage()),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (_, state) {
        opened.add(state.uri.path);
        return const Scaffold(body: Text('event page'));
      },
    ),
  ]);
  await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)));
  await _settle(tester);
  return opened;
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  testWidgets('shows the events picked for the person, from /events/for-you',
      (tester) async {
    api.on('GET', _firstPage, {
      'items': [_event(1, name: 'Hack Night'), _event(2, name: 'Design Jam')],
    });
    await _pump(tester);

    expect(api.sent('GET', _firstPage), hasLength(1));
    expect(find.text('Hack Night'), findsOneWidget);
    expect(find.text('Design Jam'), findsOneWidget);
    expect(find.text('Nothing to show on the feed'), findsNothing);
  });

  testWidgets("a card's button opens its event", (tester) async {
    api.on('GET', _firstPage, {
      'items': [_event(7, name: 'Hack Night')],
    });
    final opened = await _pump(tester);

    await tester.tap(find.text('TAKE A CLOSER LOOK OF THE EVENT'));
    await _settle(tester);

    expect(opened, ['/events/7']);
    expect(find.text('event page'), findsOneWidget);
  });

  testWidgets('an empty feed says so', (tester) async {
    api.on('GET', _firstPage, {'items': []});
    await _pump(tester);

    expect(find.text('Nothing to show on the feed'), findsOneWidget);
  });

  testWidgets('a failure with nothing saved shows the error; Try Again loads',
      (tester) async {
    api
      ..on('GET', _firstPage, {'message': 'Boom'}, status: 500)
      ..on('GET', _firstPage, {
        'items': [_event(1, name: 'Hack Night')],
      });
    await _pump(tester);

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Hack Night'), findsNothing);

    await tester.tap(find.text('Try Again'));
    await _settle(tester);

    expect(api.sent('GET', _firstPage), hasLength(2));
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
    expect(api.sent('GET', _secondPage), isEmpty);

    await tester.drag(find.byType(ListView), const Offset(0, -30000));
    await _settle(tester);

    expect(api.sent('GET', _secondPage), hasLength(1));
    await tester.drag(find.byType(ListView), const Offset(0, -30000));
    await _settle(tester);
    expect(find.text('The eleventh'), findsOneWidget);
    // A short page is the last: nothing more is asked for.
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a short first page is the whole feed: no next page',
      (tester) async {
    api.on('GET', _firstPage, {
      'items': [_event(1), _event(2)],
    });
    await _pump(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -30000));
    await _settle(tester);

    expect(api.requests.where((r) => r.path.contains('offset=10')), isEmpty);
  });
}
