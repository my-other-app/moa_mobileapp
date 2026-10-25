import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/network/sse/sse_transport.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/domain/live_room.dart';

/// An error as the app's Dio throws it: a DioException carrying the
/// ApiException the error interceptor read.
DioException apiError(int status, {String? code, String message = 'No'}) {
  final options = RequestOptions(path: '/x');
  return DioException(
    requestOptions: options,
    response: Response(requestOptions: options, statusCode: status),
    type: DioExceptionType.badResponse,
    error: ApiException(
      message: message,
      statusCode: status,
      serverMessage: message,
      errorCode: code,
      type: ApiException.typeForStatus(status),
    ),
  );
}

Map<String, dynamic> roomJson({
  int id = 7,
  String status = 'live',
  Map<String, dynamic>? banner,
  List<Map<String, dynamic>> updates = const [],
  Map<String, dynamic>? poll,
  List<Map<String, dynamic>> questions = const [],
  bool qaOpen = true,
  bool approveFirst = false,
  bool quizLive = false,
  String? quizTitle,
}) =>
    {
      'event': {'id': id, 'name': 'Hack Night', 'status': status},
      'banner': banner,
      'updates': updates,
      'poll': poll,
      'questions': questions,
      'qa': {'open': qaOpen, 'approve_first': approveFirst},
      'quiz': {'live': quizLive, 'title': quizTitle},
    };

Map<String, dynamic> questionJson(String id,
        {String text = 'What is next?',
        int votes = 0,
        bool voted = false,
        bool pinned = false,
        String status = 'approved',
        bool mine = false,
        String created = '2030-12-01T10:00:00Z'}) =>
    {
      'id': id,
      'text': text,
      'author_name': null,
      'status': status,
      'pinned': pinned,
      'votes': votes,
      'created_at': created,
      'answered_at': null,
      'voted': voted,
      'mine': mine,
    };

Map<String, dynamic> pollJson({
  String id = 'p1',
  String kind = 'choice',
  String prompt = 'Pizza or dosa?',
  List<String> options = const ['Pizza', 'Dosa'],
  int responses = 0,
  List<Map<String, dynamic>>? choices,
  List<Map<String, dynamic>>? words,
  Map<String, dynamic>? rating,
  String? myResponse,
}) =>
    {
      'id': id,
      'kind': kind,
      'prompt': prompt,
      'options': options,
      'status': 'live',
      'launched_at': '2030-12-01T10:00:00Z',
      'closed_at': null,
      'sort_order': 0,
      'results': {
        'responses': responses,
        if (choices != null) 'choices': choices,
        if (words != null) 'words': words,
        if (rating != null) 'rating': rating,
      },
      'my_response': myResponse,
    };

Map<String, dynamic> quizJson({
  String status = 'live',
  int index = 0,
  int total = 3,
  int score = 0,
  Map<String, dynamic>? question,
  List<Map<String, dynamic>> board = const [],
  int? rank,
  String name = 'Asha',
}) =>
    {
      'status': status,
      'title': 'Warm-up',
      'name': name,
      'score': score,
      'current_index': index,
      'total': total,
      'question': question,
      'leaderboard': board,
      'rank': rank,
    };

Map<String, dynamic> quizQuestionJson({
  String id = 'q1',
  int timeLeft = 15,
  String? myAnswer,
  int? myPoints,
  bool? myCorrect,
  String? correctKey,
}) =>
    {
      'id': id,
      'prompt': 'Capital of Kerala?',
      'options': [
        {'key': 'a', 'label': 'Kochi'},
        {'key': 'b', 'label': 'Thiruvananthapuram'},
        {'key': 'c', 'label': 'Kozhikode'},
        {'key': 'd', 'label': 'Thrissur'},
      ],
      'seconds': 20,
      'sort_order': 0,
      'time_left': timeLeft,
      'my_answer': myAnswer,
      'my_points': myPoints,
      if (myCorrect != null) 'my_correct': myCorrect,
      'correct_key': correctKey,
    };

