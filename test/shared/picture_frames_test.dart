import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_rail.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/discover/discover_fixtures.dart';

// One shape for each picture, wherever it is shown (agreed Oct 2026): an
// event's poster 4:5, never cropped; a club's logo square, whole when it is
// not (a wordmark) on a white tile.

/// A plain picture [width] x [height], as PNG bytes. Real decoding: call
/// inside `tester.runAsync`.
Future<Uint8List> _png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3366CC),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

/// Lets a picture decode (real I/O), then draws again.
Future<void> _decode(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

double _ratio(Size size) => size.width / size.height;

void main() {
  group('a poster', () {
    test('fills a 4:5 frame only when it is 4:5, within 1%', () {
      const frame = 4 / 5;
      expect(PosterPicture.fits(const Size(1080, 1350), frame), isTrue);
      expect(PosterPicture.fits(const Size(1085, 1350), frame), isTrue);
      expect(PosterPicture.fits(const Size(1080, 1080), frame), isFalse);
      expect(PosterPicture.fits(const Size(1600, 900), frame), isFalse);
      expect(PosterPicture.fits(const Size(1080, 1920), frame), isFalse);
      expect(PosterPicture.fits(Size.zero, frame), isFalse);
    });

    test('a small frame gets a softer blur', () {
      expect(PosterPicture.blurFor(56), lessThan(PosterPicture.blurFor(358)));
    });

    Future<void> pumpPoster(WidgetTester tester, int w, int h) async {
      final bytes = (await tester.runAsync(() => _png(w, h)))!;
      await tester.pumpWidget(_host(Center(
        child: SizedBox(
          width: 200,
          height: 250,
          child: PosterPicture(image: MemoryImage(bytes)),
        ),
      )));
      await _decode(tester);
    }

    testWidgets('of another shape is whole, on a blurred copy of itself',
        (tester) async {
      await pumpPoster(tester, 160, 90);

      final picture = tester.widget<Image>(find.byKey(PosterPicture.pictureKey));
      expect(picture.fit, BoxFit.contain);
      expect(find.byKey(PosterPicture.backdropKey), findsOneWidget);
      // The copy behind is the same picture: one download, one decode.
      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images.map((i) => i.image).toSet(), hasLength(1));
      // The frame keeps its own shape whatever the poster's.
      expect(tester.getSize(find.byType(PosterPicture)), const Size(200, 250));
    });

    testWidgets('already 4:5 fills its frame, with nothing blurred',
        (tester) async {
      await pumpPoster(tester, 80, 100);

      expect(find.byKey(PosterPicture.backdropKey), findsNothing);
      final picture = tester.widget<Image>(find.byKey(PosterPicture.pictureKey));
      expect(picture.fit, BoxFit.contain);
    });

    testWidgets("a feed card's poster is 4:5, as wide as the card",
        (tester) async {
      await tester.pumpWidget(_host(SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: EventCard(
          title: 'Build a robot',
          organizer: 'Tinkerhub CET',
          categoryId: 2,
          categoryName: 'Workshop',
          startsAt: DateTime.utc(2026, 10, 16, 20),
          tags: const ['Workshop'],
          onTap: () {},
          orgImage: '',
          eventId: 7,
          clubId: 1,
          clubSlug: 'tinkerhub-cet',
          eventSlug: 'build-a-robot',
        ),
      )));

      final poster = tester.getSize(find.byType(EventPosterImage));
      expect(_ratio(poster), closeTo(4 / 5, 0.001));
      expect(poster.width, 800 - 32);
    });

    testWidgets("a discover card's and a row's posters are 4:5",
        (tester) async {
      final event = parseEvent(eventCard(1, name: 'Hack Night'))!;
      await tester.pumpWidget(_host(ListView(children: [
        Align(
          alignment: Alignment.topLeft,
          child: DiscoverEventCard(event: event),
        ),
        DiscoverEventTile(event: event),
      ])));

      final posters = find.byType(EventPosterImage);
      expect(posters, findsNWidgets(2));
      for (final size in [tester.getSize(posters.at(0)), tester.getSize(posters.at(1))]) {
        expect(_ratio(size), closeTo(4 / 5, 0.001));
      }
      expect(tester.getSize(posters.at(0)).width, DiscoverEventCard.defaultWidth);
    });

    testWidgets("a related event's poster is 4:5, and its card fits the rail",
        (tester) async {
      final event = EventSummary.fromJson(eventCard(1, name: 'Hack Night'))!;
      await tester.pumpWidget(_host(SingleChildScrollView(
        child: EventRail(title: 'More', events: [event], onOpen: (_) {}),
      )));

      final poster = tester.getSize(find.byType(EventPosterImage));
      expect(_ratio(poster), closeTo(4 / 5, 0.001));
      expect(poster.width, EventSummaryCard.width);
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });
  });

  group('a logo', () {
    test('fills its square only when it is square, within 3%', () {
      expect(ClubLogo.isSquare(const Size(1080, 1080)), isTrue);
      expect(ClubLogo.isSquare(const Size(1080, 1060)), isTrue);
      expect(ClubLogo.isSquare(const Size(1200, 300)), isFalse);
      expect(ClubLogo.isSquare(const Size(500, 800)), isFalse);
      expect(ClubLogo.isSquare(Size.zero), isFalse);
    });

    test('has more room around it in a circle than in a rounded square', () {
      expect(ClubLogo.paddingFor(100, circle: false), 10);
      expect(ClubLogo.paddingFor(100, circle: true), 16);
    });

    Future<void> pumpLogo(WidgetTester tester, int w, int h) async {
      final bytes = (await tester.runAsync(() => _png(w, h)))!;
      await tester.pumpWidget(_host(Center(
        child: SizedBox.square(
          dimension: 48,
          child: LogoPicture(image: MemoryImage(bytes), padding: 7.68),
        ),
      )));
      await _decode(tester);
    }

    testWidgets('a wordmark is whole, padded, on a white tile', (tester) async {
      await pumpLogo(tester, 120, 30);

      final picture = tester.widget<Image>(find.byKey(ClubLogo.pictureKey));
      expect(picture.fit, BoxFit.contain);
      expect(
        tester.widget<Padding>(find.ancestor(
            of: find.byKey(ClubLogo.pictureKey),
            matching: find.byType(Padding))).padding,
        const EdgeInsets.all(7.68),
      );
      expect(
          tester
              .widget<ColoredBox>(find
                  .ancestor(
                      of: find.byKey(ClubLogo.pictureKey),
                      matching: find.byType(ColoredBox))
                  .first)
              .color,
          ClubLogo.tile);
    });

    testWidgets('a square logo fills its tile', (tester) async {
      await pumpLogo(tester, 64, 64);

      final picture = tester.widget<Image>(find.byKey(ClubLogo.pictureKey));
      expect(picture.fit, BoxFit.cover);
      expect(
          find.ancestor(
              of: find.byKey(ClubLogo.pictureKey),
              matching: find.byType(Padding)),
          findsNothing);
    });

    testWidgets('without a logo, the fallback it was given', (tester) async {
      await tester.pumpWidget(_host(const Center(
        child: ClubLogo(url: null, size: 40, fallback: Text('RC')),
      )));
      expect(find.text('RC'), findsOneWidget);
      expect(tester.getSize(find.byType(ClubLogo)), const Size(40, 40));
    });
  });
}
