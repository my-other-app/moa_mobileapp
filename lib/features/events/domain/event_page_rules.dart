import 'package:intl/intl.dart';

import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/config/app_config.dart';

// What the event page works out from the event, with no widgets: what the
// register button can do now, the event's addresses (to share, the live
// room, directions) and its calendar entry. The website's own reading is
// moa_eventwebsite `src/utils/eventpage.js` and `src/utils/calendar.js`.

/// What the register button can do right now.
enum RegisterKind {
  /// Taking registrations.
  open,

  /// Not yet: registration opens later.
  soon,

  /// The deadline has passed, or the organiser closed it.
  closed,

  /// Every place is taken. There is no waitlist on the server, so this is
  /// where a waitlist would be.
  full,

  /// Happening now.
  live,

  /// Over.
  ended,
}

/// The button, and the line under it.
class RegisterState {
  final RegisterKind kind;

  /// The button's words.
  final String label;

  /// A line about it ("Only 3 seats left"), or null.
  final String? note;

  /// [note] is urgent: few seats left, or closing soon.
  final bool urgent;

  /// The button registers: [kind] is open, or live while registration is
  /// still open.
  final bool canRegister;

  const RegisterState({
    required this.kind,
    required this.label,
    this.note,
    this.urgent = false,
    this.canRegister = false,
  });
}

/// Few enough seats to say so.
const lowSeats = 10;

/// "18 Oct".
String _shortDate(DateTime d) => DateFormat('d MMM').format(d.toLocal());

/// "Sat, 18 Oct · 6:00 PM".
String whenLine(DateTime d) =>
    DateFormat("EEE, d MMM '·' h:mm a").format(d.toLocal());

/// What the register button says and does, from the event as both APIs
/// describe it. [phase], [registrationOpen] and [seatsLeft] are the website
/// API's (`/discover/events/{ref}`); without them -- a non-public event, or
/// that call failed -- the dates from `/events/info` decide.
RegisterState registerStateFor({
  required DateTime now,
  EventPhase? phase,
  bool? registrationOpen,
  int? capacity,
  int? seatsLeft,
  DateTime? regOpensAt,
  DateTime? regClosesAt,
  DateTime? startsAt,
  DateTime? endsAt,
}) {
  final started = startsAt != null && !startsAt.isAfter(now);
  final over = endsAt != null && !endsAt.isAfter(now);
  final effectivePhase = phase ??
      (over
          ? EventPhase.ended
          : started
              ? EventPhase.live
              : EventPhase.upcoming);
  final notYet = regOpensAt != null && regOpensAt.isAfter(now);
  final pastDeadline = regClosesAt != null && !regClosesAt.isAfter(now);
  final open = registrationOpen ?? (!notYet && !pastDeadline && !over);

  if (effectivePhase == EventPhase.ended) {
    return const RegisterState(kind: RegisterKind.ended, label: 'EVENT ENDED');
  }
  if (effectivePhase == EventPhase.live) {
    return RegisterState(
      kind: RegisterKind.live,
      label: open ? 'REGISTER NOW' : 'OPEN THE LIVE ROOM',
      note: 'Happening now',
      canRegister: open,
    );
  }
  if (effectivePhase == EventPhase.full || (seatsLeft == 0 && open)) {
    return RegisterState(
      kind: RegisterKind.full,
      label: 'EVENT FULL',
      note: capacity != null
          ? 'All $capacity seats are taken.'
          : 'Every seat is taken.',
    );
  }
  if (open) {
    if (seatsLeft != null && seatsLeft <= lowSeats) {
      return RegisterState(
        kind: RegisterKind.open,
        label: 'REGISTER NOW',
        note: 'Only $seatsLeft ${seatsLeft == 1 ? 'seat' : 'seats'} left',
        urgent: true,
        canRegister: true,
      );
    }
    if (effectivePhase == EventPhase.closingSoon) {
      return RegisterState(
        kind: RegisterKind.open,
        label: 'REGISTER NOW',
        note: regClosesAt != null
            ? 'Closing soon · closes ${whenLine(regClosesAt)}'
            : 'Registration closes soon',
        urgent: true,
        canRegister: true,
      );
    }
    return const RegisterState(
      kind: RegisterKind.open,
      label: 'REGISTER NOW',
      canRegister: true,
    );
  }
  if (notYet) {
    return RegisterState(
      kind: RegisterKind.soon,
      label: 'REGISTRATION OPENS ${_shortDate(regOpensAt).toUpperCase()}',
      note: 'Opens ${whenLine(regOpensAt)}',
    );
  }
  return const RegisterState(
    kind: RegisterKind.closed,
    label: 'REGISTRATION CLOSED',
  );
}

