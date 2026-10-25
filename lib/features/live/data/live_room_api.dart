import 'package:dio/dio.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/sse/sse_transport.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/domain/live_room.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The headers the room reads.
const voterHeader = 'X-Live-Key';
const playerHeader = 'X-Live-Player';

/// The live room's calls, as the people in the room make them (the
/// backend's `app/api/live/router.py`, public side).
///
/// Every call goes through the app's one Dio, so a signed-in person's token
/// goes with it and the server counts their account. The install's key
/// ([LiveIdentity]) goes with every room call too, for when nobody is
/// signed in.
abstract class LiveRoomApi {
  /// The event's id for [ref], its id or its slug (a link to
  /// `/events/{slug}/live`): an id as it is, a slug through
  /// `/events/info/{slug}`. Null when it can't be found.
  Future<int?> resolveEventId(String ref);

  /// `GET /events/{id}/live`: the room, with this phone's votes, questions
  /// and poll answer marked.
  Future<LiveRoom?> fetchRoom(int eventId);

  /// `GET /events/{id}/live/stream?view=room`. Every status is returned.
  Future<SseResponse> openRoomStream(int eventId,
      {String? lastEventId, Future<void>? abort});

  /// `POST /events/{id}/live/questions`.
  Future<LiveQuestion> ask(int eventId, String text, {String? authorName});

  /// `POST /events/{id}/live/questions/{qid}/vote`: a toggle; the question's
  /// votes and whether this phone's vote is on it now.
  Future<({int votes, bool voted})> vote(int eventId, String questionId);

  /// `POST /events/{id}/live/polls/{pid}/respond`: the poll as the room sees
  /// it now, with this phone's answer.
  Future<LivePoll?> respond(int eventId, String pollId, String value);

  /// `POST /live/quiz/join` with the code on the screen, a name and the
  /// install's key as `player_key` (the same key is the same player, on a
  /// server that knows it; today's ignores it and makes a new one).
  Future<QuizPlayer> joinQuiz(String code, String name);

  /// `GET /events/{id}/live/quiz/play`.
  Future<QuizState?> playState(int eventId, String playerKey);

  /// `GET /events/{id}/live/stream?view=quiz`. Every status is returned.
  Future<SseResponse> openQuizStream(int eventId, String playerKey,
      {String? lastEventId, Future<void>? abort});

  /// `POST /events/{id}/live/quiz/answer`.
  Future<AnswerResult> answer(int eventId, String playerKey, String optionKey);
}

class DioLiveRoomApi implements LiveRoomApi {
  DioLiveRoomApi(this._dio, this._identity, {SseTransport? transport})
      : _transport = transport ?? DioSseTransport(_dio);

  final Dio _dio;
  final LiveIdentity _identity;
  final SseTransport _transport;

  String _base(int eventId) => '/events/$eventId/live';

  Future<Options> _keyed() async =>
      Options(headers: {voterHeader: await _identity.installKey()});

  Options _played(String playerKey) =>
      Options(headers: {playerHeader: playerKey});

  @override
  Future<int?> resolveEventId(String ref) async {
    final t = ref.trim();
    if (RegExp(r'^\d+$').hasMatch(t)) return int.tryParse(t);
    if (t.isEmpty) return null;
    final res = await _dio.get<dynamic>('/events/info/${Uri.encodeComponent(t)}');
    final body = res.data;
    final id = body is Map ? body['id'] : null;
    return id is num ? id.toInt() : int.tryParse('${id ?? ''}');
  }

  @override
  Future<LiveRoom?> fetchRoom(int eventId) async {
    final res = await _dio.get<dynamic>(_base(eventId), options: await _keyed());
    return LiveRoom.tryParse(res.data);
  }

  @override
  Future<SseResponse> openRoomStream(int eventId,
      {String? lastEventId, Future<void>? abort}) async {
    final key = await _identity.installKey();
    return _transport.open(
      '${_base(eventId)}/stream',
      query: const {'view': 'room'},
      headers: {
        voterHeader: key,
        if (lastEventId != null) 'Last-Event-ID': lastEventId,
      },
      abort: abort,
    );
  }

  @override
  Future<LiveQuestion> ask(int eventId, String text,
      {String? authorName}) async {
    final name = authorName?.trim() ?? '';
    final res = await _dio.post<dynamic>(
      '${_base(eventId)}/questions',
      data: {'text': text.trim(), 'author_name': name.isEmpty ? null : name},
      options: await _keyed(),
    );
    final q = LiveQuestion.fromJson(res.data);
    if (q == null) throw const FormatException('Not a question');
    return q;
  }

  @override
  Future<({int votes, bool voted})> vote(int eventId, String questionId) async {
    final res = await _dio.post<dynamic>(
      '${_base(eventId)}/questions/${Uri.encodeComponent(questionId)}/vote',
      data: const <String, dynamic>{},
      options: await _keyed(),
    );
    final body = res.data is Map ? res.data as Map : const {};
    final votes = body['votes'];
    return (
      votes: votes is num ? votes.toInt() : 0,
      voted: body['voted'] == true,
    );
  }

  @override
  Future<LivePoll?> respond(int eventId, String pollId, String value) async {
    final res = await _dio.post<dynamic>(
      '${_base(eventId)}/polls/${Uri.encodeComponent(pollId)}/respond',
      data: {'value': value},
      options: await _keyed(),
    );
    return LivePoll.fromJson(res.data);
  }

  @override
  Future<QuizPlayer> joinQuiz(String code, String name) async {
    final key = await _identity.installKey();
    final res = await _dio.post<dynamic>(
      '/live/quiz/join',
      data: {'code': code.trim(), 'name': name.trim(), 'player_key': key},
      options: Options(headers: {voterHeader: key}),
    );
    final player = QuizPlayer.fromJson(res.data);
    if (player == null) throw const FormatException('Not a player');
    return player;
  }

  @override
  Future<QuizState?> playState(int eventId, String playerKey) async {
    final res = await _dio.get<dynamic>('${_base(eventId)}/quiz/play',
        options: _played(playerKey));
    return QuizState.tryParse(res.data);
  }

  @override
  Future<SseResponse> openQuizStream(int eventId, String playerKey,
          {String? lastEventId, Future<void>? abort}) =>
      _transport.open(
        '${_base(eventId)}/stream',
        query: const {'view': 'quiz'},
        headers: {
          playerHeader: playerKey,
          if (lastEventId != null) 'Last-Event-ID': lastEventId,
        },
        abort: abort,
      );

  @override
  Future<AnswerResult> answer(
      int eventId, String playerKey, String optionKey) async {
    final res = await _dio.post<dynamic>(
      '${_base(eventId)}/quiz/answer',
      data: {'option_key': optionKey},
      options: _played(playerKey),
    );
    return AnswerResult.fromJson(res.data);
  }
}

final liveRoomApiProvider = Provider<LiveRoomApi>((ref) {
  return DioLiveRoomApi(ref.watch(dioProvider), ref.watch(liveIdentityProvider));
});
