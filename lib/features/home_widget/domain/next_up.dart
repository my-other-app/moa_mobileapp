import 'package:intl/intl.dart';

import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/registration_request.dart';

// "Next up", the home-screen widget (docs/HOME_WIDGETS.md): what it shows,
// chosen here from what the app already knows -- the tickets saved on the
// phone and the registrations under review -- and written as JSON into the
// storage the widgets read (an App Group on iOS, SharedPreferences on
// Android). The widgets only lay it out; the one thing they work out for
// themselves is the line that depends on the clock ("Today · 9:30 am",
// "Tomorrow", "In 3 days"), by the rules of [nextUpWhen].
//
// What goes in is what the widget shows -- the event's name, date, time and
// place -- plus its id and the link a tap opens. Never the ticket code: it
// is what the QR encodes, and the door lets in whoever shows it. The tap
// opens `/events/{id}/ticket`, which finds the code on the phone.

/// India's offset from UTC. Asia/Kolkata has kept it since 1945, with no
/// summer time, so a fixed offset is the zone.
const indiaOffset = Duration(hours: 5, minutes: 30);

/// [time] on India's clock: a UTC [DateTime] whose fields read as the time
/// in Asia/Kolkata (its hour is India's hour), for formatting and for
/// comparing calendar days.
DateTime inIndia(DateTime time) {
  final shifted = time.toUtc().add(indiaOffset);
  return DateTime.utc(shifted.year, shifted.month, shifted.day, shifted.hour,
      shifted.minute, shifted.second);
}

/// "9:30 am": the time of day of [time] in India.
String indiaTimeOfDay(DateTime time) =>
    DateFormat('h:mm a', 'en_US').format(inIndia(time)).toLowerCase();

/// Whole calendar days in India from [now] to [time]: 0 the same day, 1 the
/// next, -1 the day before.
int indiaDaysBetween(DateTime now, DateTime time) {
  DateTime day(DateTime t) {
    final india = inIndia(t);
    return DateTime.utc(india.year, india.month, india.day);
  }

  return day(time).difference(day(now)).inHours ~/ 24;
}

/// The line under the event's name, as the widget works it out at [now]:
///
/// - no date yet: "Date to be announced";
/// - started and not over ([end]): "Happening now";
/// - later today, in India: "Today · 9:30 am";
/// - tomorrow: "Tomorrow · 9:30 am";
/// - further off: "In 3 days".
///
/// The Android (NextUpWidgetProvider.kt) and iOS (NextUpWidget.swift)
/// widgets follow these same rules on their own clock, so the line stays
/// right while the app is closed.
String nextUpWhen(DateTime? start, DateTime? end, DateTime now) {
  if (start == null) return 'Date to be announced';
  if (!now.isBefore(start)) {
    return end == null || now.isBefore(end) ? 'Happening now' : 'Ended';
  }
  final days = indiaDaysBetween(now, start);
  if (days <= 0) return 'Today · ${indiaTimeOfDay(start)}';
  if (days == 1) return 'Tomorrow · ${indiaTimeOfDay(start)}';
  return 'In $days days';
}

/// What the widget is showing.
enum NextUpState {
  /// Nobody is signed in: "Sign in to see your next event".
  signedOut('signed_out'),

  /// Signed in, with nothing coming up: "Find events".
  nothing('nothing'),

  /// The next event, and a few after it.
  upcoming('upcoming');

  const NextUpState(this.wire);

  /// Its name in the JSON.
  final String wire;
}

/// One event on the widget: a ticket, or a registration under review.
class NextUpItem {
  const NextUpItem({
    required this.eventId,
    required this.name,
    required this.link,
    this.startsAt,
    this.endsAt,
    this.place,
    this.club,
    this.underReview = false,
    this.badge,
  });

  final int eventId;
  final String name;

  /// When it starts and ends (UTC); null when the club hasn't said.
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// The venue, "Online", or null when unknown (a registration under
  /// review carries no venue).
  final String? place;

  /// The club hosting it, shown where there is no [place].
  final String? club;

  /// A registration the club hasn't confirmed: no ticket to show yet.
  final bool underReview;

  /// The words in its pill ("Under review"), when it is not a ticket.
  final String? badge;

  /// What a tap opens: the website's address, which the app's router reads
  /// as its own (web_links.dart).
  final String link;

  /// Over at [now]: the widget moves on to the next one.
  bool isOverAt(DateTime now) {
    final end = endsAt;
    return end != null && !now.isBefore(end);
  }

  Map<String, Object?> toJson(DateTime now) {
    final start = startsAt;
    final india = start == null ? null : inIndia(start);
    return {
      'event_id': eventId,
      'name': name,
      if (start != null) 'starts_at': start.millisecondsSinceEpoch,
      if (endsAt != null) 'ends_at': endsAt!.millisecondsSinceEpoch,
      if (india != null) ...{
        'weekday': DateFormat('EEE', 'en_US').format(india).toUpperCase(),
        'day': '${india.day}',
        'month': DateFormat('MMM', 'en_US').format(india).toUpperCase(),
        'time': indiaTimeOfDay(start!),
        'date': DateFormat('EEE, d MMM', 'en_US').format(india),
      },
      if (place != null) 'place': place,
      if (club != null) 'club': club,
      'review': underReview,
      if (badge != null) 'badge': badge,
      'when': nextUpWhen(start, endsAt, now),
      'link': link,
    };
  }
}