/// "Tinkerhub reviews every registration", or "The club reviews every
/// registration" without a name: the short form, said in one-line stat
/// spots where an event whose club reviews every registration would say
/// "Be the first to register". Never a count of registrations under review.
String confirmsEachPlaceLine(String? clubName) {
  final name = clubName?.trim();
  return '${name == null || name.isEmpty ? 'The club' : name} reviews every '
      'registration';
}

/// "Tinkerhub reviews every registration and emails tickets to the people
/// it confirms.": the note by the register button, and on the form, of an
/// event whose club reviews every registration.
String reviewsEveryRegistrationNote(String? clubName) =>
    '${confirmsEachPlaceLine(clubName)} and emails tickets to the people it '
    'confirms.';

/// "12 going · 38 seats left", "Be the first to register", or null when
/// there is nothing to say.
///
/// An event whose club reviews every registration ([confirmsEach]) with
/// nobody going yet says so instead ("Tinkerhub reviews every registration
/// · 38 seats left"): people may have registered already, and the page
/// shows no numbers.
String? seatsLine({
  required int going,
  int? seatsLeft,
  bool confirmsEach = false,
  String? clubName,
}) {
  final parts = [
    if (going > 0)
      '$going going'
    else if (confirmsEach)
      confirmsEachPlaceLine(clubName),
    if (seatsLeft != null && seatsLeft > 0)
      '$seatsLeft ${seatsLeft == 1 ? 'seat' : 'seats'} left',
  ];
  if (parts.isNotEmpty) return parts.join(' · ');
  return seatsLeft != null ? 'Be the first to register' : null;
}

/// Whether an event shows the club's "High demand" chip (`high_demand`,
/// the club's own label, with no number behind it): while it is still to
/// come or on, never once it has ended or was called off.
bool showsHighDemand({
  required bool highDemand,
  bool ended = false,
  bool cancelled = false,
}) =>
    highDemand && !ended && !cancelled;

/// The share of places taken, 0 to 1; null when the event has no limit.
double? seatsTaken({int? capacity, int? seatsLeft}) {
  if (capacity == null || capacity <= 0 || seatsLeft == null) return null;
  final taken = (capacity - seatsLeft).clamp(0, capacity);
  return taken / capacity;
}

// ---------------------------------------------------------------- addresses

/// The event's canonical address on the website, the one to share: by
/// slug, or the API's own `url`, or by id.
String eventCanonicalUrl({required int id, String? slug, String? apiUrl}) {
  final s = slug?.trim() ?? '';
  if (s.isNotEmpty) {
    return '${AppConfig.publicSiteUrl}/events/${Uri.encodeComponent(s)}';
  }
  final given = apiUrl?.trim() ?? '';
  if (given.startsWith('https://')) return given;
  return '${AppConfig.publicSiteUrl}/events/$id';
}

/// The event's live room on the website: `/events/{slug}/live`, or by id
/// (the website sends that on to the slug).
Uri eventLiveRoomUri({required Object id, String? slug}) {
  final s = slug?.trim() ?? '';
  final ref = s.isNotEmpty ? Uri.encodeComponent(s) : '$id';
  return Uri.parse('${AppConfig.publicSiteUrl}/events/$ref/live');
}

/// Whether [ref], from an address, is an event's id rather than its slug.
int? eventIdOf(String ref) {
  final t = ref.trim();
  return RegExp(r'^\d+$').hasMatch(t) ? int.tryParse(t) : null;
}

