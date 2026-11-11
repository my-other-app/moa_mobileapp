import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/speakers/data/speakers_api.dart';
import 'package:finnet/features/speakers/domain/speaker.dart';
import 'package:finnet/features/speakers/presentation/pages/speaker_page.dart';
import 'package:finnet/features/speakers/presentation/speakers_routes.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../events/events_fakes.dart';

/// `GET /speakers/{slug}` as the contract has it.
Map<String, dynamic> _speaker({
  String slug = 'ananya-iyer',
  bool following = false,
  int followers = 41,
  List<Map<String, dynamic>>? upcoming,
  List<Map<String, dynamic>>? past,
}) =>
    {
      'slug': slug,
      'name': 'Ananya Iyer',
      'headline': 'ML engineer, Sarvam',
      'bio': 'Ananya builds speech models for Indian languages.',
      'photo': null,
      'links': {
        'website': 'ananya.dev',
        'linkedin': 'https://www.linkedin.com/in/ananya',
        'x': null,
        'github': 'https://github.com/ananya',
        'other': 'javascript:alert(1)',
      },
      'city': 'Bengaluru',
      'topics': [
        {'id': 3, 'name': 'AI'},
        'Speech',
        7,
      ],
      'claimed': true,
      'followers_count': followers,
      'following': following,
      'talks': {
        'upcoming': upcoming ??
            [
              {
                'event_id': 7,
                'slug': 'hack-night',
                'name': 'Hack Night',
                'date': '2030-12-01T10:00:00+00:00',
                'club': {'id': 3, 'name': 'Tinkerhub'},
                'talk_title': 'Speech models for Bharat',
                'poster': null,
              }
            ],
        'past': past ??
            [
              {
                'event_id': 4,
                'name': 'AI Day',
                'date': '2025-02-01T10:00:00+00:00',
                'club': 'GDG Kochi',
              },
              {'name': 'No id'},
            ],
      },
    };

