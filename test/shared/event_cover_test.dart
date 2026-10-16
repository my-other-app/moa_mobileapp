import 'package:cached_network_image/cached_network_image.dart';
import 'package:finnet/shared/widgets/event_cover.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _box(Widget child, {double width = 320, double height = 400}) =>
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

CoverLook _paintedLook(WidgetTester tester) {
  final paint = tester.widget<CustomPaint>(
    find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CoverArtPainter),
  );
  return (paint.painter! as CoverArtPainter).look;
}

void main() {
  group('the cover look matches the website', () {
    // Expected values come from running the site's own
    // moa_eventwebsite/src/utils/cover.js on the same inputs.
    test('seeds: numbers are themselves, text is FNV-1a hashed', () {
      expect(coverSeedOf(42), 42);
      expect(coverSeedOf('123'), 123);
      expect(coverSeedOf(-3.7), 4);
      expect(coverSeedOf(''), 2166136261);
      expect(coverSeedOf(null), 2166136261);
      expect(coverSeedOf('workshop'), 3580368908);
      // Ten digits is too long to be read as a number; it is hashed.
      expect(coverSeedOf('1234567890'), 1627973700);
    });

    test('palette, shape and placement for the same events', () {
      String look(Object? id, [Object? category]) {
        final l = coverLook(id: id, category: category);
        return '${l.palette.name} ${l.motif.name} ${l.variant}';
      }

      expect(look(42, {'id': 3}), 'night grid 1');
      expect(look(1), 'citron grid 0');
      expect(look(7, 2), 'citron stripes 1');
      expect(look(123, {'id': 5}), 'paper rings 2');
      expect(look('abc'), 'mist arches 2');
      expect(look('hackathon-2026', 'music'), 'paper waves 1');
      expect(look(99999, {'id': 11}), 'paper burst 1');
      expect(look(0), 'night rings 0');
    });

    test('the same id always gets the same look', () {
      expect(coverLook(id: 314, category: 6), coverLook(id: 314, category: 6));
      expect(coverLook(id: 314), isNot(coverLook(id: 315)));
    });
  });

  group('dates are in India time', () {
    test('day, month and weekday, whatever the phone\'s zone', () {
      final evening = coverDateParts(DateTime.utc(2026, 10, 16, 20));
      expect(
          [evening!.day, evening.month, evening.weekday], ['17', 'Oct', 'Sat']);

      // A minute before midnight in India is still the 31st there.
      final late = coverDateParts(DateTime.utc(2026, 10, 31, 18, 29));
      expect([late!.day, late.month, late.weekday], ['31', 'Oct', 'Sat']);

      final early = coverDateParts(DateTime.utc(2026, 10, 31, 18, 30));
      expect([early!.day, early.month], ['1', 'Nov']);

      expect(coverDateParts(null), isNull);
    });

    test('event_datetime with an offset, in UTC, or bare', () {
      for (final raw in [
        '2026-10-17T00:30:00+05:30',
        '2026-10-16T19:00:00Z',
        // No zone means India time on this server, not the phone's.
        '2026-10-17T00:30:00',
        '2026-10-17',
      ]) {
        final parts = coverDateParts(parseEventStart(raw));
        expect([parts!.day, parts.month, parts.weekday], ['17', 'Oct', 'Sat'],
            reason: raw);
      }
      expect(parseEventStart(null), isNull);
      expect(parseEventStart(''), isNull);
      expect(parseEventStart('soon'), isNull);
    });
  });

  group('EventCover', () {
    testWidgets('shows the category and a big date', (tester) async {
      await tester.pumpWidget(_box(EventCover(
        eventId: 42,
        categoryId: 3,
        categoryName: 'Workshop',
        startsAt: DateTime.utc(2026, 10, 16, 20),
      )));

      expect(find.text('WORKSHOP'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('OCT'), findsOneWidget);
      expect(find.text('SAT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says Online when there is no category, nothing otherwise',
        (tester) async {
      await tester.pumpWidget(_box(EventCover(
        eventId: 1,
        isOnline: true,
        startsAt: DateTime.utc(2026, 10, 16, 20),
      )));
      expect(find.text('ONLINE'), findsOneWidget);

      await tester.pumpWidget(_box(EventCover(
        eventId: 1,
        startsAt: DateTime.utc(2026, 10, 16, 20),
      )));
      expect(find.text('ONLINE'), findsNothing);
      expect(find.text('17'), findsOneWidget);
    });

    testWidgets('draws the same look for the same event every time',
        (tester) async {
      await tester
          .pumpWidget(_box(const EventCover(eventId: 123, categoryId: 5)));
      final first = _paintedLook(tester);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
          _box(const EventCover(eventId: 123, categoryId: 5), width: 200));
      expect(_paintedLook(tester), first);
      expect(first, coverLook(id: 123, category: 5));

      await tester
          .pumpWidget(_box(const EventCover(eventId: 124, categoryId: 5)));
      expect(_paintedLook(tester), isNot(first));
    });

    testWidgets('is painted, never fetched', (tester) async {
      await tester.pumpWidget(_box(EventCover(
        eventId: 9,
        categoryName: 'Talk',
        startsAt: DateTime.utc(2026, 10, 20, 6),
      )));

      expect(find.byType(Image), findsNothing);
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is CoverArtPainter),
        findsOneWidget,
      );
    });

    testWidgets('drops the tag when small and is a calendar leaf when tiny',
        (tester) async {
      final cover = EventCover(
        eventId: 5,
        categoryName: 'Workshop',
        startsAt: DateTime.utc(2026, 10, 16, 20),
      );

      await tester.pumpWidget(_box(cover, width: 120, height: 150));
      expect(find.text('WORKSHOP'), findsNothing);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('SAT'), findsOneWidget);

      await tester.pumpWidget(_box(cover, width: 50, height: 50));
      expect(find.text('WORKSHOP'), findsNothing);
      expect(find.text('OCT'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      expect(find.text('SAT'), findsNothing);
      // The shape is left out of a thumbnail, where it only fights the date.
      expect(
        find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is CoverArtPainter),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('every shape and placement paints, at every size',
        (tester) async {
      // Find an id for each motif and variant so all 24 get painted.
      final ids = <String, int>{};
      for (var id = 0; ids.length < 24 && id < 5000; id++) {
        final look = coverLook(id: id);
        ids.putIfAbsent('${look.motif.name}/${look.variant}', () => id);
      }
      expect(ids, hasLength(24));

      for (final id in ids.values) {
        for (final size in const [
          Size(320, 400),
          Size(358, 358),
          Size(358, 201)
        ]) {
          await tester.pumpWidget(_box(
            EventCover(
              eventId: id,
              categoryName: 'Hackathon and a very long category name',
              startsAt: DateTime.utc(2026, 12, 31, 12),
            ),
            width: size.width,
            height: size.height,
          ));
          expect(tester.takeException(), isNull, reason: 'id $id at $size');
        }
      }
    });

    testWidgets('fits a huge reader text size without overflowing',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(3)),
          child: child!,
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 250,
              child: EventCover(
                eventId: 77,
                categoryName: 'Workshop',
                startsAt: DateTime.utc(2026, 10, 16, 20),
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
    });
  });
}
