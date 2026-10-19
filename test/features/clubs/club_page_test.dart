import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/cache_store.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/clubs/data/datasources/club_page_source.dart';
import 'package:finnet/features/clubs/data/models/club_info.dart';
import 'package:finnet/features/clubs/presentation/pages/club_events_page.dart';
import 'package:finnet/features/clubs/presentation/pages/club_individual_page.dart';
import 'package:finnet/features/clubs/presentation/pages/club_profile_page.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/utils/share_links.dart';
import 'package:finnet/shared/widgets/club_tab_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';
import 'club_fixtures.dart';

/// Pictures the image widget draws its fallback for, without a network.
const _local = '/media';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// [page] in a router, signed in or out, recording the links opened.
Future<List<Uri>> _pump(
  WidgetTester tester,
  Widget page, {
  required bool signedIn,
  double width = 440,
}) async {
  // Tall, so every section is built; wide enough for the test font, where
  // every letter is a full em.
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final opened = <Uri>[];
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => page),
    GoRoute(
        path: '/auth/onboarding',
        builder: (_, __) => const Scaffold(body: Text('sign-in screen'))),
    GoRoute(
        path: '/clubs/explore',
        builder: (_, __) => const Scaffold(body: Text('explore'))),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      isAuthenticatedProvider.overrideWithValue(signedIn),
      linkLauncherProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return true;
      }),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await _settle(tester);
  return opened;
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  group('reading a club', () {
    test('/clubs/info: cover, tagline, team in order, partners', () {
      final club = ClubInfo.fromJson(clubInfoJson());

      expect(club.coverUrl, 'https://media.myotherapp.in/cover-l.jpg');
      expect(club.tagline, 'We build robots that play football.');
      expect(club.isPublicView, isFalse);

      // The club's own order (sort_order), not the order sent.
      expect(club.team.map((p) => (p.name, p.role)), [
        ('Asha Menon', 'President'),
        ('Rahul Nair', 'Design lead'),
      ]);
      final asha = club.team.first;
      expect(asha.photoUrl, 'https://media.myotherapp.in/asha-m.jpg');
      expect(asha.links.map((l) => l.$1), ['instagram', 'x', 'website']);

      // Only http(s) links are followed; a bare address gets https.
      final rahul = club.team.last;
      expect(rahul.instagram, isNull);
      expect(rahul.linkedin, 'https://linkedin.com/in/rahul');

      expect(club.partners.map((p) => (p.name, p.role, p.since)), [
        ('Acme Robotics', 'Title sponsor', 2022),
        ('Maker Space', '', null),
      ]);
      expect(club.partners.first.logoUrl,
          'https://media.myotherapp.in/acme-m.png');
      expect(club.partners.last.logoUrl, isNull);

      // No site on MyOtherApp in this answer: the website the club gave.
      expect(club.website, 'https://robotics.example.org');
    });

    test('/discover/clubs/{slug}: the public page, the same sections', () {
      final club = ClubInfo.fromDiscoverJson(clubPublicJson());

      expect(club.id, 12);
      expect(club.slug, 'robotics-club');
      expect(club.isPublicView, isTrue);
      expect(club.isFollowing, isFalse);
      expect(club.coverUrl, 'https://media.myotherapp.in/cover.jpg');
      expect(club.tagline, 'We build robots that play football.');
      expect(club.followersCount, 120);
      expect(club.eventsHeld, 9);
      expect(club.interests.map((i) => i.name), ['Robotics', 'Electronics']);
      expect(club.topics?.single.slug, 'development');
      expect(club.team.single.links.map((l) => l.$1), ['instagram', 'x']);
      expect(club.partners.single.name, 'Acme Robotics');
      // The club's own site comes first.
      expect(club.website, 'https://robotics-club.myotherapp.in');
    });

    test('a person or partner without a name is left out', () {
      final club = ClubInfo.fromJson(clubInfoJson(team: [
        {'name': '  ', 'role': 'Ghost'},
        {'name': 'Asha'},
      ], partners: [
        {'name': ''},
      ]));
      expect(club.team.map((p) => p.name), ['Asha']);
      expect(club.partners, isEmpty);
    });

    test('safe links', () {
      expect(safeWebUrl('tinkerhub.org'), 'https://tinkerhub.org');
      expect(safeWebUrl('http://a.example/x'), 'http://a.example/x');
      expect(safeWebUrl('javascript:alert(1)'), isNull);
      expect(safeWebUrl('mailto:a@b.co'), isNull);
      expect(safeWebUrl('example.org:8080/x'), 'https://example.org:8080/x');
      expect(safeWebUrl('  '), isNull);
      expect(hostLabel('https://www.tinkerhub.org/about'), 'tinkerhub.org');
    });
  });

  group('where a club is read from', () {
    late RouteAdapter api;
    late ClubPageSource source;

    setUp(() {
      api = useFakeApi();
      source = ClubPageSource(APIService.instance.dio,
          cache: ApiCache(
              shared: MemoryCacheStore(), personal: MemoryCacheStore()));
    });

    test('signed in, the club detail by id', () async {
      api.on('GET', '/clubs/info/12', clubInfoJson(following: true));

      final club = await source.fresh(const ClubKey(12, 'robotics-club'),
          signedIn: true);

      expect(api.requests.map((r) => r.path), ['/clubs/info/12']);
      expect(club.isFollowing, isTrue);
    });

    test('signed out, the public page by slug, without a session', () async {
      api.on('GET', '/discover/clubs/robotics-club', clubPublicJson());

      final club = await source.fresh(const ClubKey(12, 'robotics-club'),
          signedIn: false);

      final sent = api.requests.single;
      expect(sent.path, '/discover/clubs/robotics-club');
      expect(sent.extra['skipAuth'], isTrue);
      expect(club.isPublicView, isTrue);
    });

    test('signed out with no slug: the detail, whose 401 is the answer',
        () async {
      api.on('GET', '/clubs/info/12',
          {'message': 'Could not validate credentials'},
          status: 401);

      await expectLater(
        source.fresh(const ClubKey(12), signedIn: false),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)),
      );
      expect(api.requests.single.extra['skipAuth'], isTrue);
    });

    test('signed in from a link by slug: found publicly, then followed',
        () async {
      api
        ..on('GET', '/discover/clubs/robotics-club', clubPublicJson())
        ..on('GET', '/clubs/info/12', clubInfoJson(following: true));

      final club =
          await source.fresh(const ClubKey(0, 'robotics-club'), signedIn: true);

      expect(api.requests.map((r) => r.path),
          ['/discover/clubs/robotics-club', '/clubs/info/12']);
      expect(club.isFollowing, isTrue);
      expect(club.websiteUrl, 'https://robotics-club.myotherapp.in');
      expect(club.eventsHeld, 9);
    });
  });

  group('the club page', () {
    late RouteAdapter api;

    setUp(() {
      api = useFakeApi();
      api.on('GET', '/interests/list', const []);
    });

    testWidgets('shows the cover, tagline, team with roles and partners',
        (tester) async {
      api.on('GET', '/clubs/info/12', clubInfoJson(picture: _local));
      final opened = await _pump(
          tester, const ClubProfilePage(id: 12, slug: 'robotics-club'),
          signedIn: true);

      expect(find.byKey(const ValueKey('club-cover')), findsOneWidget);
      expect(find.text('We build robots that play football.'), findsOneWidget);
      expect(find.byKey(const ValueKey('club-team')), findsOneWidget);
      expect(find.text('TEAM'), findsOneWidget);
      expect(find.text('Asha Menon'), findsOneWidget);
      expect(find.text('President'), findsOneWidget);
      expect(find.text('Design lead'), findsOneWidget);
      expect(find.text('PARTNERS'), findsOneWidget);
      expect(find.text('Acme Robotics'), findsOneWidget);
      expect(find.text('Title sponsor · Since 2022'), findsOneWidget);
      expect(find.text('Maker Space'), findsOneWidget);
      // The team comes in the club's order.
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('club-member-0'))).dx,
        lessThan(
            tester.getTopLeft(find.byKey(const ValueKey('club-member-1'))).dx),
      );

      // A person's link opens.
      await _tap(
        tester,
        find.descendant(
          of: find.byKey(const ValueKey('club-member-0')),
          matching: find.byKey(const ValueKey('member-link-x')),
        ),
      );
      expect(opened.last, Uri.parse('https://x.com/asha'));

      // The website, prominently.
      await _tap(tester, find.byKey(const ValueKey('club-website')));
      expect(opened.last, Uri.parse('https://robotics.example.org'));
    });

    testWidgets('a club with no team or partners shows neither section',
        (tester) async {
      api.on('GET', '/clubs/info/12',
          clubInfoJson(picture: _local, team: const [], partners: const []));
      await _pump(tester, const ClubProfilePage(id: 12), signedIn: true);

      expect(find.byKey(const ValueKey('club-team')), findsNothing);
      expect(find.byKey(const ValueKey('club-partners')), findsNothing);
      // The cover still has its band.
      expect(find.byKey(const ValueKey('club-cover')), findsOneWidget);
    });

    testWidgets('signed in, follow goes to the server', (tester) async {
      api
        ..on('GET', '/clubs/info/12', clubInfoJson(picture: _local))
        ..on('POST', '/clubs/follow/12', {'is_following': true});
      await _pump(tester, const ClubProfilePage(id: 12), signedIn: true);

      expect(find.text('120 Followers'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('club-follow')));

      expect(api.sent('POST', '/clubs/follow/12'), hasLength(1));
      expect(find.text('UNFOLLOW'), findsOneWidget);
      expect(find.text('121 Followers'), findsOneWidget);
    });

    testWidgets('the header shares the club page on the website',
        (tester) async {
      api.on('GET', '/clubs/info/12', clubInfoJson(picture: _local));
      // Opened without the slug or name, as after a notification.
      await _pump(
        tester,
        const ClubIndividualPage(clubId: 12, clubname: '', clubSlug: ''),
        signedIn: true,
      );

      final header = tester.widget<ClubTabHeader>(find.byType(ClubTabHeader));
      expect(header.clubName, 'Robotics Club');
      expect(header.clubSlug, 'robotics-club');
      expect(clubShareUrl(slug: header.clubSlug, id: header.clubId),
          'https://myotherapp.in/clubs/robotics-club');
      expect(find.byKey(const ValueKey('club-share')), findsOneWidget);
    });
  });

  group('signed out', () {
    late RouteAdapter api;

    setUp(() {
      api = useFakeApi();
      api.on('GET', '/interests/list', const []);
    });

    testWidgets('the club page reads the public page, sections and all',
        (tester) async {
      api.on('GET', '/discover/clubs/robotics-club',
          clubPublicJson(picture: _local));
      await _pump(tester, const ClubProfilePage(id: 12, slug: 'robotics-club'),
          signedIn: false);

      expect(api.sent('GET', '/clubs/info/12'), isEmpty);
      expect(find.text('Robotics Club'), findsOneWidget);
      expect(find.text('We build robots that play football.'), findsOneWidget);
      expect(find.text('120 Followers · 9 events held'), findsOneWidget);
      expect(find.text('Asha Menon'), findsOneWidget);
      expect(find.text('Acme Robotics'), findsOneWidget);
      expect(
          find.textContaining('ROBOTICS-CLUB.MYOTHERAPP.IN'), findsOneWidget);
      expect(find.text('FOLLOW'), findsOneWidget);
    });

    testWidgets('follow asks to sign in, and sends nothing', (tester) async {
      api.on('GET', '/discover/clubs/robotics-club',
          clubPublicJson(picture: _local));
      await _pump(tester, const ClubProfilePage(id: 12, slug: 'robotics-club'),
          signedIn: false);

      await _tap(tester, find.byKey(const ValueKey('club-follow')));

      expect(find.text('Sign in to follow Robotics Club.'), findsOneWidget);
      expect(api.sent('POST', '/clubs/follow/12'), isEmpty);

      await tester.tap(find.byKey(const ValueKey('sign-in-prompt-go')));
      await _settle(tester);
      expect(find.text('sign-in screen'), findsOneWidget);
    });

    testWidgets('with no slug to read it by, it asks to sign in',
        (tester) async {
      api.on('GET', '/clubs/info/12',
          {'message': 'Could not validate credentials'},
          status: 401);
      await _pump(tester, const ClubProfilePage(id: 12), signedIn: false);

      expect(find.byKey(const ValueKey('club-sign-in-to-see')), findsOneWidget);
      expect(find.text('Sign in to see this club'), findsOneWidget);
    });

    testWidgets("a club the public can't see is said plainly", (tester) async {
      api.on('GET', '/discover/clubs/gone', {'message': 'Club not found'},
          status: 404);
      await _pump(tester, const ClubProfilePage(id: 12, slug: 'gone'),
          signedIn: false);

      expect(find.text("We couldn't find that club"), findsOneWidget);
    });

    testWidgets("the club's events come from its public list", (tester) async {
      api.on('GET', '/discover/clubs/robotics-club/events', {
        'items': [
          {
            'id': 70,
            'name': 'Bot Wars',
            'slug': 'bot-wars',
            'poster': null,
            'starts_at': '2025-01-10T10:00:00+05:30',
            'ends_at': '2025-01-10T13:00:00+05:30',
            'is_online': false,
            'has_fee': true,
            'category': {'id': 1, 'name': 'Competition'},
            'club': {
              'id': 12,
              'name': 'Robotics Club',
              'slug': 'robotics-club',
              'logo': null,
            },
            'going': 40,
            'status': 'ended',
            'url': 'https://myotherapp.in/events/bot-wars',
          },
        ],
        'total': 1,
        'offset': 0,
        'limit': 10,
      });
      await _pump(
        tester,
        const ClubEventsPage(
          clubId: 12,
          clubSlug: 'robotics-club',
          clubName: 'Robotics Club',
          clubLogo: '',
          isPastEvents: true,
        ),
        signedIn: false,
        width: 900,
      );

      final sent = api.sent('GET', '/discover/clubs/robotics-club/events');
      expect(sent, hasLength(1));
      expect(sent.single.queryParameters['when'], 'past');
      expect(api.sent('GET', '/clubs/12/events'), isEmpty);
      expect(find.text('Bot Wars'), findsOneWidget);
    });

    test('a public event card reads as a list item', () {
      final item = discoverEventAsListItem({
        'id': 70,
        'name': 'Bot Wars',
        'slug': 'bot-wars',
        'poster': 'https://media.myotherapp.in/p.jpg',
        'starts_at': '2025-01-10T10:00:00+05:30',
        'ends_at': '2025-01-10T12:30:00+05:30',
        'is_online': true,
        'has_fee': false,
        'category': {'id': 1, 'name': 'Talk'},
        'club': {'id': 12, 'name': 'Robotics Club'},
      });
      expect(item['event_datetime'], '2025-01-10T10:00:00+05:30');
      expect(item['duration'], 2.5);
      expect(item['is_online'], isTrue);
      expect(item['poster'], 'https://media.myotherapp.in/p.jpg');
    });
  });
}
