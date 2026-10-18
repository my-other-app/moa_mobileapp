import 'package:finnet/features/clubs/presentation/pages/pinned_clubs_section.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/shared/widgets/club_tab_header.dart';
import 'package:finnet/shared/widgets/explore_more_club_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('pinned clubs', () {
    testWidgets('a club with no logo draws a placeholder, not a red screen',
        (tester) async {
      // The crash: `club['logo']['thumbnail']` on `logo: null`.
      await tester.pumpWidget(_app(const PinnedClubsSection(pinnedClubs: [
        {'id': 1, 'name': 'No Logo Club', 'slug': 'nlc', 'logo': null},
        {'id': 2, 'name': 'Old Row', 'slug': 'old', 'logo': ''},
        {
          'id': 3,
          'name': 'Has Logo',
          'slug': 'has',
          'logo': {'thumbnail': null, 'medium': 'https://img/m.png'},
        },
      ])));

      expect(tester.takeException(), isNull);
      expect(find.text('No Logo Club'), findsOneWidget);
      expect(find.byKey(const ValueKey('club-logo-placeholder')),
          findsNWidgets(2));
      final logos = tester.widgetList<ClubLogo>(find.byType(ClubLogo));
      expect(logos.map((l) => l.url), [null, null, 'https://img/m.png']);
    });
  });

  group('the club header', () {
    Future<List<MethodCall>> pumpHeader(
      WidgetTester tester, {
      required String slug,
      int? id,
    }) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share'),
        (call) async {
          calls.add(call);
          return 'dev.fluttercommunity.plus/share/unavailable';
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('dev.fluttercommunity.plus/share'), null));

      await tester.pumpWidget(MaterialApp(
        home: ClubTabHeader(
          tabTitles: const ['PROFILE'],
          tabPages: const [SizedBox()],
          clubName: 'Tinkerhub CET',
          clubSlug: slug,
          clubId: id,
        ),
      ));
      return calls;
    }

    testWidgets("share sends the club's public page", (tester) async {
      final calls = await pumpHeader(tester, slug: 'tinkerhub-cet', id: 5);

      await tester.tap(find.byKey(const ValueKey('club-share')));
      await tester.pump();

      expect(calls, hasLength(1));
      final args = calls.single.arguments as Map;
      expect(args['text'], contains('https://myotherapp.in/clubs/tinkerhub-cet'));
      expect(args['text'], contains('Tinkerhub CET'));
    });

    testWidgets('without a slug it shares the id link', (tester) async {
      final calls = await pumpHeader(tester, slug: '', id: 5);

      await tester.tap(find.byKey(const ValueKey('club-share')));
      await tester.pump();

      expect((calls.single.arguments as Map)['text'],
          contains('https://myotherapp.in/clubs/5'));
    });

    testWidgets('with nothing to link to there is no share button',
        (tester) async {
      await pumpHeader(tester, slug: '');

      expect(find.byKey(const ValueKey('club-share')), findsNothing);
    });
  });

  testWidgets('the explore card has no JOIN THE TEAM button', (tester) async {
    await tester.pumpWidget(_app(const SingleChildScrollView(
      child: ExploreMoreClubCard(
        name: 'Tinkerhub CET',
        followersCount: 3,
        logo: '',
        interests: ['Tech'],
        id: 5,
        clubSlug: 'tinkerhub-cet',
        isFollowing: false,
      ),
    )));

    expect(find.text('JOIN THE TEAM'), findsNothing);
    expect(find.text('FOLLOW'), findsOneWidget);
    // No random stock photo for a club without a logo.
    expect(find.byKey(const ValueKey('club-logo-placeholder')), findsOneWidget);
  });
}
