/// A short post by a club, shown on the club's NOTES tab.
///
/// Mirrors `NoteListResponse` in `app/api/clubs/schemas.py`.
class ClubNote {
  final int id;
  final String title;
  final String note;
  final DateTime createdAt;

  const ClubNote({
    required this.id,
    required this.title,
    required this.note,
    required this.createdAt,
  });

  factory ClubNote.fromJson(Map<String, dynamic> json) {
    return ClubNote(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      note: json['note'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }

  /// "2 hours ago", for the card's subtitle.
  ///
  /// Deliberately coarse: a note is not time-critical, and "3 days ago"
  /// reads better than a timestamp nobody needs to the minute.
  String get relativeTime {
    final difference = DateTime.now().difference(createdAt);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
    }
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'day' : 'days'} ago';
    }
    if (difference.inDays < 365) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    }
    final years = difference.inDays ~/ 365;
    return '$years ${years == 1 ? 'year' : 'years'} ago';
  }
}
