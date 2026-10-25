/// The quiz as a player sees it: joining with the code on the screen, the
/// player's view (`GET /events/{id}/live/quiz/play`, polled or streamed),
/// and an answer.
///
/// Two servers are read alike. Today's tells a player the right answer as
/// soon as they answer (`correct_key` in the answer and in the state). The
/// fairer one keeps it until the clock runs out: an answer comes back as
/// `{correct: null, points: null, answered: true}`, and the state shows
/// `correct_key` and the player's `my_correct` once time is up.
library;

int _int(Object? v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? fallback;

int? _intOrNull(Object? v) =>
    v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);

String? _str(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

/// Who this phone is in an event's quiz: what joining gave back.
class QuizPlayer {
  const QuizPlayer({
    required this.eventId,
    required this.playerKey,
    required this.name,
    this.quizId,
    this.playerId,
    this.title,
  });

  final int eventId;

  /// Sent as `X-Live-Player` on every call of the game.
  final String playerKey;
  final String name;
  final String? quizId;
  final String? playerId;
  final String? title;

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'player_key': playerKey,
        'name': name,
        if (quizId != null) 'quiz_id': quizId,
        if (playerId != null) 'player_id': playerId,
        if (title != null) 'title': title,
      };

  static QuizPlayer? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = _str(json['player_key']);
    final eventId = _intOrNull(json['event_id']);
    if (key == null || eventId == null) return null;
    return QuizPlayer(
      eventId: eventId,
      playerKey: key,
      name: _str(json['name']) ?? '',
      quizId: _str(json['quiz_id']),
      playerId: _str(json['player_id']),
      title: _str(json['title']),
    );
  }
}

/// One answer on the screen.
class QuizOption {
  const QuizOption({required this.key, required this.label});
  final String key;
  final String label;
}

/// The question that is open (or just closed).
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    this.seconds = 20,
    this.timeLeft = 0,
    this.myAnswer,
    this.myPoints,
    this.myCorrect,
    this.correctKey,
  });

  final String id;
  final String prompt;
  final List<QuizOption> options;
  final int seconds;

  /// Seconds left on the server's clock when the state was read.
  final int timeLeft;
  final String? myAnswer;
  final int? myPoints;

  /// The fairer server's verdict on [myAnswer], once time is up.
  final bool? myCorrect;

  /// The right answer: today's server sends it once the player has
  /// answered; the fairer one only once time is up.
  final String? correctKey;

  bool get answered => myAnswer != null;
  bool get revealed => correctKey != null;

  /// Whether [myAnswer] was right: null until it can be said.
  bool? get wasRight {
    if (myAnswer == null) return null;
    if (myCorrect != null) return myCorrect;
    final key = correctKey;
    return key == null ? null : key == myAnswer;
  }

  QuizQuestion copyWith({
    String? myAnswer,
    int? Function()? myPoints,
    bool? Function()? myCorrect,
    String? Function()? correctKey,
    int? timeLeft,
  }) =>
      QuizQuestion(
        id: id,
        prompt: prompt,
        options: options,
        seconds: seconds,
        timeLeft: timeLeft ?? this.timeLeft,
        myAnswer: myAnswer ?? this.myAnswer,
        myPoints: myPoints != null ? myPoints() : this.myPoints,
        myCorrect: myCorrect != null ? myCorrect() : this.myCorrect,
        correctKey: correctKey != null ? correctKey() : this.correctKey,
      );

  static QuizQuestion? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    if (id == null) return null;
    final correct = json['my_correct'];
    return QuizQuestion(
      id: id,
      prompt: _str(json['prompt']) ?? '',
      options: [
        for (final o in (json['options'] is List ? json['options'] as List : []))
          if (o is Map && _str(o['key']) != null)
            QuizOption(key: _str(o['key'])!, label: _str(o['label']) ?? ''),
      ],
      seconds: _int(json['seconds'], 20),
      timeLeft: _int(json['time_left']).clamp(0, 3600),
      myAnswer: _str(json['my_answer']),
      myPoints: _intOrNull(json['my_points']),
      myCorrect: correct is bool ? correct : null,
      correctKey: _str(json['correct_key']),
    );
  }
}

/// A row of the leaderboard.
class BoardEntry {
  const BoardEntry({required this.rank, required this.name, this.score = 0});
  final int rank;
  final String name;
  final int score;
}

/// The player's view of the quiz.
class QuizState {
  const QuizState({
    required this.status,
    this.title = '',
    this.name = '',
    this.score = 0,
    this.currentIndex = -1,
    this.total = 0,
    this.question,
    this.leaderboard = const [],
    this.rank,
  });

  /// `draft`, `live` or `ended`.
  final String status;
  final String title;
  final String name;
  final int score;

  /// -1 in the lobby, before the first question.
  final int currentIndex;
  final int total;
  final QuizQuestion? question;
  final List<BoardEntry> leaderboard;
  final int? rank;

  bool get ended => status == 'ended';
  bool get live => status == 'live';

  /// Joined, waiting for the host's first question.
  bool get inLobby => live && question == null && currentIndex < 0;

  /// Between questions: the last one is closed and the next not open.
  bool get betweenQuestions => live && question == null && currentIndex >= 0;

  QuizState copyWith({int? score, QuizQuestion? question}) => QuizState(
        status: status,
        title: title,
        name: name,
        score: score ?? this.score,
        currentIndex: currentIndex,
        total: total,
        question: question ?? this.question,
        leaderboard: leaderboard,
        rank: rank,
      );

  static QuizState? tryParse(Object? json) {
    if (json is! Map || _str(json['status']) == null) return null;
    return QuizState(
      status: _str(json['status'])!,
      title: _str(json['title']) ?? '',
      name: _str(json['name']) ?? '',
      score: _int(json['score']),
      currentIndex: _int(json['current_index'], -1),
      total: _int(json['total']),
      question: QuizQuestion.fromJson(json['question']),
      leaderboard: [
        for (final e
            in (json['leaderboard'] is List ? json['leaderboard'] as List : []))
          if (e is Map)
            BoardEntry(
              rank: _int(e['rank']),
              name: _str(e['name']) ?? '',
              score: _int(e['score']),
            ),
      ],
      rank: _intOrNull(json['rank']),
    );
  }
}

/// What answering came back with.
class AnswerResult {
  const AnswerResult({
    required this.score,
    this.correct,
    this.points,
    this.correctKey,
  });

  /// Null from the fairer server while the clock runs.
  final bool? correct;
  final int? points;
  final int score;
  final String? correctKey;

  /// Locked in, the verdict to come once time is up.
  bool get pending => correct == null;

  static AnswerResult fromJson(Object? json) {
    final map = json is Map ? json : const {};
    final correct = map['correct'];
    return AnswerResult(
      correct: correct is bool ? correct : null,
      points: _intOrNull(map['points']),
      score: _int(map['score']),
      correctKey: _str(map['correct_key']),
    );
  }
}
