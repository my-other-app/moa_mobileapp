import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache_interceptor.dart';
import 'package:finnet/features/quests/data/quest_api.dart';
import 'package:finnet/features/quests/domain/quest.dart';
import 'package:finnet/features/quests/presentation/widgets/quest_sheets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';
import 'quest_fixtures.dart';

/// No signal: every request fails before an answer.
class NoSignal implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: const SocketException('No route to host'),
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _body(RequestOptions r) =>
    r.data is Map ? Map<String, dynamic>.from(r.data as Map) : const {};

void main() {
  group('the card', () {
    test('GET /events/{id}/quest, read as the card', () async {
      final api = useFakeApi()..on('GET', '/events/1/quest', questJson());
      final read = await QuestApi().card(1);
      expect(read.quest.enabled, isTrue);
      expect(read.quest.eventId, 1);
      expect(read.offline, isFalse);
      expect(api.sent('GET', '/events/1/quest'), hasLength(1));
    });

    test('kept on the phone: with no signal, the copy, said to be one',
        () async {
      final api = useFakeApi();
      // The app's own interceptors: nothing of theirs keeps the card.
      APIService.instance.dio.interceptors.insert(0, ApiCacheInterceptor());
      api.on('GET', '/events/1/quest', questJson(networkCount: 4));
      await QuestApi().card(1);

      APIService.instance.dio.httpClientAdapter = NoSignal();
      final read = await QuestApi().card(1);
      expect(read.offline, isTrue);
      expect(read.quest.networkTask?.count, 4);
      final saved = await QuestApi().saved(1);
      expect(saved?.networkTask?.count, 4);
    });

    test('the server down: the copy too', () async {
      // Answered in order: the card, then the server down.
      useFakeApi()
        ..on('GET', '/events/1/quest', questJson())
        ..on('GET', '/events/1/quest', {'message': 'Down'}, status: 503);
      await QuestApi().card(1);
      final read = await QuestApi().card(1);
      expect(read.offline, isTrue);
    });

    test('an event without a quest keeps nothing on the phone', () async {
      useFakeApi().on('GET', '/events/1/quest', {'enabled': false});
      final read = await QuestApi().card(1);
      expect(read.quest.enabled, isFalse);
      expect(await QuestApi().saved(1), isNull);
    });

    test('a quest switched off replaces its copy', () async {
      useFakeApi()
        ..on('GET', '/events/1/quest', questJson())
        ..on('GET', '/events/1/quest', {'enabled': false});
      await QuestApi().card(1);
      expect((await QuestApi().saved(1))?.enabled, isTrue);
      await QuestApi().card(1);
      expect((await QuestApi().saved(1))?.enabled, isFalse);
      APIService.instance.dio.httpClientAdapter = NoSignal();
      expect((await QuestApi().card(1)).quest.enabled, isFalse);
    });

    test('refused (not found): thrown, never the copy', () async {
      useFakeApi()
        ..on('GET', '/events/1/quest', questJson())
        ..on('GET', '/events/1/quest', {'message': 'No'}, status: 404);
      await QuestApi().card(1);
      await expectLater(QuestApi().card(1), throwsA(isA<ApiException>()));
    });

    test('nothing kept: no copy', () async {
      useFakeApi();
      expect(await QuestApi().saved(1), isNull);
    });
  });

  group('a code', () {
    test('sent as typed; the answer is the task and the card', () async {
      final api = useFakeApi()
        ..on('POST', '/events/1/quest/code', {
          'result': 'DONE',
          'task': taskJson('t-code2',
              kind: 'code', title: 'The closing code', done: true),
          'card': questJson(points: 30),
        });
      final outcome = await QuestApi().enterCode(1, 'cloud 24');
      expect(_body(api.sent('POST', '/events/1/quest/code').single),
          {'code': 'cloud 24'});
      expect(outcome, isA<CodeDone>());
      final done = outcome as CodeDone;
      expect(done.task?.title, 'The closing code');
      expect(done.card?.me?.points, 30);
    });

    test('already done', () async {
      useFakeApi().on('POST', '/events/1/quest/code',
          {'result': 'ALREADY_DONE', 'task': null, 'card': questJson()});
      expect(await QuestApi().enterCode(1, 'cloud24'), isA<CodeAlreadyDone>());
    });

    test('every refusal is read, with its details', () async {
      Future<CodeOutcome> refused(String code, int status,
          [Map<String, dynamic>? errors]) {
        useFakeApi().on('POST', '/events/1/quest/code',
            {'message': 'No', 'error_code': code, 'errors': errors},
            status: status);
        return QuestApi().enterCode(1, 'x y z');
      }

      final wrong = await refused('QUEST_CODE_WRONG', 404, {'left': 4});
      expect((wrong as CodeWrong).left, 4);
      final notOpen = await refused(
          'QUEST_CODE_NOT_OPEN', 409, {'opens_at': '2026-11-28T09:00:00Z'});
      expect((notOpen as CodeNotOpen).opensAt,
          DateTime.utc(2026, 11, 28, 9).toLocal());
      final locked =
          await refused('QUEST_CODE_LOCKED', 429, {'retry_after': 600});
      expect((locked as CodeLocked).retryAfter, const Duration(minutes: 10));
      expect(await refused('QUEST_CLOSED', 409), isA<CodeQuestClosed>());
      expect(
          await refused('QUEST_NOT_REGISTERED', 403), isA<CodeNotRegistered>());
      // The per-minute limit, which has no code of its own.
      expect(await refused('RATE_LIMITED', 429), isA<CodeLocked>());
      expect(await refused('SOMETHING_ELSE', 400), isA<CodeFailed>());
    });

    test('no signal: never kept to send later', () async {
      useFakeApi();
      APIService.instance.dio.httpClientAdapter = NoSignal();
      expect(await QuestApi().enterCode(1, 'cloud24'), isA<CodeNoSignal>());
    });

    test('what each outcome says', () {
      final now = DateTime(2026, 11, 28, 8);
      expect(codeOutcomeMessage(const CodeDone()), isNull);
      expect(codeOutcomeMessage(const CodeWrong(left: 3)),
          "That's not one of this quest's codes. 3 tries left this hour.");
      expect(codeOutcomeMessage(const CodeWrong(left: 1)), contains('1 try'));
      expect(codeOutcomeMessage(const CodeWrong(left: 0)),
          contains('last try for now'));
      expect(
          codeOutcomeMessage(CodeNotOpen(opensAt: DateTime(2026, 11, 28, 15)),
              now: now),
          'Right code, but it opens at 3:00 PM.');
      expect(
          codeOutcomeMessage(
              const CodeLocked(retryAfter: Duration(seconds: 90))),
          'Too many tries. Try again in 2 minutes.');
      expect(codeOutcomeMessage(const CodeNoSignal()), contains('No signal'));
    });

    test('a code is matched without spaces or case', () {
      expect(questCodeKey(' Cloud 24 '), 'cloud24');
    });
  });

  group('a size', () {
    test('POST the label; the claim back', () async {
      final api = useFakeApi()
        ..on(
            'POST', '/events/1/quest/claims/c-1/size', claimJson(variant: 'L'));
      final claim = await QuestApi().chooseSize(1, 'c-1', 'L');
      expect(_body(api.sent('POST', '/events/1/quest/claims/c-1/size').single),
          {'variant_label': 'L'});
      expect(claim.variantLabel, 'L');
    });

    test('gone: the sizes left', () async {
      useFakeApi().on(
          'POST',
          '/events/1/quest/claims/c-1/size',
          {
            'message': 'Gone',
            'error_code': 'QUEST_SIZE_GONE',
            'errors': {
              'choices': [
                {'label': 'S', 'free': 2},
              ],
            },
          },
          status: 409);
      try {
        await QuestApi().chooseSize(1, 'c-1', 'L');
        fail('should refuse');
      } catch (e) {
        expect(sizesLeftIn(e).single.label, 'S');
      }
    });
  });

  group('the leaderboard', () {
    test('the rows; off is null', () async {
      final api = useFakeApi()
        ..on('GET', '/events/1/quest/leaderboard', {
          'mode': 'points',
          'rows': [
            {'rank': 1, 'name': 'Asha K.', 'score': 120, 'me': false},
          ],
          'me': {'rank': 14, 'score': 40},
        });
      final board = await QuestApi().leaderboard(1);
      expect(board?.rows.single.name, 'Asha K.');
      expect(
          api
              .sent('GET', '/events/1/quest/leaderboard')
              .single
              .queryParameters['limit'],
          20);

      api.on('GET', '/events/2/quest/leaderboard',
          {'message': 'Off', 'error_code': 'QUEST_LEADERBOARD_OFF'},
          status: 404);
      expect(await QuestApi().leaderboard(2), isNull);
    });
  });

  test('a leaderboard of the points mode reads its mode', () {
    expect(QuestLeaderboard.fromJson({'mode': 'checkmarks'}).mode,
        QuestMode.checkmarks);
  });
}
