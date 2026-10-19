import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/entities/discover_club.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_club_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_sections.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'discover_fixtures.dart';

// The discover cards: one height in a rail whatever each holds, their rows
// lined up, exactly one price each -- and on an iPhone none at all for a
// paid online event, which the iOS app doesn't sell (canSellInApp).

DiscoverEvent _event(Map<String, dynamic> json) =>
    parseHome(homeBody(near: [json])).near.single;

DiscoverClub _club(Map<String, dynamic> json) =>
    parseHome(homeBody(clubs: [json])).clubs.single;

/// Cards as unlike each other as the owner's screenshot had them.
final _mixed = [
  _event({
    ...eventCard(1,
        name: 'Kerala Startup Mission: Founders Meetup and Demo Day 2026, '
            'with a title far too long for two lines',
        distanceKm: 3.2,
        going: 48),
    'club': {
      'id': 3,
      'name': 'A club with a name much longer than any card is wide',
      'slug': 'long',
      'logo': null,
    },
  }),
  _event(eventCard(2, name: 'Rust', online: true, hasFee: true)),
  _event(eventCard(3,
      name: 'Design Jam', hasFee: true, fee: 250, status: 'closing_soon')),
  _event({...eventCard(4, name: 'No club'), 'club': null}),
  _event(eventCard(5, name: 'Hack Night', status: 'live', going: 1200)),
];

Future<void> _pump(WidgetTester tester, Widget child,
    {double width = 375, double text = 1}) async {
  tester.view.physicalSize = Size(width, 900) * 2;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
          size: Size(width, 900), textScaler: TextScaler.linear(text)),
      child: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  ));
  await tester.pump();
}

Finder _card(int id) => find.byKey(ValueKey('discover-event-$id'));

Finder _inCard(int id, Finder matching) =>
    find.descendant(of: _card(id), matching: matching);

