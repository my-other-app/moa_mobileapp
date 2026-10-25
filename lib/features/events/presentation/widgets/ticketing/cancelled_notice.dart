import 'package:flutter/material.dart';

import 'package:finnet/features/events/domain/ticketing.dart';

/// "Cancelled", with the club's reason and, for someone who paid, that the
/// payment is being refunded: on the event page, the ticket and My events.
class CancelledNotice extends StatelessWidget {
  const CancelledNotice({
    super.key,
    required this.cancellation,
    this.registered = false,
    this.paid = false,
    this.dark = false,
    this.compact = false,
  });

  final EventCancellation cancellation;

  /// The person holds a ticket: it is no longer valid.
  final bool registered;

  /// They paid for it online: the refund is under way.
  final bool paid;

  /// On the ticket's dark screen.
  final bool dark;

  /// A card's short form: the title, the reason on one or two lines, and the
  /// refund in four words.
  final bool compact;

  static const noticeKey = ValueKey('event-cancelled-notice');
  static const title = 'This event was cancelled';

  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : const Color(0xFF7F1D1D);
    final soft = dark ? Colors.white.withAlpha(190) : const Color(0xFF991B1B);
    final reason = cancellation.reason;
    final lines = <Widget>[
      if (reason != null)
        Text(
          compact ? reason : 'The organisers said: $reason',
          maxLines: compact ? 2 : null,
          overflow: compact ? TextOverflow.ellipsis : null,
          style: TextStyle(fontSize: 13.5, color: soft, height: 1.35),
        ),
      if (registered)
        Text(
          'Your ticket is no longer valid.',
          style: TextStyle(fontSize: 13.5, color: soft, height: 1.35),
        ),
      if (paid)
        Text(
          compact
              ? EventCancellation.refundNote
              : EventCancellation.refundDetail,
          key: const ValueKey('event-cancelled-refund'),
          style: TextStyle(
            fontSize: 13.5,
            color: ink,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
    ];
    return Container(
      key: noticeKey,
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: dark ? Colors.white.withAlpha(14) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.red.shade300.withAlpha(140) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.event_busy, size: 22, color: dark ? Colors.red.shade300 : const Color(0xFFDC2626)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
                ),
                for (final line in lines) ...[
                  const SizedBox(height: 4),
                  line,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
