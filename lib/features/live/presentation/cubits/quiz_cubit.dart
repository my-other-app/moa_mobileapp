import 'dart:async';

import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/events/data/live/live_stream_client.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart'
    show readableError;
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';

/// Where the player is.
enum QuizPhase {
  /// Looking for a player this phone already is in the quiz.
  checking,

  /// Not in the quiz: the code and a name.
  join,

  /// In the quiz.
  playing,

  /// The quiz no longer knows this player (a new run, or it was reset).
  gone,
}

class QuizViewState {
  const QuizViewState({
    this.phase = QuizPhase.checking,
    this.player,
    this.quiz,
    this.left = 0,
    this.joining = false,
    this.joinError,
    this.answering = false,
    this.answerError,
    this.flash,
    this.connectionLost = false,
  });

  final QuizPhase phase;
  final QuizPlayer? player;

  /// The player's view of the quiz, once read.
  final QuizState? quiz;

  /// Seconds left on the open question, counted down here between reads.
  final int left;
  final bool joining;
  final String? joinError;
  final bool answering;
  final String? answerError;

  /// What answering this question came back with (cleared by the next).
  final AnswerResult? flash;

  /// Reads are failing; what is shown may be behind.
  final bool connectionLost;

  QuizQuestion? get question => quiz?.question;

  /// Answered, the verdict still to come (the fairer server, while the
  /// clock runs).
  bool get lockedIn {
    final q = question;
    return q != null && q.answered && q.wasRight == null;
  }

  /// The answers can't be tapped: answered, out of time, or on the way.
  bool get answersClosed {
    final q = question;
    return q == null || q.answered || left <= 0 || answering;
  }

  QuizViewState copyWith({
    QuizPhase? phase,
    QuizPlayer? Function()? player,
    QuizState? Function()? quiz,
    int? left,
    bool? joining,
    String? Function()? joinError,
    bool? answering,
    String? Function()? answerError,
    AnswerResult? Function()? flash,
    bool? connectionLost,
  }) =>
      QuizViewState(
        phase: phase ?? this.phase,
        player: player != null ? player() : this.player,
        quiz: quiz != null ? quiz() : this.quiz,
        left: left ?? this.left,
        joining: joining ?? this.joining,
        joinError: joinError != null ? joinError() : this.joinError,
        answering: answering ?? this.answering,
        answerError: answerError != null ? answerError() : this.answerError,
        flash: flash != null ? flash() : this.flash,
        connectionLost: connectionLost ?? this.connectionLost,
      );
}

/// Joins the quiz and plays it.
///
/// The player's view comes from the quiz's stream when the server has one,
/// else from its poll every [pollEvery] while the screen is in front. The
/// open question's clock runs here between reads, from the `time_left`
/// each read brings.
///
/// An answer is locked in at once. Today's server says right or wrong
/// straight back; the fairer one says it once the clock is out, in the
/// player's view ([QuizQuestion.wasRight]).
class QuizCubit {
  QuizCubit({
    required this.api,
    required this.identity,
    required this.eventId,
    this.pollEvery = const Duration(seconds: 2),
  });

  final LiveRoomApi api;
  final LiveIdentity identity;
  final int eventId;
  final Duration pollEvery;

  LiveStreamClient<QuizState>? _client;
  Timer? _clock;
  bool _visible = true;

  QuizViewState _state = const QuizViewState();
  QuizViewState get state => _state;
  void Function(QuizViewState)? onStateChanged;
  bool _disposed = false;

  /// What the stream is doing (for tests); null before playing.
  LiveMode? get mode => _client?.mode;

  void _emit(QuizViewState next) {
    if (_disposed) return;
    _state = next;
    onStateChanged?.call(next);
  }

  /// Back in as the player this phone already is, or on to joining.
  Future<void> start() async {
    final player = await identity.player(eventId);
    if (_disposed) return;
    if (player == null) {
      _emit(_state.copyWith(phase: QuizPhase.join));
    } else {
      _play(player);
    }
  }

  /// Joins with the code on the screen. True when in.
  Future<bool> join(String code, String name) async {
    final c = code.trim(), n = name.trim();
    if (_state.joining) return false;
    if (c.length < 4 || n.isEmpty) {
      _emit(_state.copyWith(
        joinError: () => n.isEmpty
            ? 'Tell the room your name.'
            : 'Type the code on the screen.',
      ));
      return false;
    }
    _emit(_state.copyWith(joining: true, joinError: () => null));
    try {
      final player = await api.joinQuiz(c, n);
      if (_disposed) return false;
      if (player.eventId != eventId) {
        // A code for another event's quiz: in, but somewhere else.
        await identity.savePlayer(player);
        _emit(_state.copyWith(
          joining: false,
          joinError: () => 'That code is for another event\'s quiz.',
        ));
        return false;
      }
      await identity.savePlayer(player);
      _emit(_state.copyWith(joining: false));
      _play(player);
      return true;
    } catch (e) {
      _emit(_state.copyWith(
        joining: false,
        joinError: () => readableError(e,
            fallback: 'Could not join. Check the code on the screen.'),
      ));
      return false;
    }
  }

