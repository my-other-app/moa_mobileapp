import 'package:fake_async/fake_async.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/domain/live_room.dart';
import 'package:finnet/features/live/domain/live_theme.dart';
import 'package:finnet/features/live/presentation/cubits/live_room_cubit.dart';
import 'package:finnet/features/live/presentation/cubits/quiz_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

void main() {
  late FakeLiveRoomApi api;
  late LiveIdentity identity;

  setUp(() {
    api = FakeLiveRoomApi();
    identity = LiveIdentity(MemoryLiveStore());
  });

  QuizCubit cubitFor({LiveThemeState? theme}) => QuizCubit(
      api: api,
      identity: identity,
      eventId: 7,
      pollEvery: const Duration(seconds: 2),
      theme: theme);

  void inQuiz(FakeAsync async, QuizCubit cubit) {
    identity.savePlayer(
        const QuizPlayer(eventId: 7, playerKey: 'k1', name: 'Asha'));
    cubit.start();
    async.flushMicrotasks();
  }

  group('answering each kind', () {
    test('a multiple answer goes as its keys, and is locked in', () {
      fakeAsync((async) {
        api.quizStates.add(v2QuizJson(question: kindQuestionJson(kind: 'multi')));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        cubit.submit(const OptionsAnswer(['a', 'c']));
        async.flushMicrotasks();
        expect((api.quizResponses.single as OptionsAnswer).keys, ['a', 'c']);
        expect(cubit.state.question!.pickedKeys, {'a', 'c'});
        expect(cubit.state.lockedIn, isTrue);
        expect(cubit.state.answersClosed, isTrue);
        cubit.dispose();
      });
    });

    test('typed and ordered answers', () {
      fakeAsync((async) {
        api.quizStates.add(v2QuizJson(
            question: kindQuestionJson(kind: 'type', options: const [])));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        cubit.submit(const TextAnswer('Sao Paulo'));
        async.flushMicrotasks();
        expect(api.quizResponses.single.toJson(), {'text': 'Sao Paulo'});
        expect(cubit.state.question!.answered, isTrue);
        cubit.dispose();
      });
      fakeAsync((async) {
        api.quizResponses.clear();
        api.quizStates
          ..clear()
          ..add(v2QuizJson(question: kindQuestionJson(kind: 'order')));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        cubit.submit(const OrderAnswer(['b', 'a', 'c', 'd']));
        async.flushMicrotasks();
        expect(api.quizResponses.single.toJson(), {
          'order': ['b', 'a', 'c', 'd']
        });
        cubit.dispose();
      });
    });

    test('an answer kept through a read from before it landed, any kind', () {
      fakeAsync((async) {
        api.quizStates.add(v2QuizJson(question: kindQuestionJson(kind: 'multi')));
        api.answerAnswer = (_) => Future<Object>.delayed(
            const Duration(seconds: 3),
            () => {'correct': null, 'points': null, 'score': 0, 'answered': true});
        final cubit = cubitFor();
        inQuiz(async, cubit);
        cubit.submit(const OptionsAnswer(['b']));
        async.elapse(const Duration(seconds: 2)); // a read without it
        expect(cubit.state.question!.pickedKeys, {'b'});
        cubit.dispose();
      });
    });

    test('a kind this app cannot answer takes no answer', () {
      fakeAsync((async) {
        api.quizStates.add(v2QuizJson(question: kindQuestionJson(kind: 'slider')));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        expect(cubit.state.answersClosed, isTrue);
        cubit.answer('a');
        async.flushMicrotasks();
        expect(api.answers, isEmpty);
        cubit.dispose();
      });
    });
  });

  group('the host\'s controls', () {
    test('paused: the clock stands still and answers wait', () {
      fakeAsync((async) {
        api.quizStates
          ..add(v2QuizJson(
              phase: 'paused', question: kindQuestionJson(timeLeft: 9)))
          ..add(v2QuizJson(question: kindQuestionJson(timeLeft: 9)));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        expect(cubit.state.left, 9);
        expect(cubit.state.answersClosed, isTrue);
        async.elapse(const Duration(milliseconds: 1900));
        expect(cubit.state.left, 9, reason: 'stopped');
        async.elapse(const Duration(milliseconds: 200)); // resumed
        expect(cubit.state.answersClosed, isFalse);
        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.left, 8, reason: 'running again');
        cubit.dispose();
      });
    });

    test('answers out, the host to reveal: closed, nothing given away', () {
      fakeAsync((async) {
        api.quizStates.add(v2QuizJson(
            phase: 'closed',
            question: kindQuestionJson(timeLeft: 0, myAnswer: 'a')));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        expect(cubit.state.quiz!.waitingForReveal, isTrue);
        expect(cubit.state.lockedIn, isTrue);
        cubit.dispose();
      });
    });
  });

  group('the theme', () {
    final themed = {
      'custom': true,
      'theme': themeJson(display: 'bebas_neue'),
      'version': 'v1',
    };

    test('read once at the start, and again only when it changes', () {
      fakeAsync((async) {
        api.themeAnswer = themed;
        api.quizStates
          ..add(v2QuizJson(phase: 'lobby', index: -1, themeVersion: 'v1'))
          ..add(v2QuizJson(phase: 'lobby', index: -1, themeVersion: 'v1'))
          ..add(v2QuizJson(phase: 'lobby', index: -1, themeVersion: 'v2'));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        expect(api.themeReads, 1);
        expect(cubit.state.theme!.custom, isTrue);
        async.elapse(const Duration(seconds: 2));
        expect(api.themeReads, 1, reason: 'the same version');
        api.themeAnswer = {...themed, 'version': 'v2'};
        async.elapse(const Duration(seconds: 2));
        expect(api.themeReads, 2);
        expect(cubit.state.theme!.version, 'v2');
        cubit.dispose();
      });
    });

    test('handed over by the room: not read again', () {
      fakeAsync((async) {
        api.quizStates.add(v2QuizJson(phase: 'lobby', index: -1, themeVersion: 'v1'));
        final cubit = cubitFor(theme: LiveThemeState.fromJson(themed));
        inQuiz(async, cubit);
        async.elapse(const Duration(seconds: 4));
        expect(api.themeReads, 0);
        cubit.dispose();
      });
    });

    test('an older server without themes: one read that fails, no more', () {
      fakeAsync((async) {
        api.themeAnswer = apiError(404);
        api.quizStates.add(quizJson(index: -1));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        async.elapse(const Duration(seconds: 6));
        expect(api.themeReads, 1);
        expect(cubit.state.theme, isNull);
        expect(cubit.state.phase, QuizPhase.playing);
        cubit.dispose();
      });
    });
  });

  group('the next round', () {
    Object newRound() => apiError(401,
        code: 'QUIZ_NEW_ROUND',
        message: 'A new round has started.',
        errors: {'join_code': '553201', 'quiz_id': 'z1', 'title': 'Round 2'});

    test('in again by itself, under the same name', () {
      fakeAsync((async) {
        api.quizStates
          ..add(v2QuizJson(status: 'ended', phase: 'ended', rounds: 2))
          ..add(newRound())
          ..add(v2QuizJson(phase: 'lobby', index: -1, round: 1, rounds: 2));
        api.joinAnswer = (code, name) => {
              'event_id': 7,
              'quiz_id': 'z1',
              'title': 'Round 2',
              'player_id': 'p2',
              'player_key': 'k2',
              'name': name,
            };
        final cubit = cubitFor();
        inQuiz(async, cubit);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(api.joins.single, ('553201', 'Asha'));
        expect(cubit.state.phase, QuizPhase.playing);
        expect(cubit.state.player!.playerKey, 'k2');
        async.elapse(const Duration(seconds: 2));
        expect(api.playerKeys.last, 'k2');
        expect(cubit.state.quiz!.roundIndex, 1);
        QuizPlayer? kept;
        identity.player(7).then((p) => kept = p);
        async.flushMicrotasks();
        expect(kept!.playerKey, 'k2');
        cubit.dispose();
      });
    });

    test('when that does not work: the form, with the code filled in', () {
      fakeAsync((async) {
        api.quizStates
          ..add(v2QuizJson(status: 'ended', phase: 'ended', rounds: 2))
          ..add(newRound());
        api.joinAnswer = (_, __) => apiError(409,
            code: 'QUIZ_LATE',
            message: 'This quiz has started; new players can\'t join now.');
        final cubit = cubitFor();
        inQuiz(async, cubit);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(cubit.state.phase, QuizPhase.join);
        expect(cubit.state.suggestedCode, '553201');
        expect(cubit.state.joinError,
            'This quiz has started; new players can\'t join now.');
        cubit.dispose();
      });
    });

    test('a plain 401 is still "the quiz moved on"', () {
      fakeAsync((async) {
        api.quizStates
          ..add(v2QuizJson(phase: 'lobby', index: -1))
          ..add(apiError(401));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.phase, QuizPhase.gone);
        expect(api.joins, isEmpty);
        cubit.dispose();
      });
    });
  });

  group('the room\'s polls', () {
    test('a multiple choice goes as labels, shown at once', () async {
      api.rooms.add(roomJson(
          poll: v2PollJson(settings: {'max_choices': 2})));
      api.respondAnswer = (id, value) => v2PollJson(
            settings: {'max_choices': 2},
            results: {'responses': 1},
            myResponse: '0,2',
            myValues: ['AI', 'Mobile'],
          );
      final cubit = LiveRoomCubit(api: api, eventId: 7);
      await cubit.refresh();
      expect(await cubit.respondWith(const PollAnswer(values: ['AI', 'Mobile'])),
          isTrue);
      expect(api.pollAnswers.single.values, ['AI', 'Mobile']);
      expect(cubit.state.room!.poll!.mine, ['AI', 'Mobile']);
      cubit.dispose();
    });

    test('too many picks are refused here, with the reason', () async {
      api.rooms.add(roomJson(poll: v2PollJson(settings: {'max_choices': 2})));
      final cubit = LiveRoomCubit(api: api, eventId: 7);
      await cubit.refresh();
      expect(
          await cubit.respondWith(
              const PollAnswer(values: ['AI', 'Web', 'Mobile'])),
          isFalse);
      expect(cubit.state.pollError, 'Pick up to 2.');
      expect(api.pollAnswers, isEmpty);
      cubit.dispose();
    });

    test('a ranking that does not land puts the last answer back', () async {
      api.rooms.add(roomJson(
          poll: v2PollJson(kind: 'ranking', myValues: ['AI', 'Web', 'Mobile'], myResponse: '0,1,2')));
      api.respondAnswer = (_, __) => apiError(500);
      final cubit = LiveRoomCubit(api: api, eventId: 7);
      await cubit.refresh();
      expect(
          await cubit.respondWith(const PollAnswer(order: ['Mobile', 'Web', 'AI'])),
          isFalse);
      expect(cubit.state.room!.poll!.mine, ['AI', 'Web', 'Mobile']);
      expect(cubit.state.pollError, isNotNull);
      cubit.dispose();
    });

    test('the room\'s theme comes with it', () async {
      api.rooms.add({
        ...roomJson(),
        'theme': {'custom': true, 'theme': themeJson(), 'version': 'v3'},
      });
      final cubit = LiveRoomCubit(api: api, eventId: 7);
      await cubit.refresh();
      expect(cubit.state.room!.theme!.version, 'v3');
      cubit.dispose();
    });
  });
}

