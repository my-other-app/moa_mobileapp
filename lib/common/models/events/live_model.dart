import 'package:finnet/core/utils/json_read.dart';

/// What the event's live room is doing right now, as the event page needs it:
/// enough to draw a strip and open the room, nothing more. The room itself
/// (voting, polls, the quiz) is its own screen (lib/features/live/).
///
/// Read from the room's body or from the strip's smaller `banner` view,
/// which has the event and its banner and nothing of the poll, the quiz or
/// the questions.
class LiveFeed {
  const LiveFeed({
    required this.eventId,
    this.eventStatus,
    this.startsAt,
    this.endsAt,
    this.bannerText,
    this.bannerKind,
    this.pollPrompt,
    this.quizLive = false,
    this.quizTitle,
    this.questions = 0,
  });

  static const LiveFeed empty = LiveFeed(eventId: 0);

  final int eventId;

  /// `event.status`: where the event is on its status clock (`published`,
  /// `live`, `closed`, ...), as the website reads it. Null from a server that
  /// does not send it.
  final String? eventStatus;

  /// The event's start and end, from the `banner` view.
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? bannerText;
  final String? bannerKind;
  final String? pollPrompt;
  final bool quizLive;
  final String? quizTitle;
  final int questions;

  factory LiveFeed.fromJson(Map<String, dynamic> json) {
    final event = json['event'];
    final banner = json['banner'];
    final poll = json['poll'];
    final quiz = json['quiz'];
    final questions = json['questions'];
    return LiveFeed(
      eventId: event is Map ? (event['id'] as num?)?.toInt() ?? 0 : 0,
      eventStatus: event is Map && event['status'] is String
          ? event['status'] as String
          : null,
      startsAt: event is Map ? jsonDate(event['starts_at']) : null,
      endsAt: event is Map ? jsonDate(event['ends_at']) : null,
      bannerText: banner is Map ? banner['text'] as String? : null,
      bannerKind: banner is Map ? banner['kind'] as String? : null,
      pollPrompt: poll is Map ? poll['prompt'] as String? : null,
      quizLive: quiz is Map && quiz['live'] == true,
      quizTitle: quiz is Map ? quiz['title'] as String? : null,
      questions: questions is List ? questions.length : 0,
    );
  }

  /// The room's body -- the poll's (`GET /events/{id}/live`), or a stream
  /// snapshot's, which is the same JSON -- or null for anything else.
  static LiveFeed? tryParse(Object? json) =>
      json is Map<String, dynamic> ? LiveFeed.fromJson(json) : null;

  /// The event is happening now (`event.status == 'live'`, the website's
  /// test): the only time the page keeps a stream open.
  bool get isEventLive => eventStatus == 'live';

  /// The event is over: its room is closed.
  bool get isClosed => eventStatus == 'closed' || eventStatus == 'archived';

  /// Whether there is anything worth a strip on the event page: the event
  /// is happening, or the room has something up.
  bool get isActive =>
      isEventLive ||
      bannerText != null ||
      pollPrompt != null ||
      quizLive ||
      questions > 0;

  /// The one line the strip shows.
  String get headline {
    if (bannerText != null) return bannerText!;
    if (quizLive) return 'The quiz is on — join with the code on the screen';
    if (pollPrompt != null) return pollPrompt!;
    if (questions > 0) return 'Questions are being taken from the floor';
    return 'The live room is open — updates, polls and questions';
  }
}
