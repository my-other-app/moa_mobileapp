import 'package:finnet/core/utils/hours.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/registration_status.dart';

/// One person in People Like You: someone else checked in at the event.
class NetworkingAttendee {
  final int userId;
  final String name;
  final String? profilePicUrl;
  final String? organization;
  final List<SharedInterest> sharedInterests;
  final int matchCount;

  NetworkingAttendee({
    required this.userId,
    required this.name,
    this.profilePicUrl,
    this.organization,
    required this.sharedInterests,
    required this.matchCount,
  });

  factory NetworkingAttendee.fromJson(Map<String, dynamic> json) {
    final picture = jsonString(json['profile_pic_url'])?.trim();
    return NetworkingAttendee(
      userId: jsonInt(json['user_id']) ?? 0,
      name: jsonText(json['name']),
      profilePicUrl: picture == null || picture.isEmpty ? null : picture,
      organization: jsonString(json['organization']),
      sharedInterests: jsonObjects(json['shared_interests'])
          .map(SharedInterest.fromJson)
          .toList(),
      matchCount: jsonInt(json['match_count']) ?? 0,
    );
  }
}

class SharedInterest {
  final int id;
  final String name;
  final String? icon;
  final String? iconType;

  SharedInterest({
    required this.id,
    required this.name,
    this.icon,
    this.iconType,
  });

  factory SharedInterest.fromJson(Map<String, dynamic> json) {
    return SharedInterest(
      id: jsonInt(json['id']) ?? 0,
      name: jsonText(json['name']),
      icon: jsonString(json['icon']),
      iconType: jsonString(json['icon_type']),
    );
  }
}

/// People Like You for one event, as `GET /events/{id}/networking` gives
/// it: everyone else checked in who shows, those sharing most first.
class NetworkingPeople {
  final int eventId;
  final String eventName;

  /// An hour after the event ends; null when the server did not say.
  final DateTime? closesAt;

  /// The reader's own "Show me in People Like You"; null from a server
  /// without the switch.
  final bool? visible;
  final List<NetworkingAttendee> attendees;

  const NetworkingPeople({
    required this.eventId,
    required this.eventName,
    this.closesAt,
    this.visible,
    this.attendees = const [],
  });

  /// Read field by field: a row or a date of the wrong shape used to throw
  /// and lose the whole list behind an error.
  factory NetworkingPeople.fromJson(Map<String, dynamic> json,
      {required int eventId}) {
    return NetworkingPeople(
      eventId: jsonInt(json['event_id']) ?? eventId,
      eventName: jsonText(json['event_name']),
      closesAt: jsonDate(json['window_closes_at']),
      visible: jsonBool(json['visible']),
      attendees:
          jsonObjects(json['attendees']).map(NetworkingAttendee.fromJson).toList(),
    );
  }

  /// Those who share at least one interest with the reader, most first.
  List<NetworkingAttendee> get sharing =>
      [for (final a in attendees) if (a.matchCount > 0) a];

  /// Everyone else checked in who shows.
  List<NetworkingAttendee> get alsoHere =>
      [for (final a in attendees) if (a.matchCount <= 0) a];
}

/// When People Like You closes for an event: an hour after it ends. Null
/// without a start or a length -- the server keeps it shut then too.
DateTime? networkingClosesAt(DateTime? startsAt, double? durationHours) {
  if (startsAt == null || durationHours == null || durationHours <= 0) {
    return null;
  }
  return startsAt
      .add(hoursToDuration(durationHours))
      .add(const Duration(hours: 1));
}

/// Where a person stands with People Like You at one event, for the event
/// page's card.
enum NetworkingMoment {
  /// Nothing to say: not registered, no ticket yet, the event doesn't have
  /// it, or it has closed.
  none,

  /// Registered, before the event: check in on the day.
  beforeEvent,

  /// Registered, the event is on, not checked in yet: check in at the door.
  checkInNow,

  /// Checked in and open: see who's here.
  open,
}

/// The moment for the event page at [now].
///
/// [networking] is the event's word on whether it has People Like You (its
/// club's plan): false hides everything; null (a server that does not say)
/// still shows the list to someone checked in -- the list itself then says
/// whether the event has it -- but makes no promise to someone who is not.
NetworkingMoment networkingMomentFor({
  required RegistrationStatus status,
  required bool? networking,
  required DateTime? startsAt,
  required double? durationHours,
  required DateTime now,
  bool revoked = false,
}) {
  if (networking == false || revoked) return NetworkingMoment.none;
  final closes = networkingClosesAt(startsAt, durationHours);
  if (closes == null || now.isAfter(closes)) return NetworkingMoment.none;
  switch (status) {
    case RegistrationStatus.attended:
      return NetworkingMoment.open;
    case RegistrationStatus.registered:
      if (networking != true) return NetworkingMoment.none;
      return now.isBefore(startsAt!)
          ? NetworkingMoment.beforeEvent
          : NetworkingMoment.checkInNow;
    case RegistrationStatus.awaitingPayment:
    case RegistrationStatus.none:
      return NetworkingMoment.none;
  }
}
