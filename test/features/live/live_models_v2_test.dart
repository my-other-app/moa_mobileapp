import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/domain/live_room.dart';
import 'package:finnet/features/live/presentation/cubits/live_room_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

void main() {
  group('the quiz from this release\'s server', () {
    test('the round: phase, rounds, teams, streak, the theme\'s version', () {
      final s = QuizState.tryParse(v2QuizJson(
        phase: 'revealed',
        round: 1,
        rounds: 3,
        team: {'key': 'red', 'name': 'Red Rockets', 'color': '#E11D48'},
        teams: [
          {'key': 'red', 'name': 'Red Rockets', 'color': '#E11D48', 'players': 70, 'score': 140000, 'rank': 1},
          {'key': 'blue', 'name': 'Blue', 'color': '#2563EB', 'players': 60, 'score': 90000, 'rank': 2},
        ],
        board: [
          {'rank': 1, 'name': 'Sneha', 'score': 2875, 'team': 'red'},
        ],
        streak: 3,
        themeVersion: 'a91c3f02',
        nextAt: '2030-12-01T10:01:10Z',
        question: kindQuestionJson(timeLeft: 0),
      ))!;
      expect(s.knowsPhase, isTrue);
      expect(s.phase, QuizStage.revealed);
      expect(s.revealedNow, isTrue);
      expect(s.boardNow, isTrue);
      expect(s.roundIndex, 1);
      expect(s.roundCount, 3);
      expect(s.hasRounds, isTrue);
      expect(s.moreRounds, isTrue);
      expect(s.team!.name, 'Red Rockets');
      expect(s.teams!.first.players, 70);
      expect(s.teamOf('blue')!.name, 'Blue');
      expect(s.leaderboard.single.team, 'red');
      expect(s.streak, 3);
      expect(s.tag, '7F2');
      expect(s.themeVersion, 'a91c3f02');
      expect(s.nextAt, DateTime.utc(2030, 12, 1, 10, 1, 10));
    });

    test('an older server\'s state: no phase, read as it always was', () {
      final s = QuizState.tryParse(quizJson(
          question: quizQuestionJson(myAnswer: 'b', correctKey: 'b')))!;
      expect(s.knowsPhase, isFalse);
      expect(s.boardNow, isNull);
      expect(s.revealedNow, isTrue, reason: 'the right answer is in it');
      expect(s.roundCount, 1);
      expect(s.question!.kind, QuizKind.single);
      expect(s.question!.wasRight, isTrue);
    });

    test('paused and waiting for the host', () {
      expect(QuizState.tryParse(v2QuizJson(phase: 'paused'))!.isPaused, isTrue);
      final closed = QuizState.tryParse(v2QuizJson(phase: 'closed'))!;
      expect(closed.waitingForReveal, isTrue);
      expect(closed.revealedNow, isFalse);
    });

    test('kinds, and a kind this app does not know', () {
      for (final (raw, kind) in [
        ('single', QuizKind.single),
        ('multi', QuizKind.multi),
        ('true_false', QuizKind.trueFalse),
        ('type', QuizKind.type),
        ('order', QuizKind.order),
        ('poll', QuizKind.poll),
        ('slider', QuizKind.unknown),
      ]) {
        expect(QuizQuestion.fromJson(kindQuestionJson(kind: raw))!.kind, kind,
            reason: raw);
      }
      expect(QuizQuestion.fromJson({'id': 'x'})!.kind, QuizKind.single,
          reason: 'no kind: today\'s single answer');
    });

    test('a multiple answer, partly right, once revealed', () {
      final q = QuizQuestion.fromJson(kindQuestionJson(
        kind: 'multi',
        myResponse: {'option_keys': ['a']},
        myPoints: 437,
        myCorrect: false,
        myCredit: 0.5,
        correctKeys: ['a', 'c'],
        effectivePoints: 2000,
        double: true,
      ))!;
      expect(q.answered, isTrue);
      expect(q.pickedKeys, {'a'});
      expect(q.rightKeys, {'a', 'c'});
      expect(q.revealed, isTrue);
      expect(q.wasRight, isFalse);
      expect(q.partlyRight, isTrue);
      expect(q.effectivePoints, 2000);
      expect(q.doublePoints, isTrue);
    });

    test('typed and ordered answers, and their right answers', () {
      final typed = QuizQuestion.fromJson(kindQuestionJson(
        kind: 'type',
        options: const [],
        myResponse: {'text': 'Sao Polo'},
        accepted: ['São Paulo'],
        myCorrect: true,
        myCredit: 1,
      ))!;
      expect((typed.sent as TextAnswer).text, 'Sao Polo');
      expect(typed.wasRight, isTrue);
      final ordered = QuizQuestion.fromJson(kindQuestionJson(
        kind: 'order',
        myResponse: {'order': ['a', 'c', 'b', 'd']},
        correctOrder: ['a', 'b', 'c', 'd'],
        myCredit: 0.5,
        myCorrect: false,
      ))!;
      expect((ordered.sent as OrderAnswer).keys, ['a', 'c', 'b', 'd']);
      expect(ordered.correctOrder, ['a', 'b', 'c', 'd']);
      expect(ordered.partlyRight, isTrue);
    });

    test('a poll question has no right or wrong', () {
      final q = QuizQuestion.fromJson(kindQuestionJson(
        kind: 'poll',
        myAnswer: 'b',
        myPoints: 0,
        counts: [
          {'key': 'a', 'label': '2', 'count': 3},
          {'key': 'b', 'label': '9', 'count': 5},
        ],
      ))!;
      expect(q.wasRight, isNull);
      expect(q.counts.map((c) => c.count), [3, 5]);
    });

    test('answers go in their kind\'s shape', () {
      expect(const OptionAnswer('b').toJson(), {'option_key': 'b'});
      expect(const OptionsAnswer(['a', 'c']).toJson(), {'option_keys': ['a', 'c']});
      expect(const TextAnswer('  Sao Paulo ').toJson(), {'text': 'Sao Paulo'});
      expect(const OrderAnswer(['c', 'a']).toJson(), {'order': ['c', 'a']});
      expect(QuizResponse.fromJson({'option_keys': []}), isNull);
    });

    test('a player keeps their team and tag', () {
      final p = QuizPlayer.fromJson({
        'event_id': 7,
        'player_key': 'k',
        'name': 'Sneha',
        'team': {'key': 'red', 'name': 'Red Rockets', 'color': '#E11D48'},
        'tag': '7F2',
      })!;
      final back = QuizPlayer.fromJson(p.toJson())!;
      expect(back.team!.name, 'Red Rockets');
      expect(back.tag, '7F2');
    });
  });

  group('polls from this release\'s server', () {
    test('a multiple choice with its settings and this phone\'s picks', () {
      final p = LivePoll.fromJson(v2PollJson(
        settings: {'max_choices': 2, 'show': 'percent', 'chart': 'donut', 'change_vote': false},
        results: {
          'responses': 4,
          'choices': [
            {'label': 'AI', 'count': 3, 'pct': 75},
            {'label': 'Web', 'count': 2, 'pct': 50},
            {'label': 'Mobile', 'count': 1, 'pct': 25},
          ],
        },
        myResponse: '0,1',
        myValues: ['AI', 'Web'],
      ))!;
      expect(p.isMultiple, isTrue);
      expect(p.settings.maxChoices, 2);
      expect(p.settings.showsPercent, isTrue);
      expect(p.settings.showsCount, isFalse);
      expect(p.settings.chart, 'donut');
      expect(p.settings.changeVote, isFalse);
      expect(p.mine, ['AI', 'Web']);
      expect(p.answered, isTrue);
    });

    test('a rating to 10, a ranking, open text', () {
      final rating = LivePoll.fromJson(v2PollJson(
        kind: 'rating',
        options: const [],
        settings: {'scale': 10},
        results: {
          'responses': 2,
          'rating': {
            'average': 7.5,
            'histogram': [
              for (var v = 1; v <= 10; v++)
                {'value': v, 'count': v == 7 || v == 8 ? 1 : 0, 'pct': v == 7 || v == 8 ? 50 : 0},
            ],
          },
          'scale': 10,
        },
      ))!;
      expect(rating.scale, 10);
      expect(rating.settings.style, 'numbers', reason: 'the default for 10');
      expect(rating.histogram, hasLength(10));
      expect(rating.ratingAverage, 7.5);
      final ranking = LivePoll.fromJson(v2PollJson(
        kind: 'ranking',
        results: {
          'responses': 1,
          'ranking': [
            {'label': 'Web', 'average': 1.0, 'points': 2, 'first': 1},
            {'label': 'AI', 'average': 2.0, 'points': 1, 'first': 0},
          ],
        },
        myValues: ['Web', 'AI', 'Mobile'],
      ))!;
      expect(ranking.isRanking, isTrue);
      expect(ranking.ranking.first.label, 'Web');
      expect(ranking.mine, ['Web', 'AI', 'Mobile']);
      final text = LivePoll.fromJson(v2PollJson(
        kind: 'text',
        options: const [],
        settings: {'anonymous': false},
        results: {
          'responses': 3,
          'texts': [
            {'id': 't1', 'text': 'More demos', 'name': 'Ravi', 'at': '2030-12-01T10:00:00Z'},
          ],
        },
      ))!;
      expect(text.isText, isTrue);
      expect(text.settings.anonymous, isFalse);
      expect(text.settings.moderate, isTrue);
      expect(text.texts.single.name, 'Ravi');
    });

    test('hidden results, a timer, pictures on options, a newer kind', () {
      final p = LivePoll.fromJson(v2PollJson(
        resultsHidden: true,
        closesAt: '2030-12-01T10:05:00Z',
        optionImages: [
          null,
          {'thumbnail': 'https://cdn.test/o.webp', 'medium': 'https://cdn.test/o-m.webp'},
          null,
        ],
      ))!;
      expect(p.resultsHidden, isTrue);
      expect(p.closesAt!.toUtc(), DateTime.utc(2030, 12, 1, 10, 5));
      expect(p.imageOf(1)!.small, 'https://cdn.test/o.webp');
      expect(p.imageOf(0), isNull);
      expect(p.imageOf(-1), isNull);
      expect(p.imageOf(9), isNull);
      expect(LivePoll.fromJson(v2PollJson(kind: 'slider'))!.isKnown, isFalse);
    });

    test('an older server\'s poll reads with today\'s settings', () {
      final p = LivePoll.fromJson(pollJson())!;
      expect(p.settings.maxChoices, 1);
      expect(p.settings.changeVote, isTrue);
      expect(p.settings.chart, 'bar');
      expect(p.resultsHidden, isFalse);
    });

    test('what each kind takes as an answer', () {
      final multi = LivePoll.fromJson(v2PollJson(settings: {'max_choices': 2}))!;
      expect(pollAnswerProblem(multi, const PollAnswer(values: ['AI', 'Web'])), isNull);
      expect(pollAnswerProblem(multi, const PollAnswer(values: ['AI', 'Web', 'Mobile'])),
          'Pick up to 2.');
      expect(pollAnswerProblem(multi, const PollAnswer(values: ['Cobol'])),
          'Pick one of the answers.');
      final rating = LivePoll.fromJson(
          v2PollJson(kind: 'rating', options: const [], settings: {'scale': 10}))!;
      expect(pollAnswerProblem(rating, const PollAnswer.value('10')), isNull);
      expect(pollAnswerProblem(rating, const PollAnswer.value('11')), isNotNull);
      expect(pollAnswerProblem(rating, const PollAnswer.value('07')), isNotNull);
      final ranking = LivePoll.fromJson(v2PollJson(kind: 'ranking'))!;
      expect(pollAnswerProblem(ranking, const PollAnswer(order: ['Web', 'AI', 'Mobile'])), isNull);
      expect(pollAnswerProblem(ranking, const PollAnswer(order: ['Web', 'AI'])),
          'Put every option in order.');
      final text = LivePoll.fromJson(v2PollJson(kind: 'text', options: const []))!;
      expect(pollAnswerProblem(text, const PollAnswer.value('Loved it')), isNull);
      expect(pollAnswerProblem(text, PollAnswer.value('x' * 121)), isNotNull);
      expect(pollAnswerProblem(LivePoll.fromJson(v2PollJson(kind: 'slider'))!,
          const PollAnswer.value('1')), isNotNull);
    });

    test('an answer\'s body', () {
      expect(const PollAnswer.value('Tea').toJson(), {'value': 'Tea'});
      expect(const PollAnswer(values: ['Tea', 'Juice']).toJson(),
          {'values': ['Tea', 'Juice']});
      expect(const PollAnswer(order: ['B', 'A']).toJson(), {'order': ['B', 'A']});
      expect(const PollAnswer(value: 'Hi', name: '  Asha ').toJson(),
          {'value': 'Hi', 'name': 'Asha'});
      expect(const PollAnswer(value: 'Hi', name: ' ').toJson(), {'value': 'Hi'});
    });
  });

  test('the room carries its theme; an older room has none', () {
    final room = LiveRoom.tryParse({
      ...roomJson(),
      'theme': {'custom': true, 'theme': themeJson(), 'version': 'v9'},
    })!;
    expect(room.theme!.custom, isTrue);
    expect(room.theme!.version, 'v9');
    expect(LiveRoom.tryParse(roomJson())!.theme, isNull);
  });
}
