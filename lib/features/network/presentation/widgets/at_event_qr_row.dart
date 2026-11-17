import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/events/domain/networking.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/network/domain/network_links.dart';

/// How early before the start someone counts as at the event.
const _early = Duration(hours: 2);

/// Whether a person with a ticket of [status] is at the event at [now]:
/// registered or checked in, from a little before it starts until People
/// Like You closes (an hour after it ends).
bool atTheEvent({
  required RegistrationStatus status,
  required DateTime? startsAt,
  required double? durationHours,
  required DateTime now,
  bool revoked = false,
}) {
  if (revoked) return false;
  if (status != RegistrationStatus.attended &&
      status != RegistrationStatus.registered) {
    return false;
  }
  final closes = networkingClosesAt(startsAt, durationHours);
  if (startsAt == null || closes == null) return false;
  return !now.isBefore(startsAt.subtract(_early)) && now.isBefore(closes);
}

/// On the event's page, while the person is there: My QR, and the
/// scanner to save someone else -- with this event filled in.
class AtEventQrRow extends StatelessWidget {
  const AtEventQrRow({
    super.key,
    required this.eventId,
    required this.status,
    required this.startsAt,
    required this.durationHours,
    this.revoked = false,
    this.now,
  });

  final int? eventId;
  final RegistrationStatus status;
  final DateTime? startsAt;
  final double? durationHours;
  final bool revoked;

  /// The clock, for tests.
  final DateTime Function()? now;

  static const myQrKey = ValueKey('event-my-qr');
  static const scanKey = ValueKey('event-scan-person');

  @override
  Widget build(BuildContext context) {
    final id = eventId;
    if (id == null ||
        id <= 0 ||
        !atTheEvent(
          status: status,
          startsAt: startsAt,
          durationHours: durationHours,
          now: (now ?? DateTime.now)(),
          revoked: revoked,
        )) {
      return const SizedBox.shrink();
    }
    final style = OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      side: const BorderSide(color: AppColors.ink),
      minimumSize: const Size.fromHeight(44),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              key: myQrKey,
              onPressed: () => context.push(myQrLocation),
              style: style,
              icon: const Icon(Icons.qr_code_2),
              label: const Text('My QR'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              key: scanKey,
              onPressed: () => context.push(savePersonScanAt(id)),
              style: style,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Save a person'),
            ),
          ),
        ],
      ),
    );
  }
}
