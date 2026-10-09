import 'package:finnet/shared/widgets/rating_stars.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Counts of each star kind, so a rating's rendering is checked rather than
/// its arithmetic.
({int full, int half, int empty}) starCounts(WidgetTester tester) => (
      full: find.byIcon(Icons.star).evaluate().length,
      half: find.byIcon(Icons.star_half).evaluate().length,
      empty: find.byIcon(Icons.star_border).evaluate().length,
    );

void main() {
  Future<({int full, int half, int empty})> render(
    WidgetTester tester,
    double rating,
  ) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: RatingStars(rating: rating)),
    ));
    return starCounts(tester);
  }

  group('RatingStars', () {
    testWidgets('4.5 is four full and a half, not five full', (tester) async {
      // The reported bug: `index < rating.round()` filled all five, so a
      // club rated 4.5 looked perfect.
      final counts = await render(tester, 4.5);

      expect(counts.full, 4);
      expect(counts.half, 1);
      expect(counts.empty, 0);
    });

    testWidgets('4.4 keeps four full and stays short of a half',
        (tester) async {
      // Rounding sent this to four full with the fraction gone; it should
      // read as "four and a bit" by leaving the fifth empty.
      final counts = await render(tester, 4.4);

      expect(counts.full, 4);
      expect(counts.half, 0);
      expect(counts.empty, 1);
    });

    testWidgets('a whole rating has no half', (tester) async {
      final counts = await render(tester, 4.0);

      expect(counts.full, 4);
      expect(counts.half, 0);
      expect(counts.empty, 1);
    });

    testWidgets('5 is five full stars', (tester) async {
      final counts = await render(tester, 5.0);

      expect(counts.full, 5);
      expect(counts.half, 0);
      expect(counts.empty, 0);
    });

    testWidgets('0 is five empty stars', (tester) async {
      final counts = await render(tester, 0);

      expect(counts.full, 0);
      expect(counts.empty, 5);
    });

    testWidgets('always exactly five stars, whatever the input',
        (tester) async {
      for (final rating in [0.0, 0.5, 2.7, 4.9, 5.0, -1.0, 7.5]) {
        final counts = await render(tester, rating);

        expect(counts.full + counts.half + counts.empty, 5,
            reason: 'rating $rating drew the wrong number of stars');
      }
    });

    testWidgets('out of range is clamped rather than drawing extra stars',
        (tester) async {
      // Bad data should not produce seven stars.
      final high = await render(tester, 7.5);
      expect(high.full, 5);

      final low = await render(tester, -2.0);
      expect(low.empty, 5);
    });
  });
}
