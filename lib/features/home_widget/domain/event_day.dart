import 'package:intl/intl.dart';

import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/home_widget/domain/next_up.dart'
    show inIndia, indiaTimeOfDay, ticketLinkFor;

// The event-day card (docs/HOME_WIDGETS.md): on the day of an event the
// person holds a ticket for, a card on the lock screen -- a Live Activity
// on the iPhone (lock screen and Dynamic Island), an ongoing notification
// on Android -- with the event's name, a countdown to its start that runs
// by itself, the venue, and "Show ticket". From the start it says it is
// happening now; after the end it goes.
//
// It is drawn on the lock screen, so it carries only what it shows and
// where a tap goes: the event's id, name, venue, start, end and time of day,
// and the ticket's page in the app (`/events/{id}/ticket`, which finds the
// code on the phone). Never the ticket's code, its QR or its link.

/// How long before the start the card may come: Live Activities stay up
/// for at most eight hours (then the system ends them), so a card started
/// earlier would be gone by the start.
const eventDayLead = Duration(hours: 8);

/// How long an event with no length is taken to last, for when its card
/// goes.
const eventDayDefaultLength = Duration(hours: 4);

/// One event's card.
class EventDayCard {
  const EventDayCard({
    required this.eventId,
    required this.name,
    required this.startsAt,
    required this.endsAt,
    this.place,
  });

  final int eventId;
  final String name;

  /// UTC.
  final DateTime startsAt;
  final DateTime endsAt;

  /// The venue, "Online", or null when not said.
  final String? place;

  /// "Show ticket": the ticket's page, which finds the code on the phone.
  String get link => ticketLinkFor(eventId);

  /// The card for [ticket], or null when it has none: no date, revoked,
  /// or the event called off.
  static EventDayCard? of(SavedTicket ticket) {
    final start = ticket.startsAt?.toUtc();
    if (start == null || ticket.revoked || ticket.cancellation != null) {
      return null;
    }
    if (ticket.eventId <= 0) return null;
    final hours = ticket.durationHours;
    final length = hours == null || hours <= 0
        ? eventDayDefaultLength
        : Duration(minutes: (hours * 60).round());
    final name = ticket.eventName.trim().replaceAll(RegExp(r'\s+'), ' ');
    final venue = ticket.venue?.trim();
    return EventDayCard(
      eventId: ticket.eventId,
      name: name.isEmpty ? 'Your event' : name,
      startsAt: start,
      endsAt: start.add(length),
      place: ticket.isOnline
          ? 'Online'
          : (venue == null || venue.isEmpty ? null : venue),
    );
  }

  /// Its day has come at [now]: it starts within [eventDayLead], or is on.
  bool isDueAt(DateTime now) =>
      now.isBefore(endsAt) && !startsAt.subtract(eventDayLead).isAfter(now);

  /// It has started at [now].
  bool hasStartedAt(DateTime now) => !now.isBefore(startsAt);

  /// What the phone's card is given (the platform channel's map).
  Map<String, Object?> toChannel() {
    final india = inIndia(startsAt);
    return {
      'event_id': eventId,
      'name': name,
      if (place != null) 'place': place,
      'starts_at': startsAt.millisecondsSinceEpoch,
      'ends_at': endsAt.millisecondsSinceEpoch,
      'time': indiaTimeOfDay(startsAt),
      'date': DateFormat('EEE, d MMM', 'en_US').format(india),
      'link': link,
    };
  }
}

/// The cards due at [now], soonest first, one per event: the person's
/// usable tickets whose event starts within [eventDayLead] or is on.
List<EventDayCard> eventDayCardsDue(List<SavedTicket> tickets, DateTime now) {
  final seen = <int>{};
  final due = [
    for (final ticket in tickets)
      if (EventDayCard.of(ticket) case final card?)
        if (card.isDueAt(now) && seen.add(card.eventId)) card,
  ]..sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return due;
}

/// Which card the phone shows at [now], one at a time, given the cards
/// [due], the event whose card is up ([showing]), the events whose card
/// was put up before ([shownBefore] -- the person may have put it away),
/// and the ticket just opened ([opened]):
///
/// - the ticket opened, when its card is due: the person asked for it;
/// - else the card up, while it is still due (so it doesn't jump);
/// - else the soonest due one not put up before (once per event: a card
///   the person put away is not put back by opening the app).
///
/// Null: nothing to show (any card up goes).
EventDayCard? eventDayCardToShow({
  required List<EventDayCard> due,
  int? showing,
  Set<int> shownBefore = const {},
  int? opened,
}) {
  EventDayCard? find(int? id) {
    if (id == null) return null;
    for (final card in due) {
      if (card.eventId == id) return card;
    }
    return null;
  }

  final asked = find(opened);
  if (asked != null) return asked;
  final up = find(showing);
  if (up != null) return up;
  for (final card in due) {
    if (!shownBefore.contains(card.eventId)) return card;
  }
  return null;
}
