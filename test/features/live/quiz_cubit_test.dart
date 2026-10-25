import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
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

  QuizCubit cubitFor() =>
      QuizCubit(api: api, identity: identity, eventId: 7);

  group('joining', () {
    test('not in the quiz yet: the code and a name', () async {
      final cubit = cubitFor();
      await cubit.start();
      expect(cubit.state.phase, QuizPhase.join);
      cubit.dispose();
    });

    test('joins, keeps the player, and plays', () {
      fakeAsync((async) {
        api.quizStates.add(quizJson(index: -1));
        final cubit = cubitFor();
        cubit.start();
        async.flushMicrotasks();
        bool? joined;
        cubit.join(' 482913 ', ' Asha ').then((v) => joined = v);
        async.flushMicrotasks();
        expect(joined, isTrue);
        expect(api.joins.single, ('482913', 'Asha'));
        expect(cubit.state.phase, QuizPhase.playing);
        expect(cubit.state.player!.playerKey, 'player-key-1');
        expect(cubit.state.quiz!.inLobby, isTrue);
        expect(api.playerKeys.first, 'player-key-1');
        QuizPlayer? kept;
        identity.player(7).then((p) => kept = p);
        async.flushMicrotasks();
        expect(kept!.playerKey, 'player-key-1');
        cubit.dispose();
      });
    });

    test('a phone already in the quiz is back in, without joining again',
        () {
      fakeAsync((async) {
        identity.savePlayer(
            const QuizPlayer(eventId: 7, playerKey: 'kept-key', name: 'Asha'));
        api.quizStates.add(quizJson(index: -1));
        final cubit = cubitFor()..start();
        async.flushMicrotasks();
        expect(cubit.state.phase, QuizPhase.playing);
        expect(api.joins, isEmpty);
        expect(api.playerKeys.single, 'kept-key');
        cubit.dispose();
      });
    });

    test('a wrong code says so, and nothing is kept', () async {
      api.joinAnswer = (_, __) => apiError(404,
          message: 'No quiz is running with that code.');
      final cubit = cubitFor();
      await cubit.start();
      expect(await cubit.join('111111', 'Asha'), isFalse);
      expect(cubit.state.phase, QuizPhase.join);
      expect(cubit.state.joinError, 'No quiz is running with that code.');
      expect(await identity.player(7), isNull);
      cubit.dispose();
    });

    test('a name and a code are needed before asking', () async {
      final cubit = cubitFor();
      await cubit.start();
      expect(await cubit.join('12', 'Asha'), isFalse);
      expect(await cubit.join('482913', '  '), isFalse);
      expect(api.joins, isEmpty);
      expect(cubit.state.joinError, isNotNull);
      cubit.dispose();
    });
  });

  group('playing', () {
    void inQuiz(FakeAsync async, QuizCubit cubit) {
      identity.savePlayer(
          const QuizPlayer(eventId: 7, playerKey: 'k', name: 'Asha'));
      cubit.start();
      async.flushMicrotasks();
    }

    test('read every 2 s while in front; nothing in the background', () {
      fakeAsync((async) {
        api.quizStates.add(quizJson(index: -1));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        expect(api.quizReads, 1);
        expect(api.quizStreams, 1, reason: 'the stream is tried first');
        async.elapse(const Duration(seconds: 10));
        expect(api.quizReads, 6);
        cubit.hidden();
        async.elapse(const Duration(minutes: 1));
        expect(api.quizReads, 6);
        cubit.shown();
        async.flushMicrotasks();
        expect(api.quizReads, 7);
        cubit.dispose();
        async.elapse(const Duration(minutes: 1));
        expect(api.quizReads, 7);
      });
    });

    test('the clock runs between reads, from the server\'s time left', () {
      fakeAsync((async) {
        api.quizStates.add(quizJson(question: quizQuestionJson(timeLeft: 15)));
        final cubit = QuizCubit(
            api: api,
            identity: identity,
            eventId: 7,
            pollEvery: const Duration(minutes: 10));
        inQuiz(async, cubit);
        expect(cubit.state.left, 15);
        async.elapse(const Duration(seconds: 3));
        expect(cubit.state.left, 12);
        async.elapse(const Duration(seconds: 20));
        expect(cubit.state.left, 0);
        expect(cubit.state.answersClosed, isTrue);
        cubit.dispose();
      });
    });

    test('today\'s server: right or wrong straight back', () {
      fakeAsync((async) {
        api.quizStates.add(quizJson(question: quizQuestionJson(timeLeft: 15)));
        api.answerAnswer = (key) => {
              'correct': true,
              'points': 870,
              'score': 870,
              'correct_key': 'b',
            };
        final cubit = cubitFor();
        inQuiz(async, cubit);
        cubit.answer('b');
        async.flushMicrotasks();
        final q = cubit.state.question!;
        expect(api.answers.single, 'b');
        expect(q.myAnswer, 'b');
        expect(q.wasRight, isTrue);
        expect(q.myPoints, 870);
        expect(cubit.state.quiz!.score, 870);
        expect(cubit.state.lockedIn, isFalse);
        expect(cubit.state.answersClosed, isTrue);
        cubit.dispose();
      });
    });

    test('the fairer server: locked in while the clock runs, right or wrong '
        'once it is out', () {
      fakeAsync((async) {
        api.quizStates
          ..add(quizJson(question: quizQuestionJson(timeLeft: 4)))
          ..add(quizJson(question: quizQuestionJson(myAnswer: 'a', timeLeft: 2)))
          ..add(quizJson(
            question: quizQuestionJson(
                myAnswer: 'a',
                myPoints: 0,
                myCorrect: false,
                correctKey: 'b',
                timeLeft: 0),
            board: [
              {'rank': 1, 'name': 'Ravi', 'score': 900},
              {'rank': 2, 'name': 'Asha', 'score': 0},
            ],
            rank: 2,
          ));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        cubit.answer('a');
        async.flushMicrotasks();
        expect(cubit.state.lockedIn, isTrue);
        expect(cubit.state.question!.wasRight, isNull);
        expect(cubit.state.question!.revealed, isFalse);

        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.lockedIn, isTrue, reason: 'still on the clock');

        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.lockedIn, isFalse);
        expect(cubit.state.question!.wasRight, isFalse);
        expect(cubit.state.question!.correctKey, 'b');
        expect(cubit.state.quiz!.leaderboard, hasLength(2));
        expect(cubit.state.quiz!.rank, 2);
        cubit.dispose();
      });
    });

    test('an answer is kept through a read from before it landed', () {
      fakeAsync((async) {
        final landed = Completer<Object>();
        api.quizStates.add(quizJson(question: quizQuestionJson(timeLeft: 15)));
        api.answerAnswer = (_) => landed.future;
        final cubit = cubitFor();
        inQuiz(async, cubit);
        cubit.answer('c');
        async.elapse(const Duration(seconds: 2)); // a read: no answer in it
        expect(cubit.state.question!.myAnswer, 'c');
        landed.complete(
            {'correct': null, 'points': null, 'score': 0, 'answered': true});
        async.flushMicrotasks();
        expect(cubit.state.lockedIn, isTrue);
        cubit.dispose();
      });
    });

    test('a refused answer lets them try again, unless already answered', () {
      fakeAsync((async) {
        api.quizStates.add(quizJson(question: quizQuestionJson(timeLeft: 15)));
        api.answerAnswer = (_) => apiError(500);
        final cubit = cubitFor();
        inQuiz(async, cubit);
        cubit.answer('a');
        async.flushMicrotasks();
        expect(cubit.state.question!.myAnswer, isNull);
        expect(cubit.state.answerError, isNotNull);

        api.answerAnswer =
            (_) => apiError(409, message: 'You already answered this one.');
        cubit.answer('a');
        async.flushMicrotasks();
        expect(cubit.state.question!.myAnswer, 'a');
        cubit.dispose();
      });
    });

    test('a new question clears the last one\'s verdict', () {
      fakeAsync((async) {
        api.quizStates
          ..add(quizJson(question: quizQuestionJson(timeLeft: 10)))
          ..add(quizJson(
              index: 1, question: quizQuestionJson(id: 'q2', timeLeft: 20)));
        api.answerAnswer = (_) =>
            {'correct': true, 'points': 900, 'score': 900, 'correct_key': 'a'};
        final cubit = cubitFor();
        inQuiz(async, cubit);
        cubit.answer('a');
        async.flushMicrotasks();
        expect(cubit.state.flash, isNotNull);
        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.question!.id, 'q2');
        expect(cubit.state.flash, isNull);
        expect(cubit.state.question!.answered, isFalse);
        expect(cubit.state.left, 20);
        cubit.dispose();
      });
    });

    test('a quiz that no longer knows the player: gone, and forgotten', () {
      fakeAsync((async) {
        api.quizStates
          ..add(quizJson(index: -1))
          ..add(apiError(401));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.phase, QuizPhase.gone);
        QuizPlayer? kept = const QuizPlayer(eventId: 0, playerKey: 'x', name: '');
        identity.player(7).then((p) => kept = p);
        async.flushMicrotasks();
        expect(kept, isNull);
        final reads = api.quizReads;
        async.elapse(const Duration(seconds: 10));
        expect(api.quizReads, reads, reason: 'no more reads');
        cubit.joinAgain();
        async.flushMicrotasks();
        expect(cubit.state.phase, QuizPhase.join);
        cubit.dispose();
      });
    });

    test('a read that fails otherwise keeps the game, and says the room was '
        'lost for a moment', () {
      fakeAsync((async) {
        api.quizStates
          ..add(quizJson(index: -1))
          ..add(apiError(503))
          ..add(quizJson(index: -1));
        final cubit = cubitFor();
        inQuiz(async, cubit);
        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.phase, QuizPhase.playing);
        expect(cubit.state.connectionLost, isTrue);
        async.elapse(const Duration(seconds: 2));
        expect(cubit.state.connectionLost, isFalse);
        cubit.dispose();
      });
    });
  });
}
