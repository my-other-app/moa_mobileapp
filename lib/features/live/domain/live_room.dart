/// The event's live room as the people in it see it: `GET
/// /events/{id}/live` (the `room` view; a stream snapshot is the same JSON).
///
/// Read leniently, field by field: a server that sends less (an older one)
/// or more (a newer one) still gives a room, never an exception.
library;

int _int(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

DateTime? _date(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

List<Map<String, dynamic>> _maps(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map) Map<String, dynamic>.from(e),
      ]
    : const [];

/// An update the organiser pushed: a room change, a schedule change, news.
class LiveUpdate {
  const LiveUpdate({
    required this.id,
    required this.text,
    this.kind = 'general',
    this.sentAt,
  });

  final String id;
  final String text;

  /// `schedule`, `room` or `general`.
  final String kind;
  final DateTime? sentAt;

  /// What the website calls each kind.
  String get kindLabel => switch (kind) {
        'schedule' => 'Schedule change',
        'room' => 'Room change',
        _ => 'Update',
      };

  static LiveUpdate? fromJson(Object? json) {
    if (json is! Map) return null;
    final text = _str(json['text']);
    if (text == null) return null;
    return LiveUpdate(
      id: _str(json['id']) ?? text,
      text: text,
      kind: _str(json['kind']) ?? 'general',
      sentAt: _date(json['sent_at']),
    );
  }
}

/// One answer of a multiple-choice poll, with its share so far.
class PollChoice {
  const PollChoice({required this.label, this.count = 0, this.pct = 0});
  final String label;
  final int count;

  /// 0 to 100.
  final int pct;
}

/// A word of a word cloud, and how many said it.
class PollWord {
  const PollWord({required this.word, this.count = 0});
  final String word;
  final int count;
}

/// The poll the organiser has up.
class LivePoll {
  const LivePoll({
    required this.id,
    required this.kind,
    required this.prompt,
    this.options = const [],
    this.status = 'live',
    this.responses = 0,
    this.choices = const [],
    this.words = const [],
    this.ratingAverage,
    this.myResponse,
  });

  final String id;

  /// `choice`, `words` or `rating` (1 to 5).
  final String kind;
  final String prompt;
  final List<String> options;
  final String status;
  final int responses;
  final List<PollChoice> choices;

  /// The room's words, most said first (the server sends the top few).
  final List<PollWord> words;
  final double? ratingAverage;

  /// This phone's (or this account's) answer, when it has given one.
  final String? myResponse;

  bool get isChoice => kind == 'choice';
  bool get isWords => kind == 'words';
  bool get isRating => kind == 'rating';
  bool get answered => myResponse != null;

  /// The choices to draw: the server's counts, or the options before any
  /// came in.
  List<PollChoice> get choicesToShow => choices.isNotEmpty
      ? choices
      : [for (final o in options) PollChoice(label: o)];

  LivePoll withMyResponse(String? value) => LivePoll(
        id: id,
        kind: kind,
        prompt: prompt,
        options: options,
        status: status,
        responses: responses,
        choices: choices,
        words: words,
        ratingAverage: ratingAverage,
        myResponse: value,
      );

  static LivePoll? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    final prompt = _str(json['prompt']);
    if (id == null || prompt == null) return null;
    final results = json['results'] is Map ? json['results'] as Map : const {};
    final rating = results['rating'] is Map ? results['rating'] as Map : null;
    final average = rating?['average'];
    return LivePoll(
      id: id,
      kind: _str(json['kind']) ?? 'choice',
      prompt: prompt,
      options: json['options'] is List
          ? [
              for (final o in json['options'] as List)
                if (_str(o) != null) _str(o)!,
            ]
          : const [],
      status: _str(json['status']) ?? 'live',
      responses: _int(results['responses']),
      choices: [
        for (final c in _maps(results['choices']))
          if (_str(c['label']) != null)
            PollChoice(
              label: _str(c['label'])!,
              count: _int(c['count']),
              pct: _int(c['pct']).clamp(0, 100),
            ),
      ],
      words: [
        for (final w in _maps(results['words']))
          if (_str(w['word']) != null)
            PollWord(word: _str(w['word'])!, count: _int(w['count'])),
      ],
      ratingAverage: average is num ? average.toDouble() : null,
      myResponse: _str(json['my_response']),
    );
  }
}

/// A question from the floor.
class LiveQuestion {
  const LiveQuestion({
    required this.id,
    required this.text,
    this.authorName,
    this.status = 'approved',
    this.pinned = false,
    this.votes = 0,
    this.createdAt,
    this.voted = false,
    this.mine = false,
  });

  final String id;
  final String text;
  final String? authorName;

  /// `pending` (waiting for the organiser), `approved`, `answered`.
  final String status;

  /// On the big screen now.
  final bool pinned;
  final int votes;
  final DateTime? createdAt;

  /// This phone (or account) voted it up.
  final bool voted;

