import 'dart:math';

import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/domain/live_room.dart';
import 'package:finnet/features/live/presentation/cubits/live_room_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

void main() {
  group('LiveRoom', () {
    test('reads the room: updates, the poll, the board, Q&A and the quiz', () {
      final room = LiveRoom.tryParse(roomJson(
        banner: {'id': 'u2', 'kind': 'room', 'text': 'Demos in Lab 3B'},
        updates: [
          {'id': 'u2', 'kind': 'room', 'text': 'Demos in Lab 3B'},
          {'id': 'u1', 'kind': 'schedule', 'text': 'Talks start at 7'},
        ],
        poll: pollJson(
          responses: 4,
          choices: [
            {'label': 'Pizza', 'count': 3, 'pct': 75},
            {'label': 'Dosa', 'count': 1, 'pct': 25},
          ],
          myResponse: 'Pizza',
        ),
        questions: [
          questionJson('a', votes: 2, created: '2030-12-01T10:00:00Z'),
          questionJson('b', votes: 5),
          questionJson('c', votes: 0, pinned: true),
          questionJson('d', votes: 2, created: '2030-12-01T09:00:00Z'),
        ],
        approveFirst: true,
        quizLive: true,
        quizTitle: 'Warm-up',
      ))!;

      expect(room.eventId, 7);
      expect(room.eventName, 'Hack Night');
      expect(room.isEventLive, isTrue);
      expect(room.banner!.kindLabel, 'Room change');
      expect(room.earlier.single.text, 'Talks start at 7');
      expect(room.earlier.single.kindLabel, 'Schedule change');
      expect(room.poll!.choices.first.pct, 75);
      expect(room.poll!.answered, isTrue);
      // Pinned, then most votes, then oldest.
      expect(room.questions.map((q) => q.id), ['c', 'b', 'd', 'a']);
      expect(room.qaOpen, isTrue);
      expect(room.approveFirst, isTrue);
      expect(room.quizLive, isTrue);
      expect(room.isEmpty, isFalse);
    });

    test('a room with nothing in it, and a closed one', () {
      final empty = LiveRoom.tryParse(roomJson(qaOpen: false))!;
      expect(empty.isEmpty, isTrue);
      expect(empty.isClosed, isFalse);
      final closed = LiveRoom.tryParse(roomJson(status: 'closed'))!;
      expect(closed.isClosed, isTrue);
      expect(LiveRoom.tryParse('nope'), isNull);
    });

    test('a server that sends less still gives a room', () {
      final room = LiveRoom.tryParse({
        'event': {'id': '9'},
        'questions': [
          {'id': 'x'}, // no text: skipped
          {'id': 'y', 'text': 'Hello there'},
        ],
      })!;
      expect(room.eventId, 9);
      expect(room.questions.single.id, 'y');
      expect(room.qaOpen, isFalse, reason: 'no word on Q&A: closed');
    });

    test('poll kinds: words and ratings', () {
      final words = LivePoll.fromJson(pollJson(
        kind: 'words',
        options: const [],
        words: [
          {'word': 'fun', 'count': 4},
          {'word': 'loud', 'count': 1},
        ],
      ))!;
      expect(words.isWords, isTrue);
      expect(words.words.first.word, 'fun');
      final rating = LivePoll.fromJson(pollJson(
        kind: 'rating',
        options: const [],
        rating: {'average': 4.25, 'histogram': []},
      ))!;
      expect(rating.isRating, isTrue);
      expect(rating.ratingAverage, 4.25);
      // A choice poll before anyone answered draws its options.
      final fresh = LivePoll.fromJson(pollJson())!;
      expect(fresh.choicesToShow.map((c) => c.label), ['Pizza', 'Dosa']);
    });

    test('what a poll takes as an answer', () {
      final choice = LivePoll.fromJson(pollJson())!;
      expect(validPollAnswer(choice, 'Pizza'), isTrue);
      expect(validPollAnswer(choice, 'Burger'), isFalse);
      final words = LivePoll.fromJson(pollJson(kind: 'words'))!;
      expect(validPollAnswer(words, 'a'), isFalse);
      expect(validPollAnswer(words, 'so fun'), isTrue);
      expect(validPollAnswer(words, 'x' * 41), isFalse);
      final rating = LivePoll.fromJson(pollJson(kind: 'rating'))!;
      expect(validPollAnswer(rating, '5'), isTrue);
      expect(validPollAnswer(rating, '6'), isFalse);
      expect(validPollAnswer(rating, '0'), isFalse);
    });
  });

  group('the quiz, read from both servers', () {
    test('today\'s: the right answer comes with the player\'s answer', () {
      final state = QuizState.tryParse(quizJson(
        question: quizQuestionJson(
            myAnswer: 'b', myPoints: 870, correctKey: 'b', timeLeft: 9),
        rank: 2,
        score: 870,
      ))!;
      final q = state.question!;
      expect(q.answered, isTrue);
      expect(q.revealed, isTrue);
      expect(q.wasRight, isTrue);
      expect(state.rank, 2);
      final result = AnswerResult.fromJson(
          {'correct': false, 'points': 0, 'score': 870, 'correct_key': 'b'});
      expect(result.pending, isFalse);
      expect(result.correct, isFalse);
    });

    test('the fairer one: locked in while the clock runs, the verdict after',
        () {
      final running = QuizState.tryParse(quizJson(
        question: quizQuestionJson(myAnswer: 'a', timeLeft: 6),
      ))!;
      expect(running.question!.answered, isTrue);
      expect(running.question!.revealed, isFalse);
      expect(running.question!.wasRight, isNull);

      final after = QuizState.tryParse(quizJson(
        question: quizQuestionJson(
            myAnswer: 'a',
            myPoints: 0,
            myCorrect: false,
            correctKey: 'b',
            timeLeft: 0),
      ))!;
      expect(after.question!.wasRight, isFalse);

      final result = AnswerResult.fromJson(
          {'correct': null, 'points': null, 'score': 0, 'answered': true});
      expect(result.pending, isTrue);
      expect(result.correctKey, isNull);
    });

    test('lobby, between questions, ended', () {
      expect(QuizState.tryParse(quizJson(index: -1))!.inLobby, isTrue);
      expect(QuizState.tryParse(quizJson(index: 1))!.betweenQuestions, isTrue);
      expect(QuizState.tryParse(quizJson(status: 'ended'))!.ended, isTrue);
      expect(QuizState.tryParse({'title': 'x'}), isNull);
    });

    test('a player keeps', () {
      final p = QuizPlayer.fromJson({
        'event_id': 7,
        'player_key': 'k-123',
        'name': 'Asha',
        'quiz_id': 'z',
        'player_id': 'p',
        'title': 'Warm-up',
      })!;
      final back = QuizPlayer.fromJson(p.toJson())!;
      expect(back.playerKey, 'k-123');
      expect(back.eventId, 7);
      expect(back.name, 'Asha');
      expect(QuizPlayer.fromJson({'name': 'x'}), isNull);
    });
  });

  group('LiveIdentity', () {
    test('one key per install, made once and kept', () async {
      final store = MemoryLiveStore();
      final first = LiveIdentity(store, random: Random(1));
      final key = await first.installKey();
      expect(LiveIdentity.validKey(key), isTrue);
      expect(key.length, 24);
      expect(await first.installKey(), key);
      expect(store.values[LiveIdentity.installKeyName], key);

      // Another run of the app: the same key.
      final again = LiveIdentity(store, random: Random(2));
      expect(await again.installKey(), key);
    });

    test('a kept key the server would refuse is replaced', () async {
      final store = MemoryLiveStore()
        ..values[LiveIdentity.installKeyName] = 'bad key!';
      final key = await LiveIdentity(store).installKey();
      expect(LiveIdentity.validKey(key), isTrue);
      expect(key, isNot('bad key!'));
    });

    test('the quiz player is kept per event, and forgotten', () async {
      final id = LiveIdentity(MemoryLiveStore());
      expect(await id.player(7), isNull);
      await id.savePlayer(
          const QuizPlayer(eventId: 7, playerKey: 'k1', name: 'Asha'));
      expect((await id.player(7))!.playerKey, 'k1');
      expect(await id.player(8), isNull);
      await id.forgetPlayer(7);
      expect(await id.player(7), isNull);
    });

    test('storage that fails still gives a key for the run', () async {
      final key = await LiveIdentity(_BrokenStore()).installKey();
      expect(LiveIdentity.validKey(key), isTrue);
    });
  });
}

class _BrokenStore implements LiveStore {
  @override
  Future<void> delete(String key) => throw StateError('no');
  @override
  Future<String?> read(String key) => throw StateError('no');
  @override
  Future<void> write(String key, String value) => throw StateError('no');
}
