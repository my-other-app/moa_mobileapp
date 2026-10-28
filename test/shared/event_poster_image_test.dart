import 'package:cached_network_image/cached_network_image.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:finnet/shared/widgets/event_cover.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _bucket =
    'https://moa-media.s3.ap-south-1.amazonaws.com/media/clubs/logos';

/// A presigned poster URL as the API sends it: a fresh signature each call.
String _signed(String file, [String signature = 'abc123']) =>
    '$_bucket/$file?X-Amz-Algorithm=AWS4-HMAC-SHA256'
    '&X-Amz-Expires=3600&X-Amz-Signature=$signature';

final _poster = {
  'thumbnail': _signed('e7f1.thumbnail.jpeg'),
  'medium': _signed('e7f1.medium.jpeg'),
  'large': _signed('e7f1.large.jpeg'),
  'original': _signed('e7f1.jpeg'),
};

Widget _host(Widget child, {double width = 320, double height = 400}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

void main() {
  group('pickPosterUrl', () {
    test('cards take large, then original, medium, thumbnail', () {
      // A card is up to ~360pt wide: over 1000px on a 3x phone.
      expect(pickPosterUrl(_poster), _poster['large']);
      expect(
        pickPosterUrl({..._poster, 'large': null}),
        _poster['original'],
      );
      expect(
        pickPosterUrl({'medium': _poster['medium'], 'thumbnail': 'x'}),
        _poster['medium'],
      );
      expect(
        pickPosterUrl({'thumbnail': _poster['thumbnail']}),
        _poster['thumbnail'],
      );
    });

    test('the event page takes the original, then large, then medium', () {
      // As wide as the screen: an old poster's large is only 640px across.
      expect(
          pickPosterUrl(_poster, slot: PosterSlot.hero), _poster['original']);
      expect(
        pickPosterUrl({..._poster, 'original': ''}, slot: PosterSlot.hero),
        _poster['large'],
      );
      expect(
        pickPosterUrl({'medium': _poster['medium']}, slot: PosterSlot.hero),
        _poster['medium'],
      );
    });

    test('each slot asks first for a size at least twice as wide as it is', () {
      // The server's boxes for the sizes (app/core/storage/shapes.py).
      const widths = {'thumbnail': 240, 'medium': 540, 'large': 1080};
      // The widest each slot is drawn, in points.
      const slots = {PosterSlot.thumb: 120.0, PosterSlot.card: 540.0};
      slots.forEach((slot, points) {
        final first = posterSizePreference[slot]!.first;
        expect(widths[first]! >= 2 * points, isTrue, reason: '$slot');
      });
      expect(posterSizePreference[PosterSlot.hero]!.first, 'original');
    });

    test('small thumbnails take the thumbnail', () {
      expect(
          pickPosterUrl(_poster, slot: PosterSlot.thumb), _poster['thumbnail']);
    });

    test('no poster, an empty one, or junk means no URL', () {
      expect(pickPosterUrl(null), isNull);
      expect(pickPosterUrl(<String, dynamic>{}), isNull);
      expect(pickPosterUrl({'medium': '', 'large': '   '}), isNull);
      expect(pickPosterUrl({'medium': 42}), isNull);
      expect(pickPosterUrl({'medium': 'media/e7f1.jpeg'}), isNull);
      expect(pickPosterUrl(''), isNull);
    });

    test('a single URL is used as it is', () {
      expect(pickPosterUrl(_poster['large']), _poster['large']);
    });
  });

  group('posterCacheKey', () {
    test('drops the signature, so a re-signed URL hits the same entry', () {
      final today = _signed('e7f1.medium.jpeg', 'aaa');
      final tomorrow = _signed('e7f1.medium.jpeg', 'bbb');
      expect(posterCacheKey(today), '$_bucket/e7f1.medium.jpeg');
      expect(posterCacheKey(today), posterCacheKey(tomorrow));
    });

    test('different posters and sizes keep different keys', () {
      expect(posterCacheKey(_signed('e7f1.medium.jpeg')),
          isNot(posterCacheKey(_signed('e7f1.large.jpeg'))));
      expect(posterCacheKey(_signed('e7f1.medium.jpeg')),
          isNot(posterCacheKey(_signed('a9c0.medium.jpeg'))));
    });

    test('a URL without a query is its own key', () {
      expect(posterCacheKey('$_bucket/x.jpeg'), '$_bucket/x.jpeg');
      expect(posterCacheKey('$_bucket/x.jpeg#top'), '$_bucket/x.jpeg');
    });
  });

  group('EventPosterImage', () {
    testWidgets('no poster draws the cover and fetches nothing',
        (tester) async {
      await tester.pumpWidget(_host(EventPosterImage(
        poster: null,
        eventId: 42,
        categoryName: 'Workshop',
        startsAt: DateTime.utc(2026, 10, 16, 20),
      )));

      expect(find.byType(EventCover), findsOneWidget);
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.text('WORKSHOP'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('loads the large poster, cached by its path', (tester) async {
      await tester.pumpWidget(_host(EventPosterImage(
        poster: _poster,
        eventId: 42,
      )));

      final image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.imageUrl, _poster['large']);
      expect(image.cacheKey, '$_bucket/e7f1.large.jpeg');
    });

    testWidgets('the event page loads the original poster', (tester) async {
      await tester.pumpWidget(_host(EventPosterImage(
        poster: _poster,
        eventId: 42,
        slot: PosterSlot.hero,
      )));

      final image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(image.imageUrl, _poster['original']);
      expect(image.cacheKey, '$_bucket/e7f1.jpeg');
    });

    testWidgets('shows the cover while loading and if the poster fails',
        (tester) async {
      await tester.pumpWidget(_host(EventPosterImage(
        poster: _poster,
        eventId: 42,
        categoryName: 'Talk',
        startsAt: DateTime.utc(2026, 10, 16, 20),
      )));
      final image =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

      // What the image shows in each state, rendered on its own.
      await tester.pumpWidget(_host(Builder(
        builder: (context) => image.placeholder!(context, image.imageUrl),
      )));
      expect(find.byKey(EventPosterImage.loadingKey), findsOneWidget);
      expect(find.text('TALK'), findsOneWidget);

      await tester.pumpWidget(_host(Builder(
        builder: (context) => image.errorWidget!(
          context,
          image.imageUrl,
          Exception('403 Forbidden'),
        ),
      )));
      expect(find.byKey(EventPosterImage.fallbackKey), findsOneWidget);
      expect(find.text('TALK'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      // Never collapses: the fallback fills the poster's box.
      expect(tester.getSize(find.byKey(EventPosterImage.fallbackKey)),
          const Size(320, 400));
    });

    test('reads an event as the API sends it', () {
      final widget = EventPosterImage.fromEvent({
        'id': 7,
        'poster': null,
        'category': {'id': 2, 'name': 'Workshop'},
        'event_datetime': '2026-10-17T10:00:00+05:30',
        'is_online': true,
      });
      expect(widget.eventId, 7);
      expect(widget.url, isNull);
      expect(widget.categoryId, 2);
      expect(widget.categoryName, 'Workshop');
      expect(widget.startsAt, DateTime.utc(2026, 10, 17, 4, 30));
      expect(widget.isOnline, isTrue);
    });
  });

  group('EventCard', () {
    Widget card(
            {Object? poster, EventCardStatus status = EventCardStatus.none}) =>
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: EventCard(
                title: 'Build a robot',
                organizer: 'Tinkerhub CET',
                poster: poster,
                categoryId: 2,
                categoryName: 'Workshop',
                startsAt: DateTime.utc(2026, 10, 16, 20),
                tags: const ['Workshop', 'Offline', 'Free', '2 Hours'],
                onTap: () {},
                orgImage: '',
                eventId: 7,
                clubId: 1,
                clubSlug: 'tinkerhub-cet',
                eventSlug: 'build-a-robot',
                status: status,
              ),
            ),
          ),
        );

    testWidgets('draws the cover for an event without a poster',
        (tester) async {
      await tester.pumpWidget(card(status: EventCardStatus.registered));

      expect(find.byType(EventCover), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      // The cover fills the poster's space rather than collapsing.
      final size = tester.getSize(find.byType(EventCover));
      expect(size.height, greaterThan(200));
      // The status badge still sits over it.
      expect(find.text('Registered'), findsOneWidget);
    });

    testWidgets('loads the large poster when there is one', (tester) async {
      await tester.pumpWidget(card(poster: _poster));

      final image = tester.widget<CachedNetworkImage>(find.byWidgetPredicate(
          (w) => w is CachedNetworkImage && w.imageUrl == _poster['large']));
      expect(image.cacheKey, '$_bucket/e7f1.large.jpeg');
    });
  });
}