/// Directions to the venue in the phone's own maps app: Apple Maps on an
/// iPhone, Google Maps on Android.
///
/// The point on the map when there is one; else the organiser's map link
/// (on Android, where it opens Google Maps; an iPhone gets Apple Maps
/// searching the venue's name, when it has one); else the venue's name.
/// Null with nothing to go on.
Uri? directionsUri({
  required bool ios,
  double? lat,
  double? lng,
  String? name,
  String? link,
}) {
  final place = name?.trim() ?? '';
  final mapLink = safeWebLink(link);
  if (lat != null && lng != null) {
    return ios
        ? Uri.https('maps.apple.com', '/', {
            'daddr': '$lat,$lng',
            if (place.isNotEmpty) 'q': place,
          })
        : Uri.https('www.google.com', '/maps/dir/', {
            'api': '1',
            'destination': '$lat,$lng',
          });
  }
  if (ios) {
    if (place.isNotEmpty) {
      return Uri.https('maps.apple.com', '/', {'daddr': place});
    }
    return mapLink;
  }
  if (mapLink != null) return mapLink;
  if (place.isNotEmpty) {
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': place,
    });
  }
  return null;
}

// ---------------------------------------------------------------- calendar

/// An event for the phone's calendar.
class CalendarEntry {
  final String title;
  final DateTime start;
  final DateTime end;
  final String location;
  final String description;

  const CalendarEntry({
    required this.title,
    required this.start,
    required this.end,
    this.location = '',
    this.description = '',
  });
}

/// An event with no end is given two hours.
const defaultEventLength = Duration(hours: 2);

/// The calendar entry for an event; null without a start.
///
/// The end is the one given when it is after the start, else the start
/// plus [durationHours], else two hours. An online event is "Online". The
/// description is the first lines of [about] and the event's address.
CalendarEntry? calendarEntryFor({
  required String name,
  DateTime? startsAt,
  DateTime? endsAt,
  double? durationHours,
  bool isOnline = false,
  String? locationName,
  String? about,
  String? url,
}) {
  final start = startsAt;
  if (start == null) return null;
  var end = endsAt;
  if (end == null || !end.isAfter(start)) {
    end = durationHours != null && durationHours > 0
        ? start.add(Duration(minutes: (durationHours * 60).round()))
        : start.add(defaultEventLength);
  }
  final summary = summarise(about ?? '', 600);
  return CalendarEntry(
    title: name.trim().isEmpty ? 'Event' : name.trim(),
    start: start,
    end: end,
    location: isOnline ? 'Online' : (locationName?.trim() ?? ''),
    description: [
      if (summary.isNotEmpty) summary,
      if (url != null && url.isNotEmpty) url,
    ].join('\n\n'),
  );
}

/// "20261018T123000Z".
String utcStamp(DateTime d) {
  final u = d.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
      'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// Google Calendar's "add event" page for [entry]: where "Add to calendar"
/// goes when the phone has no calendar app to hand it to.
Uri googleCalendarUri(CalendarEntry entry) => Uri.https(
      'calendar.google.com',
      '/calendar/render',
      {
        'action': 'TEMPLATE',
        'text': entry.title,
        'dates': '${utcStamp(entry.start)}/${utcStamp(entry.end)}',
        if (entry.description.isNotEmpty) 'details': entry.description,
        if (entry.location.isNotEmpty) 'location': entry.location,
        'ctz': 'Asia/Kolkata',
      },
    );

/// The first [max] characters of [text] on one line, cut at a word.
String summarise(String text, int max) {
  final s = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (s.length <= max) return s;
  final cut = s.substring(0, max - 1);
  final space = cut.lastIndexOf(' ');
  final head = space > max * 0.6 ? cut.substring(0, space) : cut;
  return '${head.replaceFirst(RegExp(r'[\s,.;:!?-]+$'), '')}…';
}

// ---------------------------------------------------------------- feedback

/// The app's route for a survey link from the website
/// (`https://myotherapp.in/feedback/{eventId}/{registrationId}?k=…`):
/// `/feedback/{eventId}/{registrationId}?k=…`. Null for any other link.
String? feedbackRouteFrom(String link) {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
    return null;
  }
  final site = Uri.parse(AppConfig.publicSiteUrl).host;
  final host = uri.host.toLowerCase();
  if (host != site && !host.endsWith('.$site')) return null;
  final parts = uri.pathSegments.where((p) => p.isNotEmpty).toList();
  if (parts.length != 3 || parts[0] != 'feedback') return null;
  if (eventIdOf(parts[1]) == null || parts[2].isEmpty) return null;
  final key = uri.queryParameters['k'] ?? '';
  return Uri(
    path: '/feedback/${parts[1]}/${parts[2]}',
    queryParameters: key.isEmpty ? null : {'k': key},
  ).toString();
}
