import 'package:flutter/material.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';

/// How full the event is: a bar of the places taken, and "82 going · 38
/// seats left". Nothing for an event with no limit and nobody going.
///
/// With nobody going yet, an event whose club reviews every registration
/// ([confirmsEach]) says "{club} reviews every registration" instead. When
/// the server says how many applied to it ([applied]), it says "108
/// applied", with no bar and no seats left: the club decides who gets in.
class SeatsMeter extends StatelessWidget {
  final int going;
  final int? capacity;
  final int? seatsLeft;

  /// The club reviews every registration; [clubName] names it.
  final bool confirmsEach;
  final String? clubName;

  /// How many applied, on an event whose club reviews every registration
  /// (`applied_count`); null on any other, and from an older server.
  final int? applied;

  const SeatsMeter({
    super.key,
    required this.going,
    this.capacity,
    this.seatsLeft,
    this.confirmsEach = false,
    this.clubName,
    this.applied,
  });

  static const meterKey = ValueKey('event-seats-meter');
  static const lineKey = ValueKey('event-seats-line');

  @override
  Widget build(BuildContext context) {
    final line = seatsLine(
      going: going,
      seatsLeft: seatsLeft,
      confirmsEach: confirmsEach,
      clubName: clubName,
      applied: applied,
    );
    final taken = applied != null
        ? null
        : seatsTaken(capacity: capacity, seatsLeft: seatsLeft);
    if (line == null && taken == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        // As wide as the bar even without it ("108 applied"): the line
        // stays at the start, never centred.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (taken != null)
            Semantics(
              label: '${capacity! - seatsLeft!} of $capacity seats taken',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  key: meterKey,
                  value: taken,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE5E7EB),
                  color: taken >= 0.9
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF2C333D),
                ),
              ),
            ),
          if (line != null) ...[
            const SizedBox(height: 6),
            Text(line,
                key: lineKey,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF4B5563))),
          ],
        ],
      ),
    );
  }
}

/// In place of the price button, on an iPhone, for a paid online event: it
/// is not sold in the iOS app, and nothing here says where it is.
class IosSaleBlockedNotice extends StatelessWidget {
  const IosSaleBlockedNotice({super.key});

  static const noticeKey = ValueKey('ios-online-sale-blocked');

  @override
  Widget build(BuildContext context) {
    return Container(
      key: noticeKey,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 20, color: Color(0xFF4B5563)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              iosOnlineSaleBlockedMessage,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