void main() {
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('a rail of event cards', () {
    testWidgets('every card is the same height, its rows lined up',
        (tester) async {
      // Wide enough to lay every card out at once.
      await _pump(tester, EventRail(events: _mixed), width: 1400);

      final heights = {
        for (final e in _mixed) tester.getSize(_card(e.id)).height,
      };
      expect(heights, hasLength(1));
      expect(heights.single,
          closeTo(DiscoverEventCard.heightFor(tester.element(_card(1))), 0.01));

      // The when line sits at the same height in each, a one-line name or
      // a two-line one, with a club or without.
      final whenTops = {
        for (final e in _mixed)
          tester
              .getTopLeft(_inCard(e.id, find.text(formatWhen(e.startsAt))))
              .dy,
      };
      expect(whenTops, hasLength(1));

      // And the bottom rows share a line too.
      final priceBottoms = {
        for (final id in [1, 3, 4])
          tester
              .getBottomLeft(
                  _inCard(id, find.byKey(const ValueKey('discover-event-price'))))
              .dy,
      };
      expect(priceBottoms, hasLength(1));
    });

    testWidgets('large text, long names, a small phone: nothing overflows',
        (tester) async {
      for (final text in [1.0, 1.35, 2.0, 3.1]) {
        await _pump(tester, EventRail(events: _mixed), text: text);
        expect(tester.takeException(), isNull, reason: 'text $text');
        await _pump(
            tester,
            Column(children: [for (final e in _mixed) DiscoverEventTile(event: e)]),
            text: text);
        expect(tester.takeException(), isNull, reason: 'rows, text $text');
        await _pump(tester, const EventCardSkeleton(), text: text);
        expect(tester.takeException(), isNull, reason: 'skeleton, text $text');
      }
    });

    testWidgets('one status badge, in the bottom row; nothing on the poster',
        (tester) async {
      await _pump(tester, EventRail(events: _mixed), width: 1400);
      expect(_inCard(3, find.text('Closing soon')), findsOneWidget);
      expect(_inCard(5, find.text('Live now')), findsOneWidget);
      // With a status, the badge rather than how many are going.
      expect(_inCard(5, find.textContaining('going')), findsNothing);
      expect(_inCard(1, find.text('48 going')), findsOneWidget);
    });
  });

  group('the price', () {
    final paidOnline = _event(
        eventCard(10, name: 'Masterclass', online: true, hasFee: true, fee: 499));
    final paidOnlineNoFee =
        _event(eventCard(11, name: 'Webinar', online: true, hasFee: true));
    final paidInPerson =
        _event(eventCard(12, name: 'Workshop', hasFee: true, fee: 250));
    final freeOnline = _event(eventCard(13, name: 'AMA', online: true));
    final events = [paidOnline, paidOnlineNoFee, paidInPerson, freeOnline];

    testWidgets(
        'on an iPhone a paid online event shows no price, no "Paid", no '
        '"Free"', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _pump(tester, EventRail(events: events), width: 1400);

      for (final id in [10, 11]) {
        expect(_inCard(id, find.textContaining('₹')), findsNothing);
        expect(_inCard(id, find.text('Paid')), findsNothing);
        expect(_inCard(id, find.text('Free')), findsNothing);
        expect(_inCard(id, find.byKey(const ValueKey('discover-event-price'))),
            findsNothing);
      }
      // A screen reader hears no price either.
      expect(
        tester.getSemantics(_card(10)).label,
        isNot(anyOf(contains('₹'), contains('Paid'))),
      );
      // In person it is sold, and priced; a free event still says so --
      // once.
      expect(_inCard(12, find.text('₹250')), findsOneWidget);
      expect(_inCard(13, find.text('Free')), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('the same in a list row', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _pump(tester,
          Column(children: [for (final e in events) DiscoverEventTile(event: e)]));
      expect(_inCard(10, find.textContaining('₹')), findsNothing);
      expect(_inCard(11, find.text('Paid')), findsNothing);
      expect(_inCard(12, find.text('₹250')), findsOneWidget);
      expect(_inCard(13, find.text('Free')), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('Android prices every event, once', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _pump(tester, EventRail(events: events), width: 1400);
      expect(_inCard(10, find.text('₹499')), findsOneWidget);
      expect(_inCard(11, find.text('Paid')), findsOneWidget);
      expect(_inCard(12, find.text('₹250')), findsOneWidget);
      expect(_inCard(13, find.text('Free')), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    test('cardPrice follows canSellInApp', () {
      expect(cardPrice(paidOnline, platform: TargetPlatform.iOS), isNull);
      expect(cardPrice(paidOnline, platform: TargetPlatform.android), '₹499');
      expect(cardPrice(paidInPerson, platform: TargetPlatform.iOS), '₹250');
      expect(cardPrice(freeOnline, platform: TargetPlatform.iOS), 'Free');
    });
  });

  group('a rail of club cards', () {
    testWidgets('every card is the same height, whatever it has',
        (tester) async {
      final clubs = [
        _club(clubCard(1, name: 'Tinkerhub', distanceKm: 2)),
        _club({
          ...clubCard(2,
              name: 'IEEE Student Branch, College of Engineering Trivandrum'),
          'tagline': null,
          'location_name': null,
          'interests': <String>[],
        }),
      ];
      await _pump(tester, ClubRail(clubs: clubs), width: 1000);
      final a = tester.getSize(find.byKey(const ValueKey('discover-club-club-1')));
      final b = tester.getSize(find.byKey(const ValueKey('discover-club-club-2')));
      expect(a, b);

      for (final text in [1.35, 3.1]) {
        await _pump(tester, ClubRail(clubs: clubs), text: text);
        expect(tester.takeException(), isNull, reason: 'text $text');
        await _pump(tester, Column(children: [
          for (final c in clubs) DiscoverClubCard(club: c),
        ]), text: text);
        expect(tester.takeException(), isNull, reason: 'list, text $text');
      }
    });
  });
}
