import 'package:finnet/core/utils/json_read.dart';
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

  /// One row of `/events/volunteer/my-events`, read field by field: an
  /// odd value (a null slug, a draft with no date yet) costs that field or
  /// that row, never the volunteer's whole list. Null for a row with no id
  /// or no date, which can't be shown or opened.
  static VolunteerEvent? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null) return null;
    final id = jsonInt(json['id']);
    // In the phone's time: the card shows its day.
    final at = jsonDate(json['event_datetime']);
    if (id == null || at == null) return null;
    final poster = jsonObject(json['poster']);
    final club = jsonObject(json['club']);

    return VolunteerEvent(
      id: id,
      slug: jsonText(json['slug']),
      name: jsonText(json['name']),
      posterUrl: jsonString(poster?['large']) ?? jsonString(poster?['medium']),
      poster: poster,
      // The S3 dict, an older row's bare URL, or a club without a logo.
      clubLogoUrl: imageUrlFrom(club?['logo']),
      clubName: jsonText(club?['name']),
      eventDatetime: at,
      hasFee: jsonBool(json['has_fee']) ?? false,
      regFee: jsonDouble(json['reg_fee']) ?? 0.0,
      maxParticipants: jsonInt(json['max_participants']),
    );
  }
}
