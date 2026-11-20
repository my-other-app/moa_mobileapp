import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/presentation/pages/quiz_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

void main() {
  late FakeLiveRoomApi api;
  late LiveIdentity identity;

  setUp(() {
    api = FakeLiveRoomApi();
    identity = LiveIdentity(MemoryLiveStore());
    AppImageCaches.debugOverride(public: SlowImages(), private: SlowImages());
  });
  tearDown(AppImageCaches.debugOverride);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  /// A read later: the poll's two seconds.
  Future<void> nextRead(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
  }

  Future<void> pumpQuiz(WidgetTester tester, {Size? size, double text = 1}) async {
    await identity.savePlayer(
        const QuizPlayer(eventId: 7, playerKey: 'k', name: 'Asha Menon'));
    Widget app = const MaterialApp(home: QuizPage(eventRef: '7'));
    if (size != null) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      app = MediaQuery(
        data: MediaQueryData(size: size, textScaler: TextScaler.linear(text)),
        child: app,
      );
    }
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveRoomApiProvider.overrideWithValue(api),
        liveIdentityProvider.overrideWithValue(identity),
      ],
      child: app,
    ));
    await settle(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    final list = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(finder, 200, scrollable: list);
  }

  testWidgets('true or false: two big tiles side by side, one tap',
      (tester) async {
    api.quizStates.add(v2QuizJson(
        question: kindQuestionJson(
      kind: 'true_false',
      prompt: 'Kochi is the capital of Kerala.',
      options: const [
        {'key': 'a', 'label': 'True'},
        {'key': 'b', 'label': 'False'},
      ],
    )));
    await pumpQuiz(tester);
    final t = tester.getRect(find.byKey(const ValueKey('answer-a')));
    final f = tester.getRect(find.byKey(const ValueKey('answer-b')));
    expect(t.top, f.top, reason: 'side by side');
    expect(t.height, greaterThanOrEqualTo(48));
    await tester.tap(find.byKey(const ValueKey('answer-b')));
    await settle(tester);
    expect(api.quizResponses.single.toJson(), {'option_key': 'b'});
    expect(find.text('Answer locked in'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('several answers: tick them, lock them in, then partly right',
      (tester) async {
    api.quizStates
      ..add(v2QuizJson(question: kindQuestionJson(kind: 'multi')))
      ..add(v2QuizJson(
        phase: 'revealed',
        score: 437,
        rank: 2,
        question: kindQuestionJson(
          kind: 'multi',
          timeLeft: 0,
          myResponse: {
            'option_keys': ['a', 'b']
          },
          myPoints: 437,
          myCorrect: false,
          myCredit: 0.5,
          correctKeys: ['a', 'c'],
        ),
      ));
    await pumpQuiz(tester);
    expect(find.text('Pick at least one'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('answer-a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('answer-b')));
    await tester.pump();
    expect(find.bySemanticsLabel('2, picked'), findsOneWidget);
    expect(find.text('Lock in 2 answers'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-lock-in')));
    await settle(tester);
    expect(api.quizResponses.single.toJson(), {
      'option_keys': ['a', 'b']
    });
    expect(find.text('Answer locked in'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-lock-in')), findsNothing);

    await nextRead(tester);
    expect(find.text('Partly right — +437'), findsOneWidget);
    expect(find.text('The answers: 2, 11'), findsOneWidget);
    expect(find.bySemanticsLabel('11, a right answer'), findsOneWidget);
    expect(find.bySemanticsLabel('9, picked, wrong'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('type the answer, then the accepted spellings', (tester) async {
    api.quizStates
      ..add(v2QuizJson(
          question: kindQuestionJson(
              kind: 'type',
              prompt: 'Largest city in Brazil?',
              options: const [])))
      ..add(v2QuizJson(
        phase: 'revealed',
        question: kindQuestionJson(
          kind: 'type',
          prompt: 'Largest city in Brazil?',
          options: const [],
          timeLeft: 0,
          myResponse: {'text': 'Rio'},
          myPoints: 0,
          myCorrect: false,
          myCredit: 0,
          accepted: ['São Paulo', 'Sao Paulo'],
        ),
      ));
    await pumpQuiz(tester);
    final lockIn = find.byKey(const ValueKey('quiz-lock-in'));
    expect(tester.widget<FilledButton>(lockIn).onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('quiz-type')), ' Rio ');
    await tester.pump();
    await tester.tap(lockIn);
    await settle(tester);
    expect(api.quizResponses.single.toJson(), {'text': 'Rio'});
    expect(find.byKey(const ValueKey('quiz-typed')), findsOneWidget);
    expect(find.bySemanticsLabel('Your answer: Rio'), findsOneWidget);
    await nextRead(tester);
    expect(find.text('Not that one'), findsOneWidget);
    expect(find.text('The answer: São Paulo (also: Sao Paulo)'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('put in order with the arrows, lock it, then the right places',
      (tester) async {
    api.quizStates
      ..add(v2QuizJson(question: kindQuestionJson(kind: 'order')))
      ..add(v2QuizJson(
        phase: 'revealed',
        question: kindQuestionJson(
          kind: 'order',
          timeLeft: 0,
          myResponse: {
            'order': ['b', 'a', 'c', 'd']
          },
          myPoints: 250,
          myCorrect: false,
          myCredit: 0.5,
          correctOrder: ['a', 'b', 'c', 'd'],
        ),
      ));
    await pumpQuiz(tester);
    expect(find.bySemanticsLabel('1 of 4: 2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('order-down-a')));
    await tester.pump();
    expect(find.bySemanticsLabel('1 of 4: 9'), findsOneWidget);
    expect(find.bySemanticsLabel('2 of 4: 2'), findsOneWidget);
    final up = tester.getSize(find.byKey(const ValueKey('order-up-c')));
    expect(up.width, greaterThanOrEqualTo(48));
    await scrollTo(tester, find.byKey(const ValueKey('quiz-lock-in')));
    await tester.tap(find.byKey(const ValueKey('quiz-lock-in')));
    await settle(tester);
    expect(api.quizResponses.single.toJson(), {
      'order': ['b', 'a', 'c', 'd']
    });
    expect(find.byKey(const ValueKey('order-down-a')), findsNothing,
        reason: 'locked in');
    await nextRead(tester);
    expect(find.text('Partly right — +250'), findsOneWidget);
    expect(find.text('The order: 2 → 9 → 11 → 15'), findsOneWidget);
    expect(find.bySemanticsLabel('3 of 4: 11, in the right place'),
        findsOneWidget);
    expect(find.bySemanticsLabel('1 of 4: 9, not in the right place'),
        findsOneWidget);
    await leave(tester);
  });

  testWidgets('a poll question: no points, the room\'s answers after',
      (tester) async {
    api.quizStates
      ..add(v2QuizJson(question: kindQuestionJson(kind: 'poll')))
      ..add(v2QuizJson(
        phase: 'revealed',
        question: kindQuestionJson(
          kind: 'poll',
          timeLeft: 0,
          myAnswer: 'c',
          myPoints: 0,
          counts: [
            {'key': 'a', 'label': '2', 'count': 1},
            {'key': 'c', 'label': '11', 'count': 4},
          ],
        ),
      ));
    await pumpQuiz(tester);
    await tester.tap(find.byKey(const ValueKey('answer-c')));
    await settle(tester);
    expect(find.text('A poll: no points for this one.'), findsOneWidget);
    await nextRead(tester);
    expect(find.text('Thanks for answering'), findsOneWidget);
    expect(find.bySemanticsLabel('The room said: 2, 1; 11, 4'), findsOneWidget);
    expect(find.text('Right'), findsNothing);
    await leave(tester);
  });

  testWidgets('a kind this version cannot answer says to update',
      (tester) async {
    api.quizStates.add(v2QuizJson(question: kindQuestionJson(kind: 'slider')));
    await pumpQuiz(tester);
    expect(find.byKey(const ValueKey('quiz-needs-update')), findsOneWidget);
    expect(find.byKey(const ValueKey('answer-a')), findsNothing);
    await leave(tester);
  });

  testWidgets('paused by the host: said, and nothing can be tapped',
      (tester) async {
    api.quizStates.add(v2QuizJson(phase: 'paused', question: kindQuestionJson()));
    await pumpQuiz(tester);
    expect(find.byKey(const ValueKey('quiz-paused')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('answer-a')));
    await settle(tester);
    expect(api.answers, isEmpty);
    await leave(tester);
  });

  testWidgets('the host reveals: answers in, the answer promised',
      (tester) async {
    api.quizStates.add(v2QuizJson(
        phase: 'closed',
        question: kindQuestionJson(timeLeft: 0, myAnswer: 'a')));
    await pumpQuiz(tester);
    expect(find.text('Answer locked in'), findsOneWidget);
    expect(find.text('The host will show the answer in a moment.'),
        findsOneWidget);
    await leave(tester);
  });

  testWidgets('a wrong answer that costs points says how many',
      (tester) async {
    api.quizStates.add(v2QuizJson(
      phase: 'revealed',
      question: kindQuestionJson(
          timeLeft: 0,
          myAnswer: 'b',
          myPoints: -250,
          myCorrect: false,
          myCredit: 0,
          correctKey: 'a'),
    ));
    await pumpQuiz(tester);
    expect(find.text('Not that one — −250'), findsOneWidget);
    expect(find.text('Wrong answers cost points in this quiz.'), findsOneWidget);
    expect(find.text('The answer: 2'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('double points, its worth, and a streak', (tester) async {
    api.quizStates.add(v2QuizJson(
        streak: 3,
        question: kindQuestionJson(effectivePoints: 2000, double: true)));
    await pumpQuiz(tester);
    expect(find.text('Double points'), findsOneWidget);
    expect(find.text('2000 points'), findsOneWidget);
    expect(find.text('3 in a row'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('an unchanged quiz on this server looks as it did',
      (tester) async {
    api.quizStates.add(v2QuizJson(question: kindQuestionJson()));
    await pumpQuiz(tester);
    expect(find.text('Question 1 of 5'), findsOneWidget);
    expect(find.text('1000 points'), findsNothing);
    expect(find.text('15s'), findsOneWidget, reason: 'the ring clock');
    expect(find.byKey(const ValueKey('live-logo')), findsNothing);
    expect(find.byKey(const ValueKey('live-backdrop')), findsNothing);
    await leave(tester);
  });

  testWidgets('teams: the player\'s team, and the teams\' board',
      (tester) async {
    const red = {'key': 'red', 'name': 'Red Rockets', 'color': '#E11D48'};
    api.quizStates
      ..add(v2QuizJson(phase: 'lobby', index: -1, team: red))
      ..add(v2QuizJson(
        phase: 'revealed',
        team: red,
        score: 900,
        rank: 1,
        question: kindQuestionJson(
            timeLeft: 0,
            myAnswer: 'a',
            myPoints: 900,
            myCorrect: true,
            correctKey: 'a'),
        board: [
          {'rank': 1, 'name': 'Asha Menon', 'score': 900, 'team': 'red'},
        ],
        teams: [
          {...red, 'players': 2, 'score': 1200, 'rank': 1},
          {'key': 'blue', 'name': 'Blue Jays', 'color': '#2563EB', 'players': 2, 'score': 600, 'rank': 2},
        ],
      ));
    await pumpQuiz(tester);
    expect(find.bySemanticsLabel('Your team: Red Rockets'), findsOneWidget);
    await nextRead(tester);
    await scrollTo(tester, find.byKey(const ValueKey('team-blue')));
    expect(find.text('Red Rockets · yours'), findsOneWidget);
    expect(find.bySemanticsLabel('2nd, Blue Jays, 600 points, 2 players'),
        findsOneWidget);
    await leave(tester);
  });

  testWidgets('between rounds: stay here, and the board across the rounds',
      (tester) async {
    api.quizStates.add(v2QuizJson(
      status: 'ended',
      phase: 'ended',
      rounds: 3,
      score: 900,
      rank: 2,
      name: 'Asha Menon',
      board: [
        {'rank': 1, 'name': 'Ravi', 'score': 1200},
        {'rank': 2, 'name': 'Asha Menon', 'score': 900},
      ],
      overall: [
        {'rank': 1, 'name': 'Asha Menon', 'score': 2100, 'rounds': 2},
      ],
    ));
    await pumpQuiz(tester);
    expect(find.text('That is round 1 of 3'), findsOneWidget);
    expect(find.textContaining('when the next round starts you go straight in'),
        findsOneWidget);
    await scrollTo(tester, find.text('Across all rounds'));
    expect(find.byKey(const ValueKey('quiz-overall')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the next round starts: in again without typing', (tester) async {
    api.quizStates
      ..add(v2QuizJson(status: 'ended', phase: 'ended', rounds: 2))
      ..add(apiError(401,
          code: 'QUIZ_NEW_ROUND',
          errors: {'join_code': '553201', 'quiz_id': 'z1', 'title': 'Round 2'}))
      ..add(v2QuizJson(
          phase: 'lobby', index: -1, round: 1, rounds: 2, name: 'Asha Menon'));
    api.joinAnswer = (code, name) =>
        {'event_id': 7, 'player_key': 'k2', 'name': name, 'title': 'Round 2'};
    await pumpQuiz(tester);
    expect(find.text('That is round 1 of 2'), findsOneWidget);
    await nextRead(tester);
    expect(api.joins.single, ('553201', 'Asha Menon'));
    expect(find.text('ROUND 2 OF 2'), findsOneWidget);
    expect(find.text('You are in, Asha Menon'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the event\'s look: letters, a bar clock, a grid, the logo, '
      'the display font and a gradient page', (tester) async {
    api.themeAnswer = {
      'custom': true,
      'version': 'v1',
      'theme': themeJson(
        display: 'bebas_neue',
        style: 'letters',
        timer: 'bar',
        logo: mediaJson(),
        bg: {
          'kind': 'gradient',
          'gradient': {'from': '#101820', 'to': '#29335C', 'angle': 135},
          'image': null,
          'dim': 0.45
        },
        guest: {
          'text_scale': 1.0,
          'logo': true,
          'background': 'theme',
          'answer_layout': 'grid'
        },
      ),
    };
    api.quizStates.add(v2QuizJson(question: kindQuestionJson(), themeVersion: 'v1'));
    await pumpQuiz(tester);
    expect(find.byKey(const ValueKey('live-logo')), findsOneWidget);
    expect(find.byKey(const ValueKey('live-backdrop')), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('D'), findsOneWidget);
    expect(find.bySemanticsLabel('B, 9'), findsOneWidget);
    final a = tester.getRect(find.byKey(const ValueKey('answer-a')));
    final b = tester.getRect(find.byKey(const ValueKey('answer-b')));
    expect(a.top, b.top, reason: 'a grid');
    expect(find.byType(LinearProgressIndicator), findsOneWidget,
        reason: 'the bar clock');
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final prompt = tester.widget<Text>(find.text('Which of these are prime?'));
    expect(prompt.style!.fontFamily, 'BebasNeue');
    await leave(tester);
  });

  testWidgets('a hidden clock is not drawn; the time still runs out',
      (tester) async {
    api.themeAnswer = {
      'custom': true,
      'version': 'v1',
      'theme': themeJson(timer: 'hidden'),
    };
    api.quizStates.add(v2QuizJson(question: kindQuestionJson(timeLeft: 1)));
    await pumpQuiz(tester);
    expect(find.byKey(const ValueKey('quiz-clock')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text('Time is up'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('several answers and an order hold at 320 points wide with '
      'the largest text', (tester) async {
    api.quizStates.add(v2QuizJson(
        question: kindQuestionJson(
      kind: 'order',
      options: const [
        {'key': 'a', 'label': 'The opening keynote on the main stage'},
        {'key': 'b', 'label': 'Lunch'},
        {'key': 'c', 'label': 'Workshops in the labs upstairs'},
      ],
    )));
    await pumpQuiz(tester, size: const Size(320, 760), text: 2);
    expect(tester.takeException(), isNull, reason: 'nothing clipped');
    await leave(tester);
  });

  testWidgets('every tap target on the new kinds is big enough and named',
      (tester) async {
    api.quizStates.add(v2QuizJson(question: kindQuestionJson(kind: 'multi')));
    await pumpQuiz(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await leave(tester);
    api.quizStates
      ..clear()
      ..add(v2QuizJson(question: kindQuestionJson(kind: 'order')));
    await pumpQuiz(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await leave(tester);
  });
}
