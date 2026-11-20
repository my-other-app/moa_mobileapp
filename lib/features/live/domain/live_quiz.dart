/// The quiz as a player sees it: joining with the code on the screen, the
/// player's view (`GET /events/{id}/live/quiz/play`, polled or streamed),
/// and an answer.
///
/// Three servers are read alike. The first tells a player the right answer
/// as soon as they answer (`correct_key` in the answer and in the state).
/// The fairer one keeps it until the clock runs out: an answer comes back as
/// `{correct: null, points: null, answered: true}`, and the state shows
/// `correct_key` and the player's `my_correct` once time is up. This
/// release's (asked for with `X-Live-Version: 2`) adds question kinds, the
/// round's phase, rounds, teams and the theme's version (CONTRACT 5.5); a
/// server without them gives a state that reads exactly as before.
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

List<String>? _strings(Object? v) => v is List
    ? [
        for (final e in v)
          if (_str(e) != null) _str(e)!,
      ]
    : null;

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v) : null;

// ─── Question kinds ─────────────────────────────────────────────────────

/// What a question asks for (CONTRACT 3.2). A kind this app does not know
/// (a newer server's) is [unknown]: shown with a line asking to update.
enum QuizKind {
  single,
  multi,
  trueFalse,
  type,
  order,
  poll,
  unknown;

  static QuizKind parse(Object? v) => switch (_str(v)) {
        null || 'single' => QuizKind.single,
        'multi' => QuizKind.multi,
        'true_false' => QuizKind.trueFalse,
        'type' => QuizKind.type,
        'order' => QuizKind.order,
        'poll' => QuizKind.poll,
        _ => QuizKind.unknown,
      };

  /// Answered with one tap of an option.
  bool get oneTap =>
      this == QuizKind.single ||
      this == QuizKind.trueFalse ||
      this == QuizKind.poll;
}

/// An answer as it is sent, one shape per kind (CONTRACT 5.3).
sealed class QuizResponse {
  const QuizResponse();

  Map<String, dynamic> toJson();

  /// The answer as the server gives it back in `my_response`.
  static QuizResponse? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = _str(json['option_key']);
    if (key != null) return OptionAnswer(key);
    final keys = _strings(json['option_keys']);
    if (keys != null && keys.isNotEmpty) return OptionsAnswer(keys);
    final text = _str(json['text']);
    if (text != null) return TextAnswer(text);
    final order = _strings(json['order']);
    if (order != null && order.isNotEmpty) return OrderAnswer(order);
    return null;
  }
}

/// One option: single answer, true/false, a poll question.
class OptionAnswer extends QuizResponse {
  const OptionAnswer(this.key);
  final String key;
  @override
  Map<String, dynamic> toJson() => {'option_key': key};
}

/// Several options: a multiple-answer question.
class OptionsAnswer extends QuizResponse {
  const OptionsAnswer(this.keys);
  final List<String> keys;
  @override
  Map<String, dynamic> toJson() => {'option_keys': keys};
}

/// Typed: a type-the-answer question.
class TextAnswer extends QuizResponse {
  const TextAnswer(this.text);
  final String text;
  @override
  Map<String, dynamic> toJson() => {'text': text.trim()};
}

/// Every option once, in the player's order: a put-in-order question.
class OrderAnswer extends QuizResponse {
  const OrderAnswer(this.keys);
  final List<String> keys;
  @override
  Map<String, dynamic> toJson() => {'order': keys};
}

/// The longest a typed answer may be (CONTRACT 10).
const quizTextMax = 120;

// ─── Players and teams ──────────────────────────────────────────────────

/// A team of a round played in teams.
class QuizTeam {
  const QuizTeam({required this.key, required this.name, this.color});
  final String key;
  final String name;

  /// `#RRGGBB`, the team's colour.
  final String? color;

  static QuizTeam? fromJson(Object? json) {
    if (json is! Map) return null;
    final key = _str(json['key']);
    if (key == null) return null;
    return QuizTeam(
      key: key,
      name: _str(json['name']) ?? key,
      color: _str(json['color']),
    );
  }

  Map<String, dynamic> toJson() =>
      {'key': key, 'name': name, if (color != null) 'color': color};
}

