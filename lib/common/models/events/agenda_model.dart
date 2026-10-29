import 'package:finnet/core/utils/json_read.dart';

/// One block of an event's run of show, as `GET /events/{id}/agenda` returns it.
class AgendaItem {
  final String id;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String title;
  final String? description;
  final String? speaker;
  final String? speakerPhotoUrl;
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
      location: _blank(jsonString(json['location'])),
      parallel: jsonBool(json['parallel']) ?? false,
    );
  }

  /// Speaker and room on one line, as the programme prints them.
  String get detail => [speaker, location]
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
