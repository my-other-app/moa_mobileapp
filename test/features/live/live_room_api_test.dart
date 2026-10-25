import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/network/interceptors/auth_interceptor.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/events/data/datasources/live_remote_datasource.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

/// Answers by method and path; records what was sent.
class _Server implements HttpClientAdapter {
  final List<RequestOptions> sent = [];
  final Map<String, (int, Object?)> answers = {};

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    sent.add(options);
    final (status, body) = answers['${options.method} ${options.path}'] ??
        (404, {'detail': 'Not Found'});
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

/// A signed-in phone's storage: a token to send.
class _SignedIn extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => 'token-abc';
}

class _SignedOut extends SecureStorageService {
  @override
  Future<String?> getAccessToken() async => null;
}

void main() {
  late _Server server;
  late MemoryLiveStore store;

  Dio dioFor(SecureStorageService storage) {
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = server;
    dio.interceptors
        .addAll([AuthInterceptor(storage, dio), ErrorInterceptor()]);
    return dio;
  }

  setUp(() {
    server = _Server();
    store = MemoryLiveStore()
      ..values[LiveIdentity.installKeyName] = 'installkey1234567890';
  });

  test('joining sends the code, the name and the install\'s key as the '
      'player key, with the token when signed in', () async {
    server.answers['POST /live/quiz/join'] = (
      201,
      {
        'event_id': 7,
        'quiz_id': 'z1',
        'title': 'Warm-up',
        'player_id': 'p1',
        'player_key': 'server-player',
        'name': 'Asha',
      }
    );
    final api = DioLiveRoomApi(dioFor(_SignedIn()), LiveIdentity(store));
    final player = await api.joinQuiz(' 482913 ', ' Asha ');

    final sent = server.sent.single;
    expect(sent.data, {
      'code': '482913',
      'name': 'Asha',
      'player_key': 'installkey1234567890',
    });
    expect(sent.headers['Authorization'], 'Bearer token-abc');
    expect(sent.headers[voterHeader], 'installkey1234567890');
    // What the server gave back is the key the game sends.
    expect(player.playerKey, 'server-player');
    expect(player.eventId, 7);
  });

  test('a guest joins with the key alone', () async {
    server.answers['POST /live/quiz/join'] =
        (201, {'event_id': 7, 'player_key': 'k', 'name': 'Asha'});
    final api = DioLiveRoomApi(dioFor(_SignedOut()), LiveIdentity(store));
    await api.joinQuiz('482913', 'Asha');
    final sent = server.sent.single;
    expect(sent.headers.containsKey('Authorization'), isFalse);
    expect((sent.data as Map)['player_key'], 'installkey1234567890');
  });

  test('the room\'s calls carry the install key, and the token when signed '
      'in', () async {
    server.answers['GET /events/7/live'] = (200, roomJson());
    server.answers['POST /events/7/live/questions'] =
        (201, questionJson('q9', text: 'Is there pizza?', status: 'pending'));
    server.answers['POST /events/7/live/questions/q1/vote'] =
        (200, {'id': 'q1', 'votes': 3, 'voted': true});
    server.answers['POST /events/7/live/polls/p1/respond'] =
        (200, pollJson(myResponse: 'Dosa', responses: 2));
    final api = DioLiveRoomApi(dioFor(_SignedIn()), LiveIdentity(store));

    final room = await api.fetchRoom(7);
    final asked = await api.ask(7, '  Is there pizza? ', authorName: ' ');
    final vote = await api.vote(7, 'q1');
    final poll = await api.respond(7, 'p1', 'Dosa');

    expect(room!.eventId, 7);
    expect(asked.pending, isTrue);
    expect(vote, (votes: 3, voted: true));
    expect(poll!.myResponse, 'Dosa');
    for (final r in server.sent) {
      expect(r.headers[voterHeader], 'installkey1234567890', reason: r.path);
      expect(r.headers['Authorization'], 'Bearer token-abc', reason: r.path);
    }
    expect(server.sent[1].data,
        {'text': 'Is there pizza?', 'author_name': null});
    expect(server.sent[3].data, {'value': 'Dosa'});
  });

  test('the game\'s calls carry the player key', () async {
    server.answers['GET /events/7/live/quiz/play'] = (200, quizJson());
    server.answers['POST /events/7/live/quiz/answer'] =
        (200, {'correct': null, 'points': null, 'score': 0, 'answered': true});
    final api = DioLiveRoomApi(dioFor(_SignedOut()), LiveIdentity(store));

    final state = await api.playState(7, 'player-1');
    final result = await api.answer(7, 'player-1', 'b');

    expect(state!.title, 'Warm-up');
    expect(result.pending, isTrue);
    expect(server.sent.map((r) => r.headers[playerHeader]),
        ['player-1', 'player-1']);
    expect(server.sent.last.data, {'option_key': 'b'});
  });

  test('a slug is looked up; an id is not', () async {
    server.answers['GET /events/info/hack-night'] = (200, {'id': 68});
    final api = DioLiveRoomApi(dioFor(_SignedOut()), LiveIdentity(store));
    expect(await api.resolveEventId('68'), 68);
    expect(server.sent, isEmpty);
    expect(await api.resolveEventId('hack-night'), 68);
    expect(server.sent.single.path, '/events/info/hack-night');
  });

  group('the strip\'s banner view', () {
    test('is the small view when the server has it', () async {
      server.answers['GET /events/7/live/banner'] = (
        200,
        {
          'event': {'id': 7, 'status': 'live'},
          'banner': {'kind': 'room', 'text': 'Lab 3B'},
        }
      );
      final source = LiveRemoteDataSourceImpl(dioFor(_SignedOut()));
      final feed = await source.fetchBanner(7);
      expect(feed!.bannerText, 'Lab 3B');
      expect(server.sent.map((r) => r.path), ['/events/7/live/banner']);
    });

    test('is the room on today\'s server, which is then asked straight away',
        () async {
      server.answers['GET /events/7/live'] = (
        200,
        roomJson(banner: {'kind': 'room', 'text': 'Lab 3B'}),
      );
      final source = LiveRemoteDataSourceImpl(dioFor(_SignedOut()));
      expect((await source.fetchBanner(7))!.bannerText, 'Lab 3B');
      expect((await source.fetchBanner(7))!.bannerText, 'Lab 3B');
      expect(server.sent.map((r) => r.path), [
        '/events/7/live/banner',
        '/events/7/live',
        '/events/7/live',
      ]);
    });

    test('another failure is the caller\'s', () async {
      server.answers['GET /events/7/live/banner'] = (500, {'message': 'x'});
      final source = LiveRemoteDataSourceImpl(dioFor(_SignedOut()));
      await expectLater(source.fetchBanner(7), throwsA(isA<DioException>()));
      expect(server.sent, hasLength(1));
    });
  });
}