/// A team on the teams' board.
class TeamStanding {
  const TeamStanding({
    required this.team,
    this.players = 0,
    this.score = 0,
    this.rank = 0,
  });
  final QuizTeam team;
  final int players;
  final int score;
  final int rank;

  static TeamStanding? fromJson(Object? json) {
    final team = QuizTeam.fromJson(json);
    if (team == null || json is! Map) return null;
    return TeamStanding(
      team: team,
      players: _int(json['players']),
      score: _int(json['score']),
      rank: _int(json['rank']),
    );
  }
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
    this.team,
    this.tag,
  });

  final int eventId;

  /// Sent as `X-Live-Player` on every call of the game.
  final String playerKey;
  final String name;
  final String? quizId;
  final String? playerId;
  final String? title;

  /// The player's team, in a round played in teams.
  final QuizTeam? team;

  /// Three letters that stand for the player on an anonymous big screen.
  final String? tag;

  Map<String, dynamic> toJson() => {
        'event_id': eventId,
        'player_key': playerKey,
        'name': name,
        if (quizId != null) 'quiz_id': quizId,
        if (playerId != null) 'player_id': playerId,
        if (title != null) 'title': title,
        if (team != null) 'team': team!.toJson(),
        if (tag != null) 'tag': tag,
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
      team: QuizTeam.fromJson(json['team']),
      tag: _str(json['tag']),
    );
  }
}

// ─── The question ───────────────────────────────────────────────────────

/// One answer on the screen.
class QuizOption {
  const QuizOption({required this.key, required this.label});
  final String key;
  final String label;
}

