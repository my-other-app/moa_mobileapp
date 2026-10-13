/// What the event's live room is doing right now, as the event page needs it:
/// enough to draw a strip and open the room, nothing more. The room itself
/// (voting, polls, the quiz) is the web page, so it is the same on every phone.
class LiveFeed {
  const LiveFeed({
    required this.eventId,
    this.bannerText,
    this.bannerKind,
    this.pollPrompt,
    this.quizLive = false,
    this.quizTitle,
    this.questions = 0,
  });

  static const LiveFeed empty = LiveFeed(eventId: 0);

  final int eventId;
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
      bannerText: banner is Map ? banner['text'] as String? : null,
      bannerKind: banner is Map ? banner['kind'] as String? : null,
      pollPrompt: poll is Map ? poll['prompt'] as String? : null,
      quizLive: quiz is Map && quiz['live'] == true,
      quizTitle: quiz is Map ? quiz['title'] as String? : null,
      questions: questions is List ? questions.length : 0,
    );
  }

  /// Whether there is anything worth a strip on the event page.
  bool get isActive =>
      bannerText != null || pollPrompt != null || quizLive || questions > 0;

  /// The one line the strip shows.
  String get headline {
    if (bannerText != null) return bannerText!;
    if (quizLive) return 'The quiz is on — join with the code on the screen';
    if (pollPrompt != null) return pollPrompt!;
    return 'Questions are being taken from the floor';
  }
}
