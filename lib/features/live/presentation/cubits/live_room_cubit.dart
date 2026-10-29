import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/events/data/live/live_stream_client.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart'
    show readableError;
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/domain/live_room.dart';

/// The server's answer when the room takes no questions (409).
const qaClosedCode = 'QA_CLOSED';

/// The live room screen's state.
class LiveRoomState {
  const LiveRoomState({
    this.room,
    this.loading = true,
    this.loadError,
    this.notFound = false,
    this.asking = false,
    this.askNote,
    this.askError,
    this.qaRefused = false,
    this.answering = false,
    this.pollError,
    this.voting = const {},
    this.connectionLost = false,
  });

  /// The room, once read.
  final LiveRoom? room;

  /// The first read is on its way.
  final bool loading;

  /// The first read failed, with what to say; null once there is a room.
  final String? loadError;

  /// The server knows no room for this event (404).
  final bool notFound;

  final bool asking;

  /// After a question went: "Up on the board." or, when the organiser lets
  /// questions through, that it waits for them.
  final String? askNote;
  final String? askError;

  /// The server refused a question because the floor is closed: the ask box
  /// stays closed for the rest of the visit, whatever the room says.
  final bool qaRefused;

  /// A poll answer is on its way.
  final bool answering;
  final String? pollError;

  /// Questions whose vote is on its way.
  final Set<String> voting;

  /// Reads are failing while a room is already on the screen: what is
  /// shown may be behind, and the room says so rather than looking live.
  final bool connectionLost;

  /// Whether the ask box shows.
  bool get canAsk =>
      (room?.qaOpen ?? false) && !qaRefused && !(room?.isClosed ?? false);

  LiveRoomState copyWith({
    LiveRoom? room,
    bool? loading,
    String? Function()? loadError,
    bool? notFound,
    bool? asking,
    String? Function()? askNote,
    String? Function()? askError,
    bool? qaRefused,
    bool? answering,
    String? Function()? pollError,
    Set<String>? voting,
    bool? connectionLost,
  }) =>
      LiveRoomState(
        room: room ?? this.room,
        loading: loading ?? this.loading,
        loadError: loadError != null ? loadError() : this.loadError,
        notFound: notFound ?? this.notFound,
        asking: asking ?? this.asking,
        askNote: askNote != null ? askNote() : this.askNote,
        askError: askError != null ? askError() : this.askError,
        qaRefused: qaRefused ?? this.qaRefused,
        answering: answering ?? this.answering,
        pollError: pollError != null ? pollError() : this.pollError,
        voting: voting ?? this.voting,
        connectionLost: connectionLost ?? this.connectionLost,
      );
}

/// Keeps the room current and does what the people in it do: ask, vote a
/// question up, answer the poll.
///
/// The room comes from the stream while the server has one, and otherwise
/// from the poll, every [pollEvery] while the screen is in front
/// ([LiveStreamClient]); [hidden] stops it, [shown] brings it back.
/// Callback-based like the app's other cubits: the page listens through
/// [onStateChanged] and calls [dispose] when it goes.
class LiveRoomCubit {
  LiveRoomCubit({
    required this.api,
    required this.eventId,
    this.pollEvery = const Duration(seconds: 5),
  }) {
    _client = LiveStreamClient<LiveRoom>(
      open: ({lastEventId, required abort}) =>
          api.openRoomStream(eventId, lastEventId: lastEventId, abort: abort),
      poll: () => api.fetchRoom(eventId),
      parse: LiveRoom.tryParse,
      onData: _onRoom,
      // The room is the screen's whole point: streamed whenever it can be,
      // until the event is over.
      shouldStream: (room) => !room.isClosed,
      pollEvery: pollEvery,
      // A closed room changes no more; a poll a minute would be waste, so
      // it stops, and pull-to-refresh is there.
      shouldPoll: (room) => room == null || !room.isClosed,
      onPollError: _onPollError,
    );
  }

  final LiveRoomApi api;
  final int eventId;
  final Duration pollEvery;
  late final LiveStreamClient<LiveRoom> _client;

  LiveRoomState _state = const LiveRoomState();
  LiveRoomState get state => _state;
  void Function(LiveRoomState)? onStateChanged;
  bool _disposed = false;

  /// What the stream is doing (for tests).
  LiveMode get mode => _client.mode;

  void _emit(LiveRoomState next) {
    if (_disposed) return;
    _state = next;
    onStateChanged?.call(next);
  }

  void start() => _client.start();
  void shown() => _client.shown();
  void hidden() => _client.hidden();

  /// Pull-to-refresh, or "Try again".
  Future<void> refresh() async {
    if (_state.room == null) {
      _emit(_state.copyWith(loading: true, loadError: () => null));
    }
    try {
      final room = await api.fetchRoom(eventId);
      if (room != null) _onRoom(room);
    } catch (e) {
      _onPollError(e);
    }
  }

  void dispose() {
    _disposed = true;
    _client.close();
  }

  void _onRoom(LiveRoom room) {
    // Votes on their way keep their tap until the server answers.
    final voting = _state.voting;
    final previous = {
      for (final q in _state.room?.questions ?? const <LiveQuestion>[])
        q.id: q,
    };
    final questions = voting.isEmpty
        ? room.questions
        : [
            for (final q in room.questions)
              if (voting.contains(q.id) && previous[q.id] != null)
                q.withVote(
                    votes: previous[q.id]!.votes, voted: previous[q.id]!.voted)
              else
                q,
          ];
    // An answer on its way is not undone by a poll from before it.
    var poll = room.poll;
    final mine = _state.room?.poll;
    if (_state.answering &&
        poll != null &&
        mine != null &&
        mine.id == poll.id &&
        poll.myResponse == null) {
      poll = poll.withMyResponse(mine.myResponse);
    }
    _emit(_state.copyWith(
      room: room.copyWith(questions: questions, poll: () => poll),
      loading: false,
      loadError: () => null,
      notFound: false,
      connectionLost: false,
    ));
  }