/// Everything the widget is given.
class NextUpSnapshot {
  const NextUpSnapshot._(this.state, this.items, this.link);

  /// Signed out: a tap asks them to sign in, then opens My events.
  static final NextUpSnapshot signedOut =
      NextUpSnapshot._(NextUpState.signedOut, const [], siteLink('/me/tickets'));

  /// Nothing coming up: a tap opens Find events.
  static final NextUpSnapshot nothing =
      NextUpSnapshot._(NextUpState.nothing, const [], siteLink('/events'));

  /// [items], soonest first; [nothing] when there are none.
  factory NextUpSnapshot.upcoming(List<NextUpItem> items) => items.isEmpty
      ? nothing
      : NextUpSnapshot._(
          NextUpState.upcoming, List.unmodifiable(items), siteLink('/events'));

  final NextUpState state;
  final List<NextUpItem> items;

  /// What a tap opens when no event is shown: sign-in (then My events) or
  /// Find events. With events, each item has its own [NextUpItem.link];
  /// this is the fallback for when every one of them is over.
  final String link;

  /// The one the widget shows at [now]: the first not over yet.
  NextUpItem? nextAt(DateTime now) {
    for (final item in items) {
      if (!item.isOverAt(now)) return item;
    }
    return null;
  }

  /// The JSON the widgets read. Version 1; a widget that finds a version it
  /// doesn't know shows the signed-out text, which a launch of the app
  /// rewrites.
  Map<String, Object?> toJson(DateTime now) => {
        'v': 1,
        'state': state.wire,
        'link': link,
        'items': [for (final item in items) item.toJson(now)],
      };
}

/// The website's address for [path]: what the widgets open. The app claims
/// the site's links, and its router reads them as its own screens
/// (`appLocationForLink`), on a phone that opens them with Flutter's deep
/// linking -- so a tap on the widget is handled as a link to the site.
String siteLink(String path) =>
    Uri.parse(AppConfig.publicSiteUrl).replace(path: path).toString();

/// The app's page for the ticket to event [eventId]: `/events/{id}/ticket`,
/// which finds the ticket on the phone (`EventTicketPage`).
String ticketLinkFor(int eventId) => siteLink('/events/$eventId/ticket');

/// How many events the widget is given: the next, and the ones after it
/// that it moves on to while the app stays closed.
const nextUpLimit = 4;

/// A registration under review is taken to last a day: it carries no length.
const _assumedLength = Duration(hours: 24);

/// What the widget shows, from what the app knows at [now].
///
/// Signed out, nothing. Signed in: the person's tickets for events that are
/// not over -- soonest first, a ticket without a date last -- and after
/// them, their registrations still under review. A revoked ticket, or one
/// to an event the club called off, is never the next thing to go to.
/// With no tickets at all, the registration under review is what's next
/// ("Under review"). At most [limit] events.
NextUpSnapshot nextUpFrom({
  required bool signedIn,
  required List<SavedTicket> tickets,
  required List<RegistrationRequest> requests,
  required DateTime now,
  int limit = nextUpLimit,
}) {
  if (!signedIn) return NextUpSnapshot.signedOut;

  final items = <NextUpItem>[];
  final seen = <int>{};

  final usable = [
    for (final ticket in tickets)
      if (!ticket.revoked &&
          ticket.cancellation == null &&
          ticket.isCurrentOrUpcoming(now))
        ticket,
  ]..sort((a, b) => _soonestFirst(a.startsAt, b.startsAt));
  for (final ticket in usable) {
    if (!seen.add(ticket.eventId)) continue;
    items.add(NextUpItem(
      eventId: ticket.eventId,
      name: _nameOf(ticket.eventName),
      startsAt: ticket.startsAt?.toUtc(),
      endsAt: ticket.endsAt?.toUtc(),
      place: ticket.isOnline ? 'Online' : _text(ticket.venue),
      club: _text(ticket.clubName),
      link: ticketLinkFor(ticket.eventId),
    ));
  }

  final waiting = <NextUpItem>[];
  for (final request in requests) {
    final event = request.event;
    if (event == null || !request.isOpen || event.id <= 0) continue;
    final start = event.eventDateTime?.toUtc();
    final end = start?.add(_assumedLength);
    if (end != null && !now.isBefore(end)) continue;
    if (seen.contains(event.id)) continue;
    seen.add(event.id);
    waiting.add(NextUpItem(
      eventId: event.id,
      name: _nameOf(event.name),
      startsAt: start,
      endsAt: end,
      club: _text(event.clubName),
      underReview: true,
      badge: request.awaitingPayment ? 'Payment due' : 'Under review',
      link: siteLink(event.route),
    ));
  }
  waiting.sort((a, b) => _soonestFirst(a.startsAt, b.startsAt));
  items.addAll(waiting);

  return NextUpSnapshot.upcoming(items.take(limit).toList());
}

/// Dated first, soonest first; undated last.
int _soonestFirst(DateTime? a, DateTime? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return a.compareTo(b);
}

String _nameOf(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty ? 'Your event' : trimmed;
}

String? _text(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
