import 'package:flutter/material.dart';
import 'package:finnet/features/volunteer/domain/gate_copy.dart';

/// The colours of an answer at the door.
({Color background, Color border, Color ink, IconData icon}) gateToneStyle(
    GateTone tone) {
  switch (tone) {
    case GateTone.admit:
      return (
        background: const Color(0xFFE8F7EE),
        border: const Color(0xFF34A853),
        ink: const Color(0xFF14532D),
        icon: Icons.check_circle,
      );
    case GateTone.caution:
      return (
        background: const Color(0xFFFFF7E0),
        border: const Color(0xFFE0A800),
        ink: const Color(0xFF6B4E00),
        icon: Icons.info,
      );
    case GateTone.refuse:
      return (
        background: const Color(0xFFFDECEC),
        border: const Color(0xFFD93025),
        ink: const Color(0xFF7F1D1D),
        icon: Icons.block,
      );
    case GateTone.queued:
      return (
        background: const Color(0xFFE8F0FE),
        border: const Color(0xFF1A73E8),
        ink: const Color(0xFF1E3A8A),
        icon: Icons.cloud_off,
      );
  }
}

/// A scan's answer: what happened, and what to do next. It never blocks
/// the next scan; [onClose] puts it away, [onCheckInByHand] (an admission
/// number) checks its holder in.
class GateOutcomeCard extends StatelessWidget {
  const GateOutcomeCard({
    super.key,
    required this.card,
    this.onClose,
    this.onCheckInByHand,
  });

  static const closeKey = ValueKey('gate-card-close');
  static const byHandKey = ValueKey('gate-card-by-hand');

  final OutcomeCard card;
  final VoidCallback? onClose;
  final VoidCallback? onCheckInByHand;

  @override
  Widget build(BuildContext context) {
    final style = gateToneStyle(card.tone);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: style.border, width: 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(style.icon, color: style.border, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    card.tag.toUpperCase(),
                    style: TextStyle(
                      color: style.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    key: closeKey,
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.close, color: style.ink),
                    onPressed: onClose,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                card.title,
                style: TextStyle(
                  color: style.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (card.sub != null) ...[
              const SizedBox(height: 4),
              Text(
                card.sub!,
                style: TextStyle(
                  color: style.ink.withValues(alpha: 0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (card.attribution != null) ...[
              const SizedBox(height: 4),
              Text(card.attribution!,
                  style: TextStyle(color: style.ink, fontSize: 13)),
            ],
            if (card.note != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(card.note!,
                    style: TextStyle(color: style.ink, fontSize: 13)),
              ),
            ],
            if (onCheckInByHand != null) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                key: byHandKey,
                onPressed: onCheckInByHand,
                icon: const Icon(Icons.how_to_reg),
                label: const Text('Check in by hand'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C333D),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
