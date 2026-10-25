import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/clubs/presentation/pages/clubs_page.dart';
import 'package:finnet/features/notifications/data/repositories/push_settings_repository_impl.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/core/error/either.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

/// A server that keeps no mutes: a club's sheet shows its three options.
class _NoMutes implements PushSettingsRepository {
  @override
  Future<Result<bool?>> isClubMuted(int clubId) async => Either.right(null);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

const _pinned = '/clubs/list?is_pinned=true';
const _following = '/clubs/list?is_following=true';

Map<String, dynamic> _page(List<Map<String, dynamic>> items) =>
    {'items': items, 'total': items.length, 'limit': 10, 'offset': 0};

Map<String, dynamic> _club(int id, String name) => {
      'id': id,
      'name': name,
      'slug': name.toLowerCase().replaceAll(' ', '-'),
      'logo': null,
      'followers_count': 40,
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The Clubs tab, signed in, in a router recording the pages it opens.
Future<List<(String, Object?)>> _pumpTab(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(900, 2400)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final opened = <(String, Object?)>[];
  Widget page(GoRouterState state, String label) {
    opened.add((state.uri.toString(), state.extra));
    return Scaffold(body: Text(label));
  }

  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const ClubsPage()),
    GoRoute(path: '/clubs/explore', builder: (_, s) => page(s, 'explore')),
    GoRoute(path: '/clubs/:id', builder: (_, s) => page(s, 'club page')),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      isAuthenticatedProvider.overrideWithValue(true),
      pushSettingsRepositoryProvider.overrideWithValue(_NoMutes()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
  return opened;
}

/// The "more" button on [club]'s row in "Clubs you follow".
Finder _optionsOf(String club) => find.descendant(
      of: find
          .ancestor(of: find.text(club), matching: find.byType(InkWell))
          .first,
      matching: find.byIcon(Icons.more_vert),
    );

Future<void> _openOptions(WidgetTester tester, String club) async {
  final more = _optionsOf(club);
  await tester.ensureVisible(more);
  await tester.tap(more);
  await tester.pumpAndSettle();
}

void main() {
  late RouteAdapter api;

  setUp(() {
    api = useFakeApi()..on('GET', '/interests/topics', const []);
  });

  testWidgets(
      'pinned clubs on top, the clubs you follow below, and the pinned ones '
      'known as pinned', (tester) async {
    api
      ..on('GET', _pinned, _page([_club(12, 'Circuit Society')]))
      ..on('GET', _following,
          _page([_club(12, 'Circuit Society'), _club(14, 'Lens Club')]));
    await _pumpTab(tester);

    expect(find.text('PINNED'), findsOneWidget);
    expect(find.text('CLUBS YOU FOLLOW'), findsOneWidget);
    // Once in the pinned row, once in the list.
    expect(find.text('Circuit Society'), findsNWidgets(2));
    expect(find.text('Lens Club'), findsOneWidget);

    await _openOptions(tester, 'Lens Club');
    expect(find.text('Pin It'), findsOneWidget);
    Navigator.of(tester.element(find.text('Pin It'))).pop();
    await tester.pumpAndSettle();

    // The followed copy of a pinned club offers Unpin.
    final circuitRow = find.text('Circuit Society').last;
    await tester.tap(find.descendant(
        of: find.ancestor(of: circuitRow, matching: find.byType(InkWell)).first,
        matching: find.byIcon(Icons.more_vert)));
    await tester.pumpAndSettle();
    expect(find.text('Unpin'), findsOneWidget);
  });

  testWidgets('no pinned clubs: no PINNED row', (tester) async {
    api
      ..on('GET', _pinned, _page(const []))
      ..on('GET', _following, _page([_club(14, 'Lens Club')]));
    await _pumpTab(tester);

    expect(find.text('PINNED'), findsNothing);
    expect(find.text('Lens Club'), findsOneWidget);
  });

  testWidgets('following nobody says so, with Explore more', (tester) async {
    api
      ..on('GET', _pinned, _page(const []))
      ..on('GET', _following, _page(const []));
    final opened = await _pumpTab(tester);

    expect(find.text('You are not following any clubs, checkout clubs'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('clubs-explore-more')));
    await _settle(tester);
    expect(opened.single.$1, '/clubs/explore');
  });

  testWidgets('a pinned club and a followed club open their pages',
      (tester) async {
    api
      ..on('GET', _pinned, _page([_club(12, 'Circuit Society')]))
      ..on('GET', _following, _page([_club(14, 'Lens Club')]));
    final opened = await _pumpTab(tester);

    await tester.tap(find.text('Circuit Society'));
    await _settle(tester);
    expect(opened.last.$1, '/clubs/12');
    expect(opened.last.$2,
        {'clubSlug': 'circuit-society', 'clubName': 'Circuit Society'});

    GoRouter.of(tester.element(find.text('club page'))).pop();
    await tester.pumpAndSettle();
    opened.clear();
    await tester.tap(find.text('Lens Club'));
    await _settle(tester);
    expect(opened.last.$1, '/clubs/14');
    expect(opened.last.$2, {'clubSlug': 'lens-club', 'clubName': 'Lens Club'});
  });

  testWidgets('the search box opens the club search', (tester) async {
    api
      ..on('GET', _pinned, _page(const []))
      ..on('GET', _following, _page(const []));
    await _pumpTab(tester);

    await tester.tap(find.byKey(const ValueKey('clubs-search')));
    await tester.pumpAndSettle();
    expect(find.text('Search for clubs'), findsOneWidget);
  });

  testWidgets('a failure says so; Try Again reads the clubs again',
      (tester) async {
    api
      ..on('GET', _pinned, {'message': 'Server down'}, status: 500)
      ..on('GET', _pinned, _page(const []))
      ..on('GET', _following, _page([_club(14, 'Lens Club')]));
    await _pumpTab(tester);

    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Lens Club'), findsNothing);

    await tester.tap(find.text('Try Again'));
    await _settle(tester);
    expect(find.text('Lens Club'), findsOneWidget);
    expect(api.sent('GET', _pinned), hasLength(2));
  });

  group("a club's options, from its row", () {
    testWidgets('Pin It pins it, and the tab reads its clubs again',
        (tester) async {
      api
        ..on('GET', _pinned, _page(const []))
        ..on('GET', _pinned, _page([_club(14, 'Lens Club')]))
        ..on('GET', _following, _page([_club(14, 'Lens Club')]))
        ..on('POST', '/clubs/pin/14', {'message': 'ok'});
      await _pumpTab(tester);
      expect(find.text('PINNED'), findsNothing);

      await _openOptions(tester, 'Lens Club');
      await tester.tap(find.text('Pin It'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', '/clubs/pin/14'), hasLength(1));
      expect(api.sent('GET', _pinned), hasLength(2));
      expect(find.text('PINNED'), findsOneWidget);
    });

    testWidgets('Unfollow takes the club off the list', (tester) async {
      api
        ..on('GET', _pinned, _page(const []))
        ..on('GET', _following,
            _page([_club(12, 'Circuit Society'), _club(14, 'Lens Club')]))
        ..on('GET', _following, _page([_club(12, 'Circuit Society')]))
        ..on('POST', '/clubs/unfollow/14', {'message': 'ok'});
      await _pumpTab(tester);

      await _openOptions(tester, 'Lens Club');
      await tester.tap(find.text('Unfollow'));
      await tester.pumpAndSettle();

      expect(api.sent('POST', '/clubs/unfollow/14'), hasLength(1));
      expect(find.text('Lens Club'), findsNothing);
      expect(find.text('Circuit Society'), findsOneWidget);
    });

    testWidgets('Hide Events hides them, and the tab reads its clubs again',
        (tester) async {
      final lens = _club(14, 'Lens Club');
      api
        ..on('GET', _pinned, _page(const []))
        ..on('GET', _following, _page([lens]))
        ..on(
            'GET',
            _following,
            _page([
              {...lens, 'is_hidden': true}
            ]))
        ..on('POST', '/clubs/hide/14', {'message': 'ok'});
      await _pumpTab(tester);

      await _openOptions(tester, 'Lens Club');
      await tester.tap(find.text('Hide Events'));
      await tester.pumpAndSettle();
      expect(api.sent('POST', '/clubs/hide/14'), hasLength(1));
      expect(api.sent('GET', _following), hasLength(2));

      // The row knows now: its sheet offers to show them again.
      await _openOptions(tester, 'Lens Club');
      expect(find.text('Show Events'), findsOneWidget);
    });

    testWidgets('a refused option changes nothing on the tab', (tester) async {
      api
        ..on('GET', _pinned, _page(const []))
        ..on('GET', _following, _page([_club(14, 'Lens Club')]))
        ..on('POST', '/clubs/unfollow/14', {'message': 'Try later'},
            status: 400);
      await _pumpTab(tester);

      await _openOptions(tester, 'Lens Club');
      await tester.tap(find.text('Unfollow'));
      await _settle(tester);

      expect(find.text('Failed to unfollow: Try later'), findsOneWidget);
      expect(api.sent('GET', _following), hasLength(1));
    });
  });
}