  /// Asked from this phone (or account).
  final bool mine;

  bool get answered => status == 'answered';
  bool get pending => status == 'pending';

  LiveQuestion withVote({required int votes, required bool voted}) =>
      LiveQuestion(
        id: id,
        text: text,
        authorName: authorName,
        status: status,
        pinned: pinned,
        votes: votes < 0 ? 0 : votes,
        createdAt: createdAt,
        voted: voted,
        mine: mine,
      );

  static LiveQuestion? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    final text = _str(json['text']);
    if (id == null || text == null) return null;
    return LiveQuestion(
      id: id,
      text: text,
      authorName: _str(json['author_name']),
      status: _str(json['status']) ?? 'approved',
      pinned: json['pinned'] == true,
      votes: _int(json['votes']),
      createdAt: _date(json['created_at']),
      voted: json['voted'] == true,
      mine: json['mine'] == true,
    );
  }
}

/// The board's order: the one on the screen first, then the most voted,
/// then the oldest.
List<LiveQuestion> sortQuestions(Iterable<LiveQuestion> questions) {
  final list = questions.toList();
  final at = {for (var i = 0; i < list.length; i++) list[i].id: i};
  list.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    if (a.votes != b.votes) return b.votes.compareTo(a.votes);
    final ac = a.createdAt, bc = b.createdAt;
    if (ac != null && bc != null && ac != bc) return ac.compareTo(bc);
    return at[a.id]!.compareTo(at[b.id]!);
  });
  return list;
}

/// The room.
class LiveRoom {
  const LiveRoom({
    required this.eventId,
    this.eventName,
    this.eventStatus,
    this.banner,
    this.updates = const [],
    this.poll,
    this.questions = const [],
    this.qaOpen = false,
    this.approveFirst = false,
    this.quizLive = false,
    this.quizTitle,
  });

  final int eventId;
  final String? eventName;

  /// `published`, `live`, `closed`, `archived`; null from a server that
  /// does not say.
  final String? eventStatus;

  /// The latest update, while it is fresh (the server's three hours).
  final LiveUpdate? banner;

  /// The latest updates, newest first (the banner among them).
  final List<LiveUpdate> updates;
  final LivePoll? poll;

  /// On the board: approved and answered, in the board's order.
  final List<LiveQuestion> questions;

  /// The floor takes questions: the event is not over, and the club's plan
  /// has Q&A (when it does not, the server says closed rather than refuse).
  final bool qaOpen;

  /// A question shows once the organiser lets it through.
  final bool approveFirst;
  final bool quizLive;
  final String? quizTitle;

  /// The event is over: the room is read-only.
  bool get isClosed => eventStatus == 'closed' || eventStatus == 'archived';

  bool get isEventLive => eventStatus == 'live';

  /// Updates before the banner's: "Earlier tonight".
  List<LiveUpdate> get earlier =>
      updates.length > 1 ? updates.sublist(1) : const [];

  /// Nothing to show at all.
  bool get isEmpty =>
      banner == null &&
      updates.isEmpty &&
      poll == null &&
      questions.isEmpty &&
      !qaOpen &&
      !quizLive;

  LiveRoom copyWith({
    LivePoll? Function()? poll,
    List<LiveQuestion>? questions,
    bool? qaOpen,
  }) =>
      LiveRoom(
        eventId: eventId,
        eventName: eventName,
        eventStatus: eventStatus,
        banner: banner,
        updates: updates,
        poll: poll != null ? poll() : this.poll,
        questions: questions ?? this.questions,
        qaOpen: qaOpen ?? this.qaOpen,
        approveFirst: approveFirst,
        quizLive: quizLive,
        quizTitle: quizTitle,
      );

  static LiveRoom? tryParse(Object? json) {
    if (json is! Map) return null;
    final event = json['event'] is Map ? json['event'] as Map : const {};
    final qa = json['qa'] is Map ? json['qa'] as Map : const {};
    final quiz = json['quiz'] is Map ? json['quiz'] as Map : const {};
    final updates = [
      for (final u in (json['updates'] is List ? json['updates'] as List : []))
        if (LiveUpdate.fromJson(u) != null) LiveUpdate.fromJson(u)!,
    ];
    return LiveRoom(
      eventId: _int(event['id']),
      eventName: _str(event['name']),
      eventStatus: _str(event['status']),
      banner: LiveUpdate.fromJson(json['banner']),
      updates: updates,
      poll: LivePoll.fromJson(json['poll']),
      questions: sortQuestions([
        for (final q
            in (json['questions'] is List ? json['questions'] as List : []))
          if (LiveQuestion.fromJson(q) != null) LiveQuestion.fromJson(q)!,
      ]),
      qaOpen: qa['open'] == true,
      approveFirst: qa['approve_first'] == true,
      quizLive: quiz['live'] == true,
      quizTitle: _str(quiz['title']),
    );
  }
}
