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

  factory AgendaItem.fromJson(Map<String, dynamic> json) {
    final ends = json['ends_at'] as String?;
    return AgendaItem(
      id: json['id'] as String? ?? '',
      startsAt: DateTime.tryParse(json['starts_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endsAt: ends == null ? null : DateTime.tryParse(ends),
      title: json['title'] as String? ?? '',
      description: _blank(json['description'] as String?),
      speaker: _blank(json['speaker'] as String?),
      speakerPhotoUrl: _blank(json['speaker_photo_url'] as String?),
      location: _blank(json['location'] as String?),
      parallel: json['parallel'] as bool? ?? false,
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
    final items = (json['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AgendaItem.fromJson)
        .toList();
    return Agenda(
      items: items,
      timezone: json['timezone'] as String? ?? 'Asia/Kolkata',
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