/// How many picked an option, once the tally is shown.
class QuizCount {
  const QuizCount({required this.key, this.label = '', this.count = 0});
  final String key;
  final String label;
  final int count;
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
    this.kind = QuizKind.single,
    this.rawKind,
    this.effectivePoints,
    this.doublePoints = false,
    this.myResponse,
    this.myCredit,
    this.correctKeys,
    this.accepted,
    this.correctOrder,
    this.counts = const [],
  });

  final String id;
  final String prompt;

  /// For an `order` question, shuffled: the same order on every phone and
  /// the big screen, never the answer.
  final List<QuizOption> options;
  final int seconds;

  /// Seconds left on the server's clock when the state was read.
  final int timeLeft;

  /// The key answered, for a one-tap kind (null for the others).
  final String? myAnswer;
  final int? myPoints;

  /// The fairer server's verdict on the answer, once time is up.
  final bool? myCorrect;

  /// The right answer: today's server sends it once the player has
  /// answered; the fairer one only once time is up. Null for the kinds
  /// with no one right key.
  final String? correctKey;

  final QuizKind kind;

  /// The kind as the server named it (for a kind this app does not know).
  final String? rawKind;

  /// What a fully right answer is worth (this release's server).
  final int? effectivePoints;

  /// Double points.
  final bool doublePoints;

  /// The answer as it was sent, whatever its kind.
  final QuizResponse? myResponse;

  /// The share of the points the answer earned, 0 to 1, once revealed.
  final double? myCredit;

  /// Once revealed: a multiple-answer question's right keys, a typed
  /// question's accepted answers, the right order of a put-in-order one.
  final List<String>? correctKeys;
  final List<String>? accepted;
  final List<String>? correctOrder;

  /// A poll question's tally, when the server sends it.
  final List<QuizCount> counts;

  bool get answered => myAnswer != null || myResponse != null;

  bool get revealed =>
      correctKey != null ||
      correctKeys != null ||
      accepted != null ||
      correctOrder != null ||
      myCredit != null;

  /// What was sent, whatever the kind: the response, or the one key.
  QuizResponse? get sent =>
      myResponse ?? (myAnswer != null ? OptionAnswer(myAnswer!) : null);

  /// The keys this phone picked: the one key, or a multiple answer's.
  Set<String> get pickedKeys => switch (sent) {
        OptionAnswer(:final key) => {key},
        OptionsAnswer(:final keys) => keys.toSet(),
        _ => const {},
      };

  /// The right keys, once revealed: the one key, or a multiple answer's.
  Set<String> get rightKeys =>
      correctKeys?.toSet() ?? (correctKey != null ? {correctKey!} : const {});

  /// Whether the answer was right: null until it can be said. A partly
  /// right answer is not right ([partlyRight]).
  bool? get wasRight {
    if (!answered || kind == QuizKind.poll) return null;
    if (myCorrect != null) return myCorrect;
    final key = correctKey;
    if (key != null && myAnswer != null) return key == myAnswer;
    final credit = myCredit;
    return credit == null ? null : credit >= 1;
  }

  /// Some of the points, not all.
  bool get partlyRight {
    final c = myCredit;
    return wasRight == false && c != null && c > 0 && c < 1;
  }

  /// The label of an option.
  String labelOf(String key) =>
      options.where((o) => o.key == key).firstOrNull?.label ?? key;

  QuizQuestion copyWith({
    String? myAnswer,
    int? Function()? myPoints,
    bool? Function()? myCorrect,
    String? Function()? correctKey,
    QuizResponse? Function()? myResponse,
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
        kind: kind,
        rawKind: rawKind,
        effectivePoints: effectivePoints,
        doublePoints: doublePoints,
        myResponse: myResponse != null ? myResponse() : this.myResponse,
        myCredit: myCredit,
        correctKeys: correctKeys,
        accepted: accepted,
        correctOrder: correctOrder,
        counts: counts,
      );

  /// The question with no answer from this phone: an answer that did not
  /// land, to be tried again.
  QuizQuestion withoutAnswer() => QuizQuestion(
        id: id,
        prompt: prompt,
        options: options,
        seconds: seconds,
        timeLeft: timeLeft,
        correctKey: correctKey,
        kind: kind,
        rawKind: rawKind,
        effectivePoints: effectivePoints,
        doublePoints: doublePoints,
        counts: counts,
      );

  static QuizQuestion? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = _str(json['id']);
    if (id == null) return null;
    final correct = json['my_correct'];
    final credit = json['my_credit'];
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
      kind: QuizKind.parse(json['kind']),
      rawKind: _str(json['kind']),
      effectivePoints: _intOrNull(json['effective_points']),
      doublePoints: json['double'] == true,
      myResponse: QuizResponse.fromJson(json['my_response']),
      myCredit: credit is num ? credit.toDouble().clamp(0.0, 1.0) : null,
      correctKeys: _strings(json['correct_keys']),
      accepted: _strings(json['accepted']),
      correctOrder: _strings(json['correct_order']),
      counts: [
        for (final c in (json['counts'] is List ? json['counts'] as List : []))
          if (c is Map && _str(c['key']) != null)
            QuizCount(
              key: _str(c['key'])!,
              label: _str(c['label']) ?? '',
              count: _int(c['count']),
            ),
      ],
    );
  }
}

// ─── The board ──────────────────────────────────────────────────────────

/// A row of the leaderboard.
class BoardEntry {
  const BoardEntry({
    required this.rank,
    required this.name,
    this.score = 0,
    this.team,
    this.rounds,
  });
  final int rank;
  final String name;
  final int score;

  /// The player's team's key, in a round played in teams.
  final String? team;

  /// Rounds played, on the board across rounds.
  final int? rounds;

  static List<BoardEntry> listOf(Object? v) => [
        for (final e in (v is List ? v : const []))
          if (e is Map)
            BoardEntry(
              rank: _int(e['rank']),
              name: _str(e['name']) ?? '',
              score: _int(e['score']),
              team: _str(e['team']),
              rounds: _intOrNull(e['rounds']),
            ),
      ];
}

/// Where the round is (CONTRACT 5.4). A server from before this release
/// says none of it: [QuizState.phase] is then [unknown] and the page reads
/// the state as it always did.
enum QuizStage {
  draft,
  lobby,
  question,
  paused,
  closed,
  revealed,
  ended,
  unknown;

  static QuizStage parse(Object? v) => switch (_str(v)) {
        'draft' => QuizStage.draft,
        'lobby' => QuizStage.lobby,
        'question' => QuizStage.question,
        'paused' => QuizStage.paused,
        'closed' => QuizStage.closed,
        'revealed' => QuizStage.revealed,
        'ended' => QuizStage.ended,
        _ => QuizStage.unknown,
      };
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
    this.quizId,
    this.roundIndex = 0,
    this.roundCount = 1,
    this.phase = QuizStage.unknown,
    this.paused = false,
    this.boardNow,
    this.nextAt,
    this.team,
    this.teams,
    this.tag,
    this.streak = 0,
    this.themeVersion,
    this.overall,
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

