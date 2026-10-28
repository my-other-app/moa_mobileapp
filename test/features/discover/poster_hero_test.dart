import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_sections.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';
import 'package:finnet/shared/widgets/poster_hero.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'discover_fixtures.dart';

// A rail's poster flies into the event's page. Its tag must be unique on
// the screen -- the same event can sit in two rails at once -- and must
// travel with the tap, for the page to fly it in.

final DiscoverEvent _hackNight = parseEvent(eventCard(1, name: 'Hack Night'))!;

Future<GoRouter> _pump(WidgetTester tester, Widget body) async {
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => Scaffold(body: ListView(children: [body])),
    ),
    GoRoute(
      path: '/events/:id',
      builder: (_, state) {
        final extra = state.extra as Map?;
        final hint = extra?['posterHint'] as PosterHint?;
        return Scaffold(
          body: Text('event ${state.pathParameters['id']} '
              '${extra?['posterHero']} ${hint?.categoryName}'),
        );
      },
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(routerConfig: router));
  await tester.pump();
  return router;
}

List<String> _tags(WidgetTester tester) => [
      for (final hero in tester.widgetList<Hero>(find.byType(Hero)))
        hero.tag as String,
    ];

void main() {
  testWidgets('one event in two rails: two posters, two different tags',
      (tester) async {
    await _pump(
      tester,
      Column(children: [
        EventRail(events: [_hackNight], heroScope: 'this-week'),
        EventRail(events: [_hackNight], heroScope: 'popular'),
      ]),
    );

    final tags = _tags(tester);
    expect(tags, hasLength(2));
    expect(tags.toSet(), hasLength(2));
  });

  testWidgets('a rail nobody named has no heroes at all', (tester) async {
    await _pump(tester, EventRail(events: [_hackNight]));

    expect(find.byType(Hero), findsNothing);
  });

  testWidgets(
      "a tap carries the poster's tag, and what it is drawn from, to the "
      "event's page", (tester) async {
    await _pump(tester, EventRail(events: [_hackNight], heroScope: 'near'));
    final tag = _tags(tester).single;

    await tester.tap(find.text('Hack Night'));
    await tester.pumpAndSettle();

    // The page draws the same cover while it loads: same category.
    expect(find.text('event 1 $tag Workshop'), findsOneWidget);
  });

  testWidgets("while a page's poster loads, the card's poster stands in",
      (tester) async {
    AppImageCaches.debugOverride(public: _Slow(), private: _Slow());
    addTearDown(AppImageCaches.debugOverride);
    await tester.pumpWidget(const MaterialApp(
      home: EventPosterImage(
        poster: 'https://media.myotherapp.in/events/p.large.jpeg',
        eventId: 1,
        slot: PosterSlot.hero,
        placeholder: Text('the card poster'),
      ),
    ));
    await tester.pump();

    expect(
        find.descendant(
            of: find.byKey(EventPosterImage.loadingKey),
            matching: find.text('the card poster')),
        findsOneWidget);
  });

  testWidgets(
      "the stand-in is decoded as the card decoded it, so it is already "
      "in memory", (tester) async {
    AppImageCaches.debugOverride(public: _Slow(), private: _Slow());
    addTearDown(AppImageCaches.debugOverride);
    const hint = PosterHint(
      poster: 'https://media.myotherapp.in/events/p.medium.jpeg',
      size: Size(248, 139.5),
    );
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(devicePixelRatio: 3, size: Size(400, 800)),
        child: SizedBox(width: 358, height: 358, child: hint.cardPoster(1)),
      ),
    ));

    final image =
        tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
    // The card's 248 points, at 3x: the same decode, the same cached copy.
    expect(image.memCacheWidth, 744);
    // Drawn whole, as the card drew it (PosterPicture), never cropped.
    expect(image.imageBuilder, isNotNull);
  });

  test("a card's poster is offered only when there is one to offer", () {
    const size = Size(248, 139.5);
    expect(const PosterHint(size: size).cardPoster(1), isNull,
        reason: 'a drawn cover: the page draws its own');
    expect(const PosterHint(poster: 'https://x/p.jpeg').cardPoster(1), isNull,
        reason: "without the card's size it could not be the same picture");
    expect(
        const PosterHint(poster: 'https://x/p.jpeg', size: size).cardPoster(1),
        isNotNull);
  });
}

/// A picture that is still on its way.
class _Slow extends Fake implements BaseCacheManager {
  @override
  Stream<FileResponse> getFileStream(String url,
          {String? key, Map<String, String>? headers, bool? withProgress}) =>
      StreamController<FileResponse>().stream;

  @override
  Future<FileInfo?> getFileFromCache(String key,
          {bool ignoreMemCache = false}) async =>
      null;
}
