import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/domain/entities/profile_badge.dart';
import 'package:finnet/features/profile/presentation/pages/badges/my_badges_page.dart';
import 'package:finnet/features/profile/presentation/pages/profile_page.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

/// A badge as the server describes it (`BadgeDefinitionResponse`).
Map<String, dynamic> _def(int id, String slug, String name, String about,
        {String type = 'user', String emoji = '⭐'}) =>
    {
      'id': id,
      'slug': slug,
      'name': name,
      'description': about,
      'emoji': emoji,
      'badge_type': type,
      'trigger_metric': 'events_attended',
      'threshold': 5,
    };

final _firstSteps = _def(
    1, 'first_event', 'First Steps', 'Registered for your first event',
    emoji: '🎟️');
final _explorer =
    _def(3, 'event_explorer', 'Event Explorer', 'Attended 5 events');
final _winner = _def(2, 'winner', 'Winner', 'Won an event', emoji: '🏆');
final _clubBadge = _def(
    11, 'first_event_hosted', 'First Event', 'Hosted your first event',
    type: 'club');

/// `GET /badges/me`.
Map<String, dynamic> _mine(List<(Map<String, dynamic>, String)> awards) => {
      'user_id': 1,
      'badges': [
        for (final (i, (badge, at)) in awards.indexed)
          {'id': 100 + i, 'badge': badge, 'awarded_at': at},
      ],
      'total': awards.length,
    };

Future<void> _pump(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1170, 2532)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: MyBadgesPage())));
  await tester.pumpAndSettle();
}

void main() {
  group('BadgeShelf', () {
    test("earned newest first; to earn in the server's order; no club ones",
        () {
      final shelf = BadgeShelf.from(
        awards: [
          ProfileBadge.fromAward(
              {'badge': _firstSteps, 'awarded_at': '2026-09-01T10:00:00Z'})!,
          ProfileBadge.fromAward(
              {'badge': _winner, 'awarded_at': '2026-10-01T10:00:00Z'})!,
        ],
        definitions: [
          for (final d in [_firstSteps, _winner, _explorer, _clubBadge])
            ProfileBadge.fromJson(d)!,
        ],
      );

      expect(shelf.earned.map((b) => b.slug), ['winner', 'first_event']);
      expect(shelf.locked.map((b) => b.slug), ['event_explorer']);
      expect(shelf.total, 3);
    });

    test('a badge without an id or a name is dropped', () {
      expect(ProfileBadge.fromJson({'name': 'x'}), isNull);
      expect(ProfileBadge.fromJson({'id': 1, 'name': ' '}), isNull);
      expect(ProfileBadge.fromJson('nope'), isNull);
      expect(ProfileBadge.fromJson({'id': 1, 'name': 'A'})!.emoji, '🏅');
    });
  });

  group('My Badges', () {
    testWidgets('shows what was earned and what is still to earn',
        (tester) async {
      useFakeApi()
        ..on('GET', '/badges/me', _mine([(_firstSteps, '2026-10-12T10:00:00Z')]))
        ..on('GET', '/badges/definitions',
            [_firstSteps, _winner, _explorer, _clubBadge]);

      await _pump(tester);

      // The placeholder is gone.
      expect(find.textContaining('DROPPING'), findsNothing);
      expect(find.text('1 of 3 earned'), findsOneWidget);
      expect(find.text('EARNED'), findsOneWidget);
      expect(find.text('TO EARN'), findsOneWidget);

      final first = find.byKey(MyBadgesPage.tileKey('first_event'));
      expect(find.descendant(of: first, matching: find.text('First Steps')),
          findsOneWidget);
      expect(
          find.descendant(
              of: first, matching: find.text('Earned 12 Oct 2026')),
          findsOneWidget);
      expect(
          find.descendant(of: first, matching: find.byIcon(Icons.lock_outline)),
          findsNothing);

      // A locked one says what earns it, with a lock.
      final explorer = find.byKey(MyBadgesPage.tileKey('event_explorer'));
      expect(
          find.descendant(
              of: explorer, matching: find.text('Attended 5 events')),
          findsOneWidget);
      expect(
          find.descendant(
              of: explorer, matching: find.byIcon(Icons.lock_outline)),
          findsOneWidget);
      // A club's badge is not a person's to earn.
      expect(find.byKey(MyBadgesPage.tileKey('first_event_hosted')),
          findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nothing earned yet says how to start', (tester) async {
      useFakeApi()
        ..on('GET', '/badges/me', _mine(const []))
        ..on('GET', '/badges/definitions', [_firstSteps, _winner]);

      await _pump(tester);

      expect(find.text('0 of 2 earned'), findsOneWidget);
      expect(find.text('None yet. Register for an event to earn your first.'),
          findsOneWidget);
    });

    testWidgets('without the full list, the earned ones still show',
        (tester) async {
      useFakeApi()
        ..on('GET', '/badges/me', _mine([(_winner, '2026-10-12T10:00:00Z')]))
        ..on('GET', '/badges/definitions', {'message': 'down'}, status: 500);

      await _pump(tester);

      expect(find.byKey(MyBadgesPage.tileKey('winner')), findsOneWidget);
      expect(find.text('TO EARN'), findsNothing);
    });

    testWidgets('a failure says so, and Try Again reads them again',
        (tester) async {
      final api = useFakeApi()
        ..on('GET', '/badges/me', {'message': 'down'}, status: 500)
        ..on('GET', '/badges/me', _mine([(_firstSteps, '2026-10-12T10:00:00Z')]))
        ..on('GET', '/badges/definitions', [_firstSteps]);

      await _pump(tester);
      expect(find.byType(ErrorView), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.byKey(MyBadgesPage.tileKey('first_event')), findsOneWidget);
      expect(api.sent('GET', '/badges/me'), hasLength(2));
    });
  });

  testWidgets('the Profile menu has My Badges again, and it opens the page',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    useFakeApi()
      ..on('GET', '/badges/me', _mine(const []))
      ..on('GET', '/badges/definitions', [_firstSteps]);
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ProfilePage()),
      GoRoute(
          path: '/profile/badges', builder: (_, __) => const MyBadgesPage()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Badges'));
    await tester.pumpAndSettle();

    expect(find.text('BADGES'), findsOneWidget);
    expect(find.text('0 of 1 earned'), findsOneWidget);
  });

  test('is at /profile/badges', () {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith((ref) => _FakeAuth(
          const AuthState(accessToken: 'token', isInitialized: true))),
      routerObserversProvider.overrideWithValue(const []),
    ]);
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    expect(
        router.configuration
            .findMatch(Uri.parse('/profile/badges'))
            .last
            .route
            .name,
        AppRoutes.badges);
  });
}