  final String? quizId;

  /// This round's place among the event's rounds (0 first) and how many.
  final int roundIndex;
  final int roundCount;
  final QuizStage phase;
  final bool paused;

  /// Whether the board is to be shown now; null from a server that does
  /// not say (the board then shows once a question's clock is out).
  final bool? boardNow;

  /// When an auto-advancing round opens its next question.
  final DateTime? nextAt;
  final QuizTeam? team;

  /// The teams' board, while the board is shown.
  final List<TeamStanding>? teams;
  final String? tag;

  /// Fully right answers in a row.
  final int streak;

  /// Changes whenever the event's theme does: read it again then.
  final String? themeVersion;

  /// The board across the event's rounds, when the server sends it.
  final List<BoardEntry>? overall;

  bool get ended => status == 'ended';
  bool get live => status == 'live';

  /// This release's server: the state says its phase.
  bool get knowsPhase => phase != QuizStage.unknown;

  /// Joined, waiting for the host's first question.
  bool get inLobby => live && question == null && currentIndex < 0;

  /// Between questions: the last one is closed and the next not open.
  bool get betweenQuestions => live && question == null && currentIndex >= 0;

  /// The event has several rounds.
  bool get hasRounds => roundCount >= 2;

  /// Another round comes after this one.
  bool get moreRounds => roundIndex + 1 < roundCount;

  /// The open question's answer, points and verdict may be shown: this
  /// release's phase says so, else (an older server) the question carries
  /// a right answer.
  bool get revealedNow => knowsPhase
      ? phase == QuizStage.revealed || phase == QuizStage.ended
      : question?.revealed ?? false;

  /// The answers are in but not shown yet: the host reveals them.
  bool get waitingForReveal => phase == QuizStage.closed;

  /// The host has stopped the clock.
  bool get isPaused => paused || phase == QuizStage.paused;

  /// A team on the board or the player's own, by key.
  QuizTeam? teamOf(String? key) {
    if (key == null) return null;
    if (team?.key == key) return team;
    return teams?.where((t) => t.team.key == key).firstOrNull?.team;
  }

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
        quizId: quizId,
        roundIndex: roundIndex,
        roundCount: roundCount,
        phase: phase,
        paused: paused,
        boardNow: boardNow,
        nextAt: nextAt,
        team: team,
        teams: teams,
        tag: tag,
        streak: streak,
        themeVersion: themeVersion,
        overall: overall,
      );

  static QuizState? tryParse(Object? json) {
    if (json is! Map || _str(json['status']) == null) return null;
    final round = json['round'] is Map ? json['round'] as Map : const {};
    final board = json['board_now'];
    final teams = json['teams'];
    final overall = json['overall'];
    return QuizState(
      status: _str(json['status'])!,
      title: _str(json['title']) ?? '',
      name: _str(json['name']) ?? '',
      score: _int(json['score']),
      currentIndex: _int(json['current_index'], -1),
      total: _int(json['total']),
      question: QuizQuestion.fromJson(json['question']),
      leaderboard: BoardEntry.listOf(json['leaderboard']),
      rank: _intOrNull(json['rank']),
      quizId: _str(json['quiz_id']),
      roundIndex: _int(round['index']).clamp(0, 99),
      roundCount: _int(round['count'], 1).clamp(1, 99),
      phase: QuizStage.parse(json['phase']),
      paused: json['paused'] == true,
      boardNow: board is bool ? board : null,
      nextAt: _date(json['next_at']),
      team: QuizTeam.fromJson(json['team']),
      teams: teams is List
          ? [
              for (final t in teams)
                if (TeamStanding.fromJson(t) != null) TeamStanding.fromJson(t)!,
            ]
          : null,
      tag: _str(json['tag']),
      streak: _int(json['streak']),
      themeVersion: _str(json['theme_version']),
      overall: overall is List ? BoardEntry.listOf(overall) : null,
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