void main() {
  group('reading a speaker', () {
    test('the profile, its safe links in order, its topics and talks', () {
      final p = SpeakerProfile.fromJson(_speaker(), slug: 'x');
      expect(p.slug, 'ananya-iyer');
      expect(p.headline, 'ML engineer, Sarvam');
      expect(p.links.map((l) => l.kind), [
        PersonLinkKind.website,
        PersonLinkKind.linkedin,
        PersonLinkKind.github,
      ]);
      expect(p.links.first.uri.toString(), 'https://ananya.dev');
      expect(p.links.last.label, 'GitHub');
      expect(p.topics, ['AI', 'Speech']);
      expect(p.followersCount, 41);
      expect(p.claimed, isTrue);
      expect(p.upcoming.single.talkTitle, 'Speech models for Bharat');
      expect(p.upcoming.single.clubName, 'Tinkerhub');
      expect(p.upcoming.single.eventRoute, '/events/hack-night');
      expect(p.past.single.eventRoute, '/events/4');
      expect(p.past.single.clubName, 'GDG Kochi');
    });

    test('an empty answer is still a page, never a crash', () {
      final p = SpeakerProfile.fromJson('nonsense', slug: 'x');
      expect(p.slug, 'x');
      expect(p.name, 'Speaker');
      expect(p.links, isEmpty);
      expect(p.followersCount, 0);
      expect(p.upcoming, isEmpty);
    });

    test("an event's speaker: their page's slug and their talk", () {
      final person = EventPerson.speakerFromJson({
        'name': 'Ananya Iyer',
        'profile_slug': 'ananya-iyer',
        'talk_title': '  Speech models for Bharat ',
      })!;
      expect(person.profileSlug, 'ananya-iyer');
      expect(person.talkTitle, 'Speech models for Bharat');
      expect(person.hasMore, isTrue);
      // Hidden (null), or nothing the app could put in an address.
      expect(EventPerson.speakerFromJson({'name': 'A', 'profile_slug': null})!
          .profileSlug, isNull);
      expect(EventPerson.speakerFromJson({'name': 'A', 'profile_slug': 'a/b'})!
          .profileSlug, isNull);
      expect(EventPerson.speakerFromJson({'name': 'A'})!.hasMore, isFalse);
    });

    test('a GitHub link is GitHub wherever it comes from', () {
      expect(personLinkKindOf(Uri.parse('https://github.com/a')),
          PersonLinkKind.github);
    });
  });

  group('the calls', () {
    test('a page, a merged one, and one that is not there', () async {
      final api = useFakeApi();
      api
        ..on('GET', '/speakers/ananya-iyer', _speaker())
        ..on('GET', '/speakers/old-name', {'redirect_slug': 'ananya-iyer'})
        ..on('GET', '/speakers/gone-301', {'redirect_slug': 'ananya-iyer'},
            status: 301);
      final speakers = SpeakersApi();
      expect(await speakers.profile('ananya-iyer'), isA<SpeakerFound>());
      expect(
          await speakers.profile('old-name'),
          isA<SpeakerMoved>()
              .having((m) => m.slug, 'slug', 'ananya-iyer'));
      expect(await speakers.profile('gone-301'), isA<SpeakerMoved>());
      // Hidden, or a server without speaker pages: 404.
      expect(await speakers.profile('hidden'), isA<SpeakerMissing>());
    });

    test('follow and unfollow', () async {
      final api = useFakeApi();
      api
        ..on('POST', '/speakers/ananya-iyer/follow', {'ok': true})
        ..on('DELETE', '/speakers/ananya-iyer/follow', null, status: 204);
      await SpeakersApi().follow('ananya-iyer');
      await SpeakersApi().unfollow('ananya-iyer');
      expect(api.sent('POST', '/speakers/ananya-iyer/follow'), hasLength(1));
      expect(api.sent('DELETE', '/speakers/ananya-iyer/follow'), hasLength(1));
    });
  });

  group('the page', () {
    late RouteAdapter api;
    setUp(() => api = useFakeApi());

    Future<({List<String> went, List<Uri> opened})> pump(
      WidgetTester tester, {
      String slug = 'ananya-iyer',
      bool signedIn = true,
    }) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final went = <String>[];
      final opened = <Uri>[];
      final router = GoRouter(initialLocation: '/speakers/$slug', routes: [
        ...speakersRoutes,
        GoRoute(
          path: '/events/:ref',
          builder: (_, state) {
            went.add(state.uri.toString());
            return const Scaffold(body: Text('the event'));
          },
        ),
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
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      return (went: went, opened: opened);
    }

    testWidgets('photo, headline, bio, links and talks', (tester) async {
      api.on('GET', '/speakers/ananya-iyer', _speaker());
      final h = await pump(tester);

      expect(find.text('Ananya Iyer'), findsOneWidget);
      expect(find.text('ML engineer, Sarvam'), findsOneWidget);
      expect(find.text('Bengaluru · 41 followers'), findsOneWidget);
      expect(find.text('Ananya builds speech models for Indian languages.'),
          findsOneWidget);
      expect(find.byKey(SpeakerPage.upcomingKey), findsOneWidget);
      expect(find.byKey(SpeakerPage.pastKey), findsOneWidget);
      expect(find.text('“Speech models for Bharat”'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('speaker-link-github')));
      await tester.pump();
      expect(h.opened.single.toString(), 'https://github.com/ananya');

      await tester.tap(find.byKey(const ValueKey('speaker-talk-7')));
      await tester.pumpAndSettle();
      expect(h.went.single, '/events/hack-night');
    });

    testWidgets('Follow, then Unfollow; the count follows', (tester) async {
      api
        ..on('GET', '/speakers/ananya-iyer', _speaker())
        ..on('POST', '/speakers/ananya-iyer/follow', {'ok': true})
        ..on('DELETE', '/speakers/ananya-iyer/follow', {'ok': true});
      await pump(tester);

      expect(find.text('FOLLOW'), findsOneWidget);
      await tester.tap(find.byKey(SpeakerPage.followKey));
      await tester.pumpAndSettle();
      expect(api.sent('POST', '/speakers/ananya-iyer/follow'), hasLength(1));
      expect(find.text('UNFOLLOW'), findsOneWidget);
      expect(find.text('Bengaluru · 42 followers'), findsOneWidget);

      await tester.tap(find.byKey(SpeakerPage.followKey));
      await tester.pumpAndSettle();
      expect(api.sent('DELETE', '/speakers/ananya-iyer/follow'), hasLength(1));
      expect(find.text('FOLLOW'), findsOneWidget);
      expect(find.text('Bengaluru · 41 followers'), findsOneWidget);
    });

    testWidgets('a refused follow takes itself back', (tester) async {
      api
        ..on('GET', '/speakers/ananya-iyer', _speaker())
        ..on('POST', '/speakers/ananya-iyer/follow', {'message': 'No'},
            status: 500);
      await pump(tester);

      await tester.tap(find.byKey(SpeakerPage.followKey));
      await tester.pumpAndSettle();

      expect(find.text('FOLLOW'), findsOneWidget);
      expect(find.text('Bengaluru · 41 followers'), findsOneWidget);
    });

    testWidgets('signed out, Follow asks for sign-in and sends nothing',
        (tester) async {
      api.on('GET', '/speakers/ananya-iyer', _speaker());
      await pump(tester, signedIn: false);

      await tester.tap(find.byKey(SpeakerPage.followKey));
      await tester.pumpAndSettle();

      expect(find.byType(SignInPromptSheet), findsOneWidget);
      expect(api.sent('POST', '/speakers/ananya-iyer/follow'), isEmpty);
    });

    testWidgets('a merged speaker opens the page they were merged into',
        (tester) async {
      api
        ..on('GET', '/speakers/old-name', {'redirect_slug': 'ananya-iyer'})
        ..on('GET', '/speakers/ananya-iyer', _speaker());
      await pump(tester, slug: 'old-name');
      expect(find.text('Ananya Iyer'), findsOneWidget);
    });

    testWidgets('hidden, or a server without speaker pages: said so',
        (tester) async {
      final h = await pump(tester, slug: 'hidden');
      expect(find.byKey(SpeakerPage.missingKey), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('speaker-open-website')));
      await tester.pump();
      expect(h.opened.single.toString(), 'https://myotherapp.in/speakers/hidden');
    });

    testWidgets('no talks yet: said so', (tester) async {
      api.on('GET', '/speakers/ananya-iyer',
          _speaker(upcoming: const [], past: const []));
      await pump(tester);
      expect(find.byKey(SpeakerPage.upcomingKey), findsNothing);
      expect(find.textContaining('No talks listed yet'), findsOneWidget);
    });
  });
}
