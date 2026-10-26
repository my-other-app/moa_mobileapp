import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart' show claimRoute;

/// My events' "Waiting for confirmation": the person's requests at events
/// whose club confirms each place, still waiting for the club or for the
/// payment. Each opens its request's screen.
class WaitingRequestsSection extends StatelessWidget {
  const WaitingRequestsSection({super.key, required this.requests});

  final List<RegistrationRequest> requests;

  static const sectionKey = ValueKey('waiting-for-confirmation');
  static const title = 'WAITING FOR CONFIRMATION';

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

/// One request: its event, when, and where it stands.
class RequestTile extends StatelessWidget {
  const RequestTile({super.key, required this.request});

  final RegistrationRequest request;

  /// Where tapping it goes: the request's screen; without its token, the
  /// claim screen for a place to pay for, else the event.
  String? get location {
    final route = request.route;
    if (route != null) return route;
    final pay = request.pay;
    if (request.awaitingPayment && pay != null) {
      return claimRoute(pay.claimToken);
    }
    return request.event?.route;
  }

  /// "Waiting for Tinkerhub to confirm", or, confirmed for a paid ticket,
  /// "Tinkerhub confirmed your place · finish by Sat 1 Nov, 6:00 PM". No
  /// price: an iPhone doesn't show one for a paid online event.
  String get statusLine {
    if (request.awaitingPayment) {
      final by = request.pay?.payBy;
      return by == null
          ? '${request.clubName} confirmed your place · finish it to get your ticket'
          : '${request.clubName} confirmed your place · finish by ${requestMoment(by)}';
    }
    final club = request.event?.clubName;
    return club == null
        ? 'Waiting for the club to confirm'
        : 'Waiting for $club to confirm';
  }

  @override
  Widget build(BuildContext context) {
    final when = request.event?.eventDateTime;
    final to = location;
    final confirmed = request.awaitingPayment;
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
                color: confirmed
                    ? const Color(0xFF047857)
                    : const Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.event?.name.isNotEmpty == true
                          ? request.event!.name
                          : 'Your request',
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