  /// Leaves this phone's player behind, to join again.
  Future<void> joinAgain() async {
    _client?.close();
    _client = null;
    _stopClock();
    await identity.forgetPlayer(eventId);
    _emit(QuizViewState(phase: QuizPhase.join, joinError: _state.joinError));
  }

  void _play(QuizPlayer player) {
    _emit(_state.copyWith(
      phase: QuizPhase.playing,
      player: () => player,
      joinError: () => null,
    ));
    _client?.close();
    final client = LiveStreamClient<QuizState>(
      open: ({lastEventId, required abort}) => api.openQuizStream(
          eventId, player.playerKey,
          lastEventId: lastEventId, abort: abort),
      poll: () => api.playState(eventId, player.playerKey),
      parse: QuizState.tryParse,
      onData: _onState,
      shouldStream: (_) => true,
      pollEvery: pollEvery,
      onPollError: _onPollError,
    );
    _client = client;
    if (!_visible) client.hidden();
    client.start();
  }

  void _onState(QuizState next) {
    final before = _state.quiz;
    final incoming = next.question;
    final mine = before?.question;
    final sameQuestion = incoming != null && mine?.id == incoming.id;
    var q = incoming;
    // An answer this phone just gave stands until the server has it.
    if (sameQuestion && incoming.myAnswer == null && mine!.myAnswer != null) {
      q = incoming.copyWith(
        myAnswer: mine.myAnswer,
        myPoints: () => mine.myPoints,
        correctKey: () => incoming.correctKey ?? mine.correctKey,
      );
    }
    final quiz = q == null ? next : next.copyWith(question: q);
    _emit(_state.copyWith(
      quiz: () => quiz,
      left: q?.timeLeft ?? 0,
      connectionLost: false,
      // A new question clears the last one's verdict and error.
      flash: sameQuestion ? null : () => null,
      answerError: sameQuestion ? null : () => null,
    ));
    // The clock again from this read: its next second is a second from now.
    _stopClock();
    _runClock();
  }

  void _onPollError(Object error) {
    final status = statusCodeOf(error);
    if (status == 401 || status == 404) {
      // The quiz has moved on without this player: a new run, or reset.
      _client?.close();
      _client = null;
      _stopClock();
      unawaited(identity.forgetPlayer(eventId));
      _emit(_state.copyWith(
        phase: QuizPhase.gone,
        player: () => null,
        quiz: () => null,
      ));
      return;
    }
    _emit(_state.copyWith(connectionLost: true));
  }

  /// Answers the open question with [optionKey].
  Future<void> answer(String optionKey) async {
    final player = _state.player;
    final quiz = _state.quiz;
    final q = quiz?.question;
    if (player == null || quiz == null || q == null || _state.answersClosed) {
      return;
    }
    _emit(_state.copyWith(
      answering: true,
      answerError: () => null,
      quiz: () => quiz.copyWith(question: q.copyWith(myAnswer: optionKey)),
    ));
    try {
      final result = await api.answer(eventId, player.playerKey, optionKey);
      final now = _state.quiz;
      final current = now?.question;
      if (now == null || current == null || current.id != q.id) {
        _emit(_state.copyWith(answering: false));
        return;
      }
      _emit(_state.copyWith(
        answering: false,
        flash: () => result,
        quiz: () => now.copyWith(
          score: result.score,
          question: current.copyWith(
            myAnswer: optionKey,
            // Today's server: right or wrong now. The fairer one: later.
            myPoints: () => result.points ?? current.myPoints,
            correctKey: () => result.correctKey ?? current.correctKey,
            myCorrect: () => result.correct ?? current.myCorrect,
          ),
        ),
      ));
    } catch (e) {
      final now = _state.quiz;
      final current = now?.question;
      final status = statusCodeOf(e);
      _emit(_state.copyWith(
        answering: false,
        answerError: () => readableError(e, fallback: 'That did not land.'),
        // "Already answered" keeps the answer; anything else lets them try.
        quiz: now != null && current != null && current.id == q.id && status != 409
            ? () => now.copyWith(
                question: QuizQuestion(
                  id: current.id,
                  prompt: current.prompt,
                  options: current.options,
                  seconds: current.seconds,
                  timeLeft: current.timeLeft,
                  correctKey: current.correctKey,
                ))
            : null,
      ));
    }
  }

  // ─── The clock ─────────────────────────────────────────────────────────

  void _runClock() {
    if (_state.left <= 0 || !_visible) {
      _stopClock();
      return;
    }
    _clock ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _state.left - 1;
      _emit(_state.copyWith(left: left < 0 ? 0 : left));
      if (left <= 0) _stopClock();
    });
  }

  void _stopClock() {
    _clock?.cancel();
    _clock = null;
  }

  /// The app went to the background: the game stops reading.
  void hidden() {
    _visible = false;
    _stopClock();
    _client?.hidden();
  }

  /// Back: a read now, and the clock from it.
  void shown() {
    _visible = true;
    _client?.shown();
    _runClock();
  }

  void dispose() {
    _disposed = true;
    _stopClock();
    _client?.close();
    _client = null;
  }
}
