import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:finnet/features/profile/presentation/pages/profile_page.dart';
import 'package:finnet/features/speakers/data/speakers_api.dart';
import 'package:finnet/features/speakers/domain/speaker.dart';
import 'package:finnet/features/speakers/presentation/pages/followed_speakers_page.dart';
import 'package:finnet/features/speakers/presentation/pages/speaker_page.dart';
import 'package:finnet/features/speakers/presentation/speakers_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

/// `GET /speakers/following` as the contract has it.
final _following = [
  {
    'slug': 'ananya-iyer',
    'name': 'Ananya Iyer',
    'headline': 'ML engineer, Sarvam',
    'photo': {'thumbnail': 'https://media.myotherapp.in/a-t.jpg'},
    'upcoming_count': 2,
  },
  {
    'slug': 'ravi-k',
    'name': 'Ravi K',
    'headline': null,
    'photo': null,
    'upcoming_count': 0,
  },
];

void main() {
  group('reading the list', () {
    test('each speaker, their photo and upcoming talks; nothing unopenable',
        () {
      final list = FollowedSpeaker.listFrom([
        ..._following,
        {'slug': 'a/b', 'name': 'Odd'},
        {'slug': 'no-name'},
        {'name': 'No slug'},
        'nonsense',
      ]);
      expect(list.map((s) => s.slug), ['ananya-iyer', 'ravi-k']);
      expect(list.first.photo, 'https://media.myotherapp.in/a-t.jpg');
      expect(list.first.upcomingCount, 2);
      expect(list.last.headline, isNull);
      expect(FollowedSpeaker.listFrom({'items': _following}), hasLength(2));
      expect(FollowedSpeaker.listFrom(null), isEmpty);
    });

    test('a server without the speakers directory (404) is null', () async {
      final api = useFakeApi();
      expect(await SpeakersApi().following(), isNull);
      api.on('GET', '/speakers/following', _following);
      expect(await SpeakersApi().following(), hasLength(2));
    });
  });

  group('Profile > Speakers I Follow', () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    /// Profile at `/profile`, its list at `/profile/speakers`, and a
    /// speaker's page that records it was opened.
    Future<List<String>> pump(WidgetTester tester,
        {String at = '/profile'}) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final went = <String>[];
      final router = GoRouter(initialLocation: at, routes: [
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
        GoRoute(
          path: followedSpeakersLocation,
          builder: (_, __) => const FollowedSpeakersPage(),
        ),
        GoRoute(
          path: '/speakers/:slug',
          builder: (_, state) {
            went.add(state.uri.toString());
            return const Scaffold(body: Text('the speaker'));
          },
        ),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
          isAuthenticatedProvider.overrideWithValue(true),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      return went;
    }

    testWidgets('the menu row opens the list; a row opens the speaker',
        (tester) async {
      api.on('GET', '/speakers/following', _following);
      final went = await pump(tester);

      await tester.tap(find.byKey(ProfilePage.followedSpeakersKey));
      await tester.pumpAndSettle();

      expect(find.text('SPEAKERS I FOLLOW'), findsOneWidget);
      expect(find.text('Ananya Iyer'), findsOneWidget);
      expect(find.text('ML engineer, Sarvam'), findsOneWidget);
      expect(find.text('2 upcoming talks'), findsOneWidget);
      expect(find.text('Ravi K'), findsOneWidget);

      await tester.tap(find.byKey(FollowedSpeakersPage.rowKey('ravi-k')));
      await tester.pumpAndSettle();
      expect(find.text('the speaker'), findsOneWidget);
      expect(went.single, '/speakers/ravi-k');
    });

    testWidgets('unfollowing on the speaker\'s page takes them off the list',
        (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      api
        ..on('GET', '/speakers/following', _following)
        ..on('GET', '/speakers/following', [_following.first])
        ..on('GET', '/speakers/ravi-k', {
          'slug': 'ravi-k',
          'name': 'Ravi K',
          'following': true,
          'followers_count': 3,
          'talks': {'upcoming': [], 'past': []},
        })
        ..on('DELETE', '/speakers/ravi-k/follow',
            {'slug': 'ravi-k', 'following': false, 'followers_count': 2});
      final router = GoRouter(initialLocation: followedSpeakersLocation,
          routes: [
            GoRoute(
              path: followedSpeakersLocation,
              builder: (_, __) => const FollowedSpeakersPage(),
            ),
            ...speakersRoutes,
          ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [isAuthenticatedProvider.overrideWithValue(true)],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(FollowedSpeakersPage.rowKey('ravi-k')));
      await tester.pumpAndSettle();
      expect(find.text('UNFOLLOW'), findsOneWidget);
      await tester.tap(find.byKey(SpeakerPage.followKey));
      await tester.pumpAndSettle();
      expect(find.text('FOLLOW'), findsOneWidget);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Ananya Iyer'), findsOneWidget);
      expect(find.byKey(FollowedSpeakersPage.rowKey('ravi-k')), findsNothing);
      expect(api.sent('GET', '/speakers/following'), hasLength(2));
    });

    testWidgets('following nobody yet: said so, with how to',
        (tester) async {
      api.on('GET', '/speakers/following', const <Object>[]);
      await pump(tester, at: followedSpeakersLocation);

      expect(find.byKey(FollowedSpeakersPage.emptyKey), findsOneWidget);
      expect(find.textContaining('choose Follow'), findsOneWidget);
    });

    testWidgets('a server without the speakers directory: no row at all',
        (tester) async {
      await pump(tester);

      expect(api.sent('GET', '/speakers/following'), hasLength(1));
      expect(find.byKey(ProfilePage.followedSpeakersKey), findsNothing);
      expect(find.text('My Badges'), findsOneWidget);
    });

    testWidgets('a failed load keeps the row, and the list offers a retry',
        (tester) async {
      // The first answer fails; the next ones work.
      api
        ..on('GET', '/speakers/following', {'message': 'Down'}, status: 500)
        ..on('GET', '/speakers/following', _following);
      await pump(tester);
      expect(find.byKey(ProfilePage.followedSpeakersKey), findsOneWidget);

      await tester.tap(find.byKey(ProfilePage.followedSpeakersKey));
      await tester.pumpAndSettle();
      expect(find.text('Ananya Iyer'), findsNothing);

      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Ananya Iyer'), findsOneWidget);
    });
  });
}
