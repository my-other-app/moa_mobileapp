import 'package:flutter/material.dart';

/// Five stars for a 0–5 rating, with a half star where the data has one.
///
/// One widget because there were three implementations and they disagreed.
/// Two of them rendered `index < rating.round()`, so a 4.5 filled all five
/// stars -- a club or event looked perfect when it was not -- while 4.4
/// showed four and dropped the fraction entirely. The third handled halves
/// correctly and nothing called it.
class RatingStars extends StatelessWidget {
  /// The rating, 0–5. Values outside that range are clamped rather than
  /// drawing more than five stars or none at all.
  final double rating;

  final double size;
  final Color color;
  final MainAxisAlignment alignment;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 28,
    this.color = Colors.amber,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final value = rating.clamp(0.0, 5.0).toDouble();
    final full = value.floor();
    // A half is shown from .5 up; below that the star stays empty, so 4.4
    // reads as "four and a bit" rather than being rounded up to five.
    final hasHalf = (value - full) >= 0.5;

    final stars = <Widget>[
      for (int i = 0; i < full; i++)
        Icon(Icons.star, color: color, size: size),
      if (hasHalf) Icon(Icons.star_half, color: color, size: size),
    ];
    while (stars.length < 5) {
      stars.add(Icon(Icons.star_border, color: color, size: size));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignment,
      children: stars,
    );
  }
}
