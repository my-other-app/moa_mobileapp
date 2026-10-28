import 'package:flutter/material.dart';

/// The club's "High demand" label on an event (`high_demand`): a small
/// orange chip with a bolt, and no number behind it.
///
/// Its colours are its own, picked for the surface it sits on: dark orange
/// on pale orange in a light theme, pale orange on deep brown in a dark one
/// (both about 7:1), so it reads either way. [compact] is the cards' size.
class HighDemandChip extends StatelessWidget {
  const HighDemandChip({super.key, this.compact = false});

  /// Smaller, for a card's bottom row.
  final bool compact;

  static const chipKey = ValueKey('high-demand-chip');
  static const label = 'High demand';

  /// Background, edge, words, bolt -- in a light theme, then a dark one.
  static const _light = (
    Color(0xFFFFF7ED),
    Color(0xFFFDBA74),
    Color(0xFF9A3412),
    Color(0xFFEA580C),
  );
  static const _dark = (
    Color(0xFF431407),
    Color(0xFF9A3412),
    Color(0xFFFED7AA),
    Color(0xFFFB923C),
  );

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (background, edge, ink, bolt) = dark ? _dark : _light;
    final size = compact ? 11.0 : 13.0;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        key: chipKey,
        padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: edge, width: compact ? 0.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, size: size + 2, color: bolt),
            const SizedBox(width: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
