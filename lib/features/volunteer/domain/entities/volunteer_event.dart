/// An event this user is a volunteer for.
///
/// Mirrors `MyEventEventDetails` on the server
/// (`app/api/events/volunteer/schemas.py`).
class VolunteerEvent {
  final int id;
  final String slug;
  final String name;
  final String? posterUrl;

  /// The poster's sizes as the server sent them, so each screen can pick
  /// the one it needs. Null when the event has no poster.
  final Map<String, dynamic>? poster;
  final String? clubLogoUrl;
  final String clubName;
  final DateTime eventDatetime;
  final bool hasFee;
  final double regFee;
  final int? maxParticipants;

  const VolunteerEvent({
    required this.id,
    required this.slug,
    required this.name,
    this.posterUrl,
    this.poster,
    this.clubLogoUrl,
    required this.clubName,
    required this.eventDatetime,
    required this.hasFee,
    required this.regFee,
    this.maxParticipants,
  });

  factory VolunteerEvent.fromJson(Map<String, dynamic> json) {
    final poster = json['poster'] as Map<String, dynamic>?;
    final club = json['club'] as Map<String, dynamic>?;
    final clubLogo = club?['logo'] as Map<String, dynamic>?;

    return VolunteerEvent(
      id: json['id'] as int,
      slug: json['slug'] as String,
      name: json['name'] as String,
      posterUrl: poster?['large'] as String? ?? poster?['medium'] as String?,
      poster: poster,
      clubLogoUrl: clubLogo?['thumbnail'] as String?,
      clubName: club?['name'] as String? ?? '',
      eventDatetime: DateTime.parse(json['event_datetime'] as String),
      hasFee: json['has_fee'] as bool? ?? false,
      regFee: (json['reg_fee'] as num?)?.toDouble() ?? 0.0,
      maxParticipants: json['max_participants'] as int?,
    );
  }
}

/// How a scan came out. Each value is a distinct screen in the scanner.
enum CheckinResultType {
  /// Valid ticket -- show the holder's details and the grant-entry button.
  success,

  /// No registration anywhere with this ticket id.
  notFound,

  /// The ticket is real but has already been used.
  alreadyScanned,

  /// Registered but the fee is unpaid.
  unpaid,

  /// The ticket is real and unused, but for a different event.
  incorrectEvent,

  /// This user is not a volunteer for this event, so the server refused.
  ///
  /// Previously collapsed into [notFound], which told a volunteer whose
  /// permission had been revoked that the attendee's ticket was invalid --
  /// sending them to argue with the wrong person at the door.
  notPermitted,

  /// The scan never got an answer: no network, a timeout, or a 5xx.
  ///
  /// Also previously collapsed into [notFound]. A volunteer on bad venue wifi
  /// was told the attendee's ticket was invalid, when the right instruction
  /// is to scan it again. This is the only refusal worth retrying.
  unreachable,
}

/// The outcome of a validate or check-in call, including the holder's details
/// on success.
class CheckinResult {
  final bool success;
  final CheckinResultType type;
  final String message;
  final String? ticketId;
  final String? ticketHolderName;
  final String? ticketHolderEmail;
  final String? ticketType;
  final DateTime? eventDate;
  final String? eventTime;
  final String? location;

  /// The event the ticket is really for, when [type] is
  /// [CheckinResultType.incorrectEvent]. The server names it in prose; this
  /// is the same name as a field, for the screen that wants to show it.
  final String? actualEventName;

  const CheckinResult({
    required this.success,
    required this.type,
    required this.message,
    this.ticketId,
    this.ticketHolderName,
    this.ticketHolderEmail,
    this.ticketType,
    this.eventDate,
    this.eventTime,
    this.location,
    this.actualEventName,
  });

  /// A refusal, carrying only why.
  const CheckinResult.refused({
    required this.type,
    required this.message,
    this.ticketId,
    this.actualEventName,
  })  : success = false,
        ticketHolderName = null,
        ticketHolderEmail = null,
        ticketType = null,
        eventDate = null,
        eventTime = null,
        location = null;
}
