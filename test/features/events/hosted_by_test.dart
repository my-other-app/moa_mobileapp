import 'package:finnet/common/models/events/cohost_model.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/hosted_by.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../discover/discover_fixtures.dart';

// "Hosted by A and B" on a co-hosted event's page, and the cards' short
// "A and B" / "A + 2" (feature-register cohosts-contract.md §8, §11).

const _host = EventCohost(
    clubId: 1, name: 'Design Society', slug: 'design-society');
const _robotics =
    EventCohost(clubId: 9, name: 'Robotics Club', slug: 'robotics-club');
const _quiz = EventCohost(clubId: 12, name: 'Quiz Club', slug: 'quiz-club');

Future<List<EventCohost>> _pumpLine(
  WidgetTester tester,
  List<EventCohost> cohosts, {
  EventCohost host = _host,
  bool openable = true,
}) async {
  final opened = <EventCohost>[];
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 358,
          child: HostedByLine(
            host: host,
            cohosts: cohosts,
            onOpen: openable ? opened.add : null,
          ),
        ),
      ),
    ),
  ));
  return opened;
}

/// The line's words, as drawn.
String _words(WidgetTester tester) => tester
    .widget<Text>(find.byKey(HostedByLine.namesKey))
    .textSpan!
    .toPlainText();

void main() {
  group('the "Hosted by" line', () {
    testWidgets('one co-host: "Hosted by A and B"', (tester) async {
      await _pumpLine(tester, const [_robotics]);
      expect(_words(tester), 'Hosted by Design Society and Robotics Club');
    });

    testWidgets('more: "Hosted by A, B and C"', (tester) async {
      await _pumpLine(tester, const [_robotics, _quiz]);
      expect(_words(tester),
          'Hosted by Design Society, Robotics Club and Quiz Club');
    });

    testWidgets("the host's logo first, then each co-host's, overlapping",
        (tester) async {
      await _pumpLine(tester, const [_robotics, _quiz]);
      final lefts = [
        for (var i = 0; i < 3; i++)
          tester.getTopLeft(find.byKey(ClubLogoStack.logoKey(i))).dx,
      ];
      expect(lefts, orderedEquals([...lefts]..sort()));
      final width =
          tester.getSize(find.byKey(ClubLogoStack.logoKey(0))).width;
      // Each one covers part of the one before it.
      expect(lefts[1] - lefts[0], lessThan(width));
      // Without logos, each club's initials.
      expect(find.text('DS'), findsOneWidget);
      expect(find.text('RC'), findsOneWidget);
      expect(find.text('QC'), findsOneWidget);
    });

    testWidgets("each name opens that club's page", (tester) async {
      final opened = await _pumpLine(tester, const [_robotics, _quiz]);
      await tester.tapOnText(find.textRange.ofSubstring('Robotics Club'));
      await tester.tapOnText(find.textRange.ofSubstring('Design Society'));
      await tester.tapOnText(find.textRange.ofSubstring('Quiz Club'));
      expect(opened.map((c) => c.clubId), [9, 1, 12]);
      // "Hosted by" and "and" open nothing.
      await tester.tapOnText(find.textRange.ofSubstring('Hosted by'));
      expect(opened, hasLength(3));
    });

    testWidgets('a logo opens its club too', (tester) async {
      final opened = await _pumpLine(tester, const [_robotics]);
      await tester.tap(find.byKey(ClubLogoStack.logoKey(1)));
      expect(opened.single.name, 'Robotics Club');
    });

    testWidgets('a club that cannot be opened (no id, no slug) stays still',
        (tester) async {
      final opened = await _pumpLine(
          tester, const [EventCohost(clubId: 0, name: 'Ghost Club')]);
      await tester.tapOnText(find.textRange.ofSubstring('Ghost Club'));
      expect(opened, isEmpty);
    });

    testWidgets('screen readers hear each name as something to tap',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpLine(tester, const [_robotics]);
      final node = find.semantics.byLabel('Robotics Club').evaluate().single;
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      // The logos are for the eye: their initials are not read out.
      expect(find.semantics.byLabel('RC').evaluate(), isEmpty);
      semantics.dispose();
    });
  });

  group("a list's card", () {
    Future<void> pumpCard(WidgetTester tester, List<String> cohosts) async {
      final router = GoRouter(routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              child: EventCard(
                title: 'Hack the Campus',
                organizer: 'Design Society',
                cohosts: cohosts,
                tags: const ['Hackathon', 'Offline', 'Free'],
                onTap: () {},
                orgImage: '',
                eventId: 42,
                clubId: 1,
                clubSlug: 'design-society',
                eventSlug: 'hack-the-campus',
              ),
            ),
          ),
        ),
      ]);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    }

    String organizer(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('event-card-organizer')))
        .data!;

    testWidgets('reads "A and B" with one co-host', (tester) async {
      await pumpCard(tester, const ['Robotics Club']);
      expect(organizer(tester), 'Design Society and Robotics Club');
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('event-card-organizer')))
              .semanticsLabel,
          'Hosted by Design Society and Robotics Club');
    });

    testWidgets('reads "A + 2" with two', (tester) async {
      await pumpCard(tester, const ['Robotics Club', 'Quiz Club']);
      expect(organizer(tester), 'Design Society + 2');
    });

    testWidgets('the host alone without co-hosts, as before', (tester) async {
      await pumpCard(tester, const []);
      expect(organizer(tester), 'Design Society');
      expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('event-card-organizer')))
              .semanticsLabel,
          isNull);
    });
  });

  group('a discover card', () {
    Future<void> pump(WidgetTester tester, Map<String, dynamic> json) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DiscoverEventCard(event: parseEvent(json)!),
        ),
      ));
    }

    String club(WidgetTester tester) => tester
        .widget<Text>(find.byKey(const ValueKey('discover-event-club')))
        .data!;

    testWidgets('names the host and its co-host', (tester) async {
      await pump(tester, {
        ...eventCard(7),
        'cohosts': [
          {'club_id': 9, 'name': 'Robotics Club', 'logo': null},
        ],
      });
      expect(club(tester), 'Tinkerhub and Robotics Club');
      expect(discoverEventLabel(parseEvent({
        ...eventCard(7),
        'cohosts': [
          {'club_id': 9, 'name': 'Robotics Club'},
          {'club_id': 12, 'name': 'Quiz Club'},
        ],
      })!), contains('Hosted by Tinkerhub, Robotics Club and Quiz Club'));
    });

    testWidgets('"A + 2" with more', (tester) async {
      await pump(tester, {
        ...eventCard(7),
        'cohosts': [
          {'club_id': 9, 'name': 'Robotics Club'},
          {'club_id': 12, 'name': 'Quiz Club'},
        ],
      });
      expect(club(tester), 'Tinkerhub + 2');
    });

    testWidgets('the club alone from an older server', (tester) async {
      await pump(tester, eventCard(7));
      expect(club(tester), 'Tinkerhub');
      expect(discoverEventLabel(parseEvent(eventCard(7))!),
          isNot(contains('Hosted by')));
    });
  });
}
