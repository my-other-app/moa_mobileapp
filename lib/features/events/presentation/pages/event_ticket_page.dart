import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/presentation/pages/individual_event_page.dart';
import 'package:finnet/features/events/presentation/pages/saved_ticket_page.dart';
import 'package:finnet/features/events/presentation/providers/saved_tickets_provider.dart';

/// The person's saved ticket to event [eventId] on this phone, if any: a
/// usable one first (not revoked).
SavedTicket? savedTicketForEvent(List<SavedTicket> tickets, int? eventId) {
  if (eventId == null || eventId <= 0) return null;
  SavedTicket? revoked;
  for (final ticket in tickets) {
    if (ticket.eventId != eventId) continue;
    if (!ticket.revoked) return ticket;
    revoked ??= ticket;
  }
  return revoked;
}

/// `/events/{id}/ticket`: the ticket to an event, by the event.
///
/// What the "Next up" home-screen widget opens (docs/HOME_WIDGETS.md). The
/// widget knows the event, never the ticket's code -- the code is what the
/// QR encodes, and is kept out of the widget's storage -- so the code is
/// found here, among the tickets saved on the phone. If the phone has none
/// for the event yet, the list is read again once (signed in); without a
/// ticket after that, the event's page opens instead, which says where the
/// registration stands.
class EventTicketPage extends ConsumerStatefulWidget {
  const EventTicketPage({super.key, required this.eventRef});

  /// The event's id (or slug, which finds no ticket: the event page opens).
  final String eventRef;

  @override
  ConsumerState<EventTicketPage> createState() => _EventTicketPageState();
}

class _EventTicketPageState extends ConsumerState<EventTicketPage> {
  /// Done looking: the ticket, or the event page.
  bool _settled = false;

  int? get _eventId => eventIdOf(widget.eventRef);

  @override
  void initState() {
    super.initState();
    _find();
  }

  Future<void> _find() async {
    final tickets = ref.read(savedTicketsProvider.notifier);
    try {
      await tickets.loaded;
      if (!mounted) return;
      if (savedTicketForEvent(ref.read(savedTicketsProvider), _eventId) ==
              null &&
          _eventId != null &&
          ref.read(isAuthenticatedProvider)) {
        // A registration made on another device, or since the list was
        // last read.
        await tickets.refreshIfOlderThan(const Duration(seconds: 30));
      }
    } catch (e) {
      debugPrint('EventTicketPage: $e');
    }
    if (mounted) setState(() => _settled = true);
  }

  @override
  Widget build(BuildContext context) {
    final ticket =
        savedTicketForEvent(ref.watch(savedTicketsProvider), _eventId);
    if (ticket != null) return SavedTicketPage(code: ticket.code);
    if (!_settled) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final eventRef = widget.eventRef;
    return IndividualEventPage(
      key: ValueKey('event-$eventRef'),
      eventId: _eventId,
      eventRef: eventRef,
    );
  }
}
