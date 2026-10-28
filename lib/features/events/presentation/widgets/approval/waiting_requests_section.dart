import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart'
    show claimRoute, formatRupees;

/// My events' "Under review": the person's registrations at events whose
/// club reviews every registration, still under review or waiting for the
/// payment. Each opens its registration's screen.
class WaitingRequestsSection extends StatelessWidget {
  const WaitingRequestsSection({super.key, required this.requests});

  final List<RegistrationRequest> requests;

  static const sectionKey = ValueKey('waiting-for-confirmation');
  static const title = 'UNDER REVIEW';

  @override
  Widget build(BuildContext context) {
    return Column(
      key: sectionKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          title,
          style: TextStyle(fontSize: 20, fontFamily: 'BebasNeue'),
        ),
        const SizedBox(height: 8),
        for (final request in requests) ...[
          RequestTile(request: request),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// One registration: its event, when, where it stands, and what tapping
/// it does.
class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.request});

  final RegistrationRequest request;

  /// Where tapping it goes: the registration's screen; without its token,
  /// the claim screen for a ticket to pay for, else the event.
  String? get location {
    final route = request.route;
    if (route != null) return route;
    final pay = request.pay;
    if (request.awaitingPayment && pay != null) {
      return claimRoute(pay.claimToken);
    }
    return request.event?.route;
  }

  /// "Under review", or, confirmed for a paid ticket, "Confirmed · pay by
  /// Sat 1 Nov, 6:00 PM to get your ticket". No price: an iPhone doesn't
  /// show one for a paid online event.
  String get statusLine => request.statusWord ?? 'Under review';

  /// What tapping it does, in words: "See your registration", or "Pay
  /// ₹199" for a confirmed paid ticket. An iPhone names no price (it
  /// doesn't sell a paid online event): the registration's screen says
  /// whether it can be paid here.
  String get actionLine {
    final pay = request.pay;
    if (request.awaitingPayment &&
        pay != null &&
        pay.amount > 0 &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return 'Pay ${formatRupees(pay.amount)}';
    }
    return 'See your registration';
  }

  @override
  Widget build(BuildContext context) {
    final when = request.event?.eventDateTime;
    final to = location;
    final confirmed = request.awaitingPayment;
    final accent =
        confirmed ? const Color(0xFF047857) : const Color(0xFF1D4ED8);
    return Material(
      color: confirmed ? const Color(0xFFECFDF5) : const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('request-tile-${request.id}'),
        borderRadius: BorderRadius.circular(12),
        onTap: to == null
            ? null
            : () => context.push(to, extra: {'request': request}),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Icon(
                confirmed ? Icons.celebration_outlined : Icons.hourglass_top,
                size: 22,
                color: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.event?.name.isNotEmpty == true
                          ? request.event!.name
                          : 'Your registration',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    if (when != null)
                      Text(
                        DateFormat('EEE d MMM, h:mm a').format(when.toLocal()),
                        style: const TextStyle(
                            fontSize: 12.5, color: Color(0xFF4B5563)),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      statusLine,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151)),
                    ),
                    if (to != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        actionLine,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent),
                      ),
                    ],
                  ],
                ),
              ),
              if (to != null)
                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }
}