SseResponse notFoundStream() => SseResponse(
      statusCode: 404,
      body: Stream<List<int>>.value(utf8.encode('{"message":"off"}')),
    );

/// The live room's calls, answered by the test.
class FakeLiveRoomApi implements LiveRoomApi {
  /// What the room reads give, in turn; the last keeps being given.
  final List<Object> rooms = [];
  int roomReads = 0;
  int roomStreams = 0;

  /// What a stream open gives; a 404 (no streams) unless set.
  SseResponse Function()? roomStream;

  final List<(String, String?)> asked = [];
  Object Function(String text)? askAnswer;

  final List<String> votes = [];
  Object Function(String id)? voteAnswer;

  final List<(String, String)> responses = [];
  Object Function(String pollId, String value)? respondAnswer;

  final List<(String, String)> joins = [];
  Object Function(String code, String name)? joinAnswer;

  final List<Object> quizStates = [];
  int quizReads = 0;
  int quizStreams = 0;
  final List<String> playerKeys = [];

  final List<String> answers = [];
  Object Function(String key)? answerAnswer;

  int? resolvedId;

  @override
  Future<int?> resolveEventId(String ref) async =>
      resolvedId ?? int.tryParse(ref);

  Object _next(List<Object> list, int read) =>
      list[read < list.length ? read : list.length - 1];

  @override
  Future<LiveRoom?> fetchRoom(int eventId) async {
    final answer = _next(rooms, roomReads++);
    if (answer is Exception || answer is Error) throw answer;
    return LiveRoom.tryParse(answer);
  }

  @override
  Future<SseResponse> openRoomStream(int eventId,
      {String? lastEventId, Future<void>? abort}) async {
    roomStreams++;
    return (roomStream ?? notFoundStream)();
  }

  @override
  Future<LiveQuestion> ask(int eventId, String text,
      {String? authorName}) async {
    asked.add((text, authorName));
    final answer = askAnswer?.call(text) ?? questionJson('new', text: text);
    if (answer is Exception) throw answer;
    return LiveQuestion.fromJson(answer)!;
  }

  @override
  Future<({int votes, bool voted})> vote(int eventId, String questionId) async {
    votes.add(questionId);
    Object answer = voteAnswer?.call(questionId) ?? (votes: 1, voted: true);
    if (answer is Future) answer = await answer;
    if (answer is Exception) throw answer;
    return answer as ({int votes, bool voted});
  }

  @override
  Future<LivePoll?> respond(int eventId, String pollId, String value) async {
    responses.add((pollId, value));
    final answer = respondAnswer?.call(pollId, value) ??
        pollJson(id: pollId, myResponse: value, responses: 1);
    if (answer is Exception) throw answer;
    return LivePoll.fromJson(answer);
  }

  @override
  Future<QuizPlayer> joinQuiz(String code, String name) async {
    joins.add((code, name));
    final answer = joinAnswer?.call(code, name) ??
        {
          'event_id': 7,
          'quiz_id': 'z1',
          'title': 'Warm-up',
          'player_id': 'pl1',
          'player_key': 'player-key-1',
          'name': name,
        };
    if (answer is Exception) throw answer;
    return QuizPlayer.fromJson(answer)!;
  }

  @override
  Future<QuizState?> playState(int eventId, String playerKey) async {
    playerKeys.add(playerKey);
    final answer = _next(quizStates, quizReads++);
    if (answer is Exception || answer is Error) throw answer;
    return QuizState.tryParse(answer);
  }

  @override
  Future<SseResponse> openQuizStream(int eventId, String playerKey,
      {String? lastEventId, Future<void>? abort}) async {
    quizStreams++;
    return notFoundStream();
  }

  @override
  Future<AnswerResult> answer(
      int eventId, String playerKey, String optionKey) async {
    answers.add(optionKey);
    Object answer = answerAnswer?.call(optionKey) ??
        {'correct': null, 'points': null, 'score': 0, 'answered': true};
    if (answer is Future) answer = await answer;
    if (answer is Exception) throw answer;
    return AnswerResult.fromJson(answer);
  }
}
