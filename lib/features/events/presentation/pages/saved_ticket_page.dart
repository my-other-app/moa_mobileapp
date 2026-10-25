import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/presentation/pages/ticket_view_page.dart';
import 'package:finnet/features/events/presentation/providers/event_cancellation_provider.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';

/// The address of a ticket inside the app: `/tickets/{code}`.
String ticketRoute(String code) => '/tickets/${Uri.encodeComponent(code)}';

/// `/tickets/{code}`: a ticket, from what the phone has saved about it.
///
/// Opens with no network: the event's name, date and place come from the
/// saved ticket, and the QR is drawn from the code. A code the phone knows
/// nothing more about still shows its QR.
class SavedTicketPage extends ConsumerWidget {
  const SavedTicketPage({super.key, required this.code, this.revoked = false});

  final String code;

  /// The screen that opened this already knows the ticket is revoked (a
  /// list fresher than the saved tickets).
  final bool revoked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(savedTicketsProvider);
    SavedTicket? ticket;
    for (final saved in tickets) {
      if (saved.code == code) ticket = saved;
    }
    // Called off: by the saved ticket's word, else the event's page's (the
    // list of registrations doesn't say it today).
    final cancellation = ticket?.cancellation ??
        (ticket == null
            ? null
            : ref
                .watch(eventCancellationProvider('${ticket.eventId}'))
                .valueOrNull);
    return TicketViewPage(
      ticketId: code,
      eventName: ticket?.eventName ?? 'Your ticket',
      eventDateTime: ticket?.startsAt,
      locationName: ticket?.isOnline ?? false ? 'Online' : ticket?.venue,
      durationHours: ticket?.durationHours,
      ticketUrl: ticket?.ticketUrl,
      posterUrl: ticket?.posterUrl,
      revoked: revoked || (ticket?.revoked ?? false),
      eventId: ticket?.eventId,
      ticketType: ticket?.ticketType,
      cancellation: cancellation,
      paid: ticket?.paid ?? false,
    );
  }
}

/// The tickets saved on the phone, for when the list of registrations
/// cannot be loaded and there is no saved copy of it: with no signal at the
/// door, the tickets are still one tap away.
///
/// Shows [fallback] when there are no saved tickets either.
class SavedTicketsFallback extends ConsumerWidget {
  const SavedTicketsFallback({super.key, required this.fallback});

  final Widget fallback;

  static const notice = 'Offline — showing your saved tickets';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(savedTicketsProvider);
    if (tickets.isEmpty) return fallback;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.cloud_off, size: 16, color: Colors.black54),
            const SizedBox(width: 8),
            Text(notice,
                style: TextStyle(fontSize: 13, color: Colors.grey[700])),
          ],
        ),
        const SizedBox(height: 12),
        for (final ticket in tickets) _SavedTicketTile(ticket: ticket),
      ],
    );
  }
}

class _SavedTicketTile extends StatelessWidget {
  const _SavedTicketTile({required this.ticket});

  final SavedTicket ticket;

  @override
  Widget build(BuildContext context) {
    final start = ticket.startsAt;
    final when =
        start == null ? 'Date to be announced' : DateFormat('EEE, d MMM · h:mm a').format(start);
    final where = ticket.isOnline ? 'Online' : (ticket.venue ?? '');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        title: Text(ticket.eventName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          when,
          if (where.isNotEmpty) where,
          if (ticket.revoked) 'Revoked by the organiser',
          if (ticket.cancellation != null) 'Cancelled by the organiser',
        ].join('\n')),
        isThreeLine:
            where.isNotEmpty || ticket.revoked || ticket.cancellation != null,
        trailing: FilledButton(
          onPressed: () => context.push(ticketRoute(ticket.code)),
          style: FilledButton.styleFrom(
            backgroundColor: ticket.revoked
                ? Colors.grey.shade600
                : const Color(0xFF2C333D),
          ),
          child: Text(ticket.revoked ? 'REVOKED' : 'VIEW TICKET'),
        ),
      ),
    );
  }
}
