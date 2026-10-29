import 'package:finnet/shared/utils/image_url.dart';

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
    final club = json['club'] is Map ? json['club'] as Map : null;
    final clubName = club?['name'];

    return VolunteerEvent(
      id: json['id'] as int,
      slug: json['slug'] as String,
      name: json['name'] as String,
      posterUrl: poster?['large'] as String? ?? poster?['medium'] as String?,
      poster: poster,
      // The S3 dict, an older row's bare URL, or a club without a logo.
      clubLogoUrl: imageUrlFrom(club?['logo']),
      clubName: clubName is String ? clubName : '',
      // In the phone's time: the card shows its day.
      eventDatetime: DateTime.parse(json['event_datetime'] as String).toLocal(),
      hasFee: json['has_fee'] as bool? ?? false,
      regFee: (json['reg_fee'] as num?)?.toDouble() ?? 0.0,
      maxParticipants: json['max_participants'] as int?,
    );
  }
}