  void _onPollError(Object error) {
    if (_state.room != null) {
      // What is shown stands, but the room says it may be behind.
      _emit(_state.copyWith(connectionLost: true));
      return;
    }
    final status = statusCodeOf(error);
    _emit(_state.copyWith(
      loading: false,
      notFound: status == 404,
      loadError: () => readableError(error,
          fallback: 'The live room could not load. Please try again.'),
    ));
  }

  // ─── Q&A ───────────────────────────────────────────────────────────────

  /// Asks the room. True when it went.
  Future<bool> ask(String text, {String? name}) async {
    final body = text.trim();
    if (body.length < 3 || _state.asking) return false;
    _emit(_state.copyWith(
        asking: true, askError: () => null, askNote: () => null));
    try {
      final q = await api.ask(eventId, body, authorName: name);
      final room = _state.room;
      final onBoard = !q.pending;
      _emit(_state.copyWith(
        asking: false,
        askNote: () => onBoard
            ? 'Up on the board.'
            : 'Sent — the organiser will put it up.',
        room: room != null && onBoard
            ? room.copyWith(
                questions: sortQuestions([
                ...room.questions.where((x) => x.id != q.id),
                q,
              ]))
            : room,
      ));
      return true;
    } catch (e) {
      if (statusCodeOf(e) == 409 && errorCodeOf(e) == qaClosedCode) {
        _emit(_state.copyWith(asking: false, qaRefused: true));
      } else {
        _emit(_state.copyWith(
          asking: false,
          askError: () =>
              readableError(e, fallback: 'That did not send. Try again.'),
        ));
      }
      return false;
    }
  }

  /// Votes [questionId] up, or takes the vote back. Shows at once; the
  /// server's count wins when it answers, and the tap is undone if it says
  /// no.
  Future<void> toggleVote(String questionId) async {
    final room = _state.room;
    if (room == null || _state.voting.contains(questionId)) return;
    final before = room.questions.where((q) => q.id == questionId).firstOrNull;
    if (before == null || before.answered) return;
    final flipped = before.withVote(
      votes: before.votes + (before.voted ? -1 : 1),
      voted: !before.voted,
    );
    _emit(_state.copyWith(
      voting: {..._state.voting, questionId},
      room: room.copyWith(questions: _replace(room.questions, flipped)),
    ));
    ({int votes, bool voted})? result;
    try {
      result = await api.vote(eventId, questionId);
    } catch (_) {
      // Put back: the next read sets it straight either way.
    }
    final now = _state.room;
    final voting = {..._state.voting}..remove(questionId);
    if (now == null) {
      _emit(_state.copyWith(voting: voting));
      return;
    }
    final current = now.questions.where((q) => q.id == questionId).firstOrNull;
    if (current == null) {
      _emit(_state.copyWith(voting: voting));
      return;
    }
    final settled = result == null
        ? current.withVote(votes: before.votes, voted: before.voted)
        : current.withVote(votes: result.votes, voted: result.voted);
    _emit(_state.copyWith(
      voting: voting,
      room: now.copyWith(questions: _replace(now.questions, settled)),
    ));
  }

  static List<LiveQuestion> _replace(
          List<LiveQuestion> questions, LiveQuestion q) =>
      [for (final x in questions) x.id == q.id ? q : x];

  // ─── The poll ──────────────────────────────────────────────────────────

  /// Answers the poll that is up, or changes the answer: a choice's label,
  /// a word or two, or a rating from "1" to "5". True when it went.
  Future<bool> respond(String value) async {
    final room = _state.room;
    final poll = room?.poll;
    final clean = value.trim();
    if (room == null || poll == null || _state.answering) return false;
    if (!validPollAnswer(poll, clean)) {
      _emit(_state.copyWith(
        pollError: () =>
            poll.isWords ? 'A word or two.' : 'Pick one of the answers.',
      ));
      return false;
    }
    final previous = poll.myResponse;
    _emit(_state.copyWith(
      answering: true,
      pollError: () => null,
      room: room.copyWith(poll: () => poll.withMyResponse(clean)),
    ));
    try {
      final back = await api.respond(eventId, poll.id, clean);
      final now = _state.room;
      final current = now?.poll;
      _emit(_state.copyWith(
        answering: false,
        room: now != null && current != null && current.id == poll.id
            ? now.copyWith(
                poll: () => (back ?? current).withMyResponse(
                    back?.myResponse ?? clean))
            : now,
      ));
      return true;
    } catch (e) {
      final now = _state.room;
      final current = now?.poll;
      _emit(_state.copyWith(
        answering: false,
        pollError: () =>
            readableError(e, fallback: 'That did not go through. Try again.'),
        room: now != null && current != null && current.id == poll.id
            ? now.copyWith(poll: () => current.withMyResponse(previous))
            : now,
      ));
      return false;
    }
  }
}

/// What the server takes as an answer to [poll] (it says the same in a 422).
bool validPollAnswer(LivePoll poll, String value) {
  final v = value.trim();
  if (poll.isChoice) return poll.choicesToShow.any((c) => c.label == v);
  if (poll.isRating) return const {'1', '2', '3', '4', '5'}.contains(v);
  return v.length >= 2 && v.length <= 40;
}
