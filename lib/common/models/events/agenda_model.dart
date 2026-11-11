import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/shared/utils/image_url.dart';

/// One of a session's speakers, picked by the club from the event's
/// speakers (`speakers: [{event_speaker_id, name, photo_thumbnail,
/// profile_slug}]`, the speakers directory). With a [profileSlug] a tap
/// opens their page; without one (a hidden profile) they are only named.
class AgendaSpeaker {
  final int? eventSpeakerId;
  final String name;
  final String? photo;
  final String? profileSlug;

  const AgendaSpeaker({
    this.eventSpeakerId,
    required this.name,
    this.photo,
    this.profileSlug,
  });

  /// Null without a name.
  static AgendaSpeaker? fromJson(Map<String, dynamic> json) {
    final name = AgendaItem._blank(jsonString(json['name']))?.trim();
    if (name == null) return null;
    return AgendaSpeaker(
      eventSpeakerId: jsonInt(json['event_speaker_id']),
      name: name,
      photo: imageUrlFrom(json['photo_thumbnail']),
      profileSlug: profileSlugFrom(json['profile_slug']),
    );
  }

  static List<AgendaSpeaker> listFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (fromJson(json) case final speaker?) speaker,
      ];
}

/// One block of an event's run of show, as `GET /events/{id}/agenda` returns it.
class AgendaItem {
  final String id;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String title;
  final String? description;
  /// The free text the club typed (older sessions), or -- for one with
  /// [speakers] and no text of its own -- their names, which the server
  /// fills in for older apps.
  final String? speaker;
  final String? speakerPhotoUrl;

  /// The session's speakers from the event's speakers, in order; empty for
  /// a session with only the free text (or on an older server).
  final List<AgendaSpeaker> speakers;
  final String? location;

  /// Two blocks are parallel when their times overlap.
  final bool parallel;

  const AgendaItem({
    required this.id,
    required this.startsAt,
    this.endsAt,
    required this.title,
    this.description,
    this.speaker,
    this.speakerPhotoUrl,
    this.speakers = const [],
    this.location,
    this.parallel = false,
  });

  /// Read field by field (core/utils/json_read.dart): a numeric id or a
  /// missing title used to throw, and the whole agenda went with it.
  factory AgendaItem.fromJson(Map<String, dynamic> json) {
    return AgendaItem(
      id: jsonText(json['id']),
      startsAt:
          jsonDate(json['starts_at']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: jsonDate(json['ends_at']),
      title: jsonText(json['title']),
      description: _blank(jsonString(json['description'])),
      speaker: _blank(jsonString(json['speaker'])),
      speakerPhotoUrl: _blank(jsonString(json['speaker_photo_url'])),
      speakers: AgendaSpeaker.listFrom(json['speakers']),
      location: _blank(jsonString(json['location'])),
      parallel: jsonBool(json['parallel']) ?? false,
    );
  }

  /// The free text, when it says something [speakers] do not: text naming
  /// any of them -- their names as the server fills them in, or the old
  /// text they were matched from -- is shown by them instead.
  String? get speakerText {
    final text = speaker;
    if (text == null || speakers.isEmpty) return text;
    final lower = text.toLowerCase();
    final named = speakers.any((s) => lower.contains(s.name.toLowerCase()));
    return named ? null : text;
  }

  /// Speaker and room on one line, as the programme prints them. Linked
  /// [speakers] show on their own, so only [speakerText] is here.
  String get detail => [speakerText, location]
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');

  static String? _blank(String? s) =>
      (s == null || s.trim().isEmpty) ? null : s;
}

/// The run of show with the zone its times are meant to be read in.
class Agenda {
  final List<AgendaItem> items;
  final String timezone;

  const Agenda({required this.items, this.timezone = 'Asia/Kolkata'});

  factory Agenda.fromJson(Map<String, dynamic> json) {
    final items = jsonObjects(json['items']).map(AgendaItem.fromJson).toList();
    return Agenda(
      items: items,
      timezone: jsonString(json['timezone']) ?? 'Asia/Kolkata',
    );
  }

  /// Items grouped by calendar day (local time), in order.
  Map<DateTime, List<AgendaItem>> get byDay {
    final out = <DateTime, List<AgendaItem>>{};
    for (final item in items) {
      final local = item.startsAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      out.putIfAbsent(day, () => []).add(item);
    }
    return out;
  }
}
