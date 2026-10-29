import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/presentation/pages/quiz_page.dart';
import 'package:finnet/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';
import 'live_fakes.dart';

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}

void main() {
  late FakeLiveRoomApi api;
  late LiveIdentity identity;

  setUp(() {
    api = FakeLiveRoomApi();
    identity = LiveIdentity(MemoryLiveStore());
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpQuiz(WidgetTester tester, {bool signedIn = false}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveRoomApiProvider.overrideWithValue(api),
        liveIdentityProvider.overrideWithValue(identity),
        if (signedIn) ...[
          authStateProvider.overrideWith((ref) => _FakeAuth(const AuthState(
              accessToken: 'token', isInitialized: true))),
          profileRepositoryProvider
              .overrideWithValue(FakeProfileRepository()),
        ],
      ],
      child: const MaterialApp(home: QuizPage(eventRef: '7')),
    ));
    await settle(tester);
  }

  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  Future<void> alreadyIn() => identity.savePlayer(
      const QuizPlayer(eventId: 7, playerKey: 'k', name: 'Asha Menon'));

  testWidgets('joining: the name from the profile, the code typed, then in',
      (tester) async {
    api.quizStates.add(quizJson(index: -1, total: 5, name: 'Asha Menon'));
    await pumpQuiz(tester, signedIn: true);

    expect(find.text('Join the quiz'), findsWidgets);
    final name = tester.widget<TextField>(find.byKey(const ValueKey('quiz-name')));
    expect(name.controller!.text, 'Asha Menon');

    await tester.enterText(find.byKey(const ValueKey('quiz-code')), '48a2913');
    await tester.pump();
    final code = tester.widget<TextField>(find.byKey(const ValueKey('quiz-code')));
    expect(code.controller!.text, '482913', reason: 'digits only');

    await tester.tap(find.widgetWithText(FilledButton, 'Join the quiz'));
    await settle(tester);
    expect(api.joins.single, ('482913', 'Asha Menon'));
    expect(find.text('You are in, Asha Menon'), findsOneWidget);
    expect(find.text('5 questions tonight'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a wrong code is said under the form', (tester) async {
    api.joinAnswer = (_, __) =>
        apiError(404, message: 'No quiz is running with that code.');
    await pumpQuiz(tester);
    await tester.enterText(find.byKey(const ValueKey('quiz-code')), '111111');
    await tester.enterText(find.byKey(const ValueKey('quiz-name')), 'Asha');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Join the quiz'));
    await settle(tester);
    expect(find.text('No quiz is running with that code.'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the fairer server: "Answer locked in", then the verdict and '
      'the board once time is up', (tester) async {
    await alreadyIn();
    api.quizStates
      ..add(quizJson(question: quizQuestionJson(timeLeft: 2)))
      ..add(quizJson(question: quizQuestionJson(myAnswer: 'b', timeLeft: 0)))
      ..add(quizJson(
        score: 870,
        rank: 1,
        question: quizQuestionJson(
            myAnswer: 'b',
            myPoints: 870,
            myCorrect: true,
            correctKey: 'b',
            timeLeft: 0),
        board: [
          {'rank': 1, 'name': 'Asha Menon', 'score': 870},
          {'rank': 2, 'name': 'Ravi', 'score': 500},
        ],
        name: 'Asha Menon',
      ));
    await pumpQuiz(tester);

    expect(find.text('Question 1 of 3'), findsOneWidget);
    expect(find.text('Capital of Kerala?'), findsOneWidget);
    expect(find.text('2s'), findsOneWidget);
    final button = tester.getSize(find.byKey(const ValueKey('answer-b')));
    expect(button.height, greaterThanOrEqualTo(48));

    await tester.tap(find.byKey(const ValueKey('answer-b')));
    await settle(tester);
    expect(api.answers.single, 'b');
    expect(find.text('Answer locked in'), findsOneWidget);
    expect(find.bySemanticsLabel('Thiruvananthapuram, your answer'),
        findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    expect(find.text('Right — +870'), findsOneWidget);
    expect(find.text('+870'), findsOneWidget,
        reason: 'what the answer added, beside the new score');
    expect(find.text('1st right now'), findsOneWidget);
    final list = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Leaderboard'), 200,
        scrollable: list);
    expect(find.text('Leaderboard'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('today\'s server: right or wrong at once', (tester) async {
    await alreadyIn();
    api.quizStates.add(quizJson(question: quizQuestionJson(timeLeft: 15)));
    api.answerAnswer = (_) =>
        {'correct': false, 'points': 0, 'score': 0, 'correct_key': 'b'};
    await pumpQuiz(tester);
    await tester.tap(find.byKey(const ValueKey('answer-a')));
    await settle(tester);
    expect(find.text('Not that one'), findsOneWidget);
    expect(find.bySemanticsLabel('Thiruvananthapuram, the right answer'),
        findsOneWidget);
    expect(find.bySemanticsLabel('Kochi, your answer, wrong'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the end: where they came, and the board', (tester) async {
    await alreadyIn();
    api.quizStates.add(quizJson(
      status: 'ended',
      score: 900,
      rank: 2,
      name: 'Asha Menon',
      board: [
        {'rank': 1, 'name': 'Ravi', 'score': 1500},
        {'rank': 2, 'name': 'Asha Menon', 'score': 900},
      ],
    ));
    await pumpQuiz(tester);
    expect(find.text('That is the quiz'), findsOneWidget);
    expect(find.text('You came 2nd with 900 points.'), findsOneWidget);
    expect(find.bySemanticsLabel('2nd, Asha Menon, 900 points, you'),
        findsOneWidget);
    await leave(tester);
  });

  testWidgets('a quiz that moved on offers to join again', (tester) async {
    await alreadyIn();
    api.quizStates.add(apiError(401));
    await pumpQuiz(tester);
    expect(find.text('That quiz has moved on'), findsOneWidget);
    await tester.tap(find.text('Join again'));
    await settle(tester);
    expect(find.byKey(const ValueKey('quiz-code')), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a wrong answer names the right one', (tester) async {
    await alreadyIn();
    api.quizStates.add(quizJson(question: quizQuestionJson(timeLeft: 15)));
    api.answerAnswer = (_) =>
        {'correct': false, 'points': 0, 'score': 120, 'correct_key': 'b'};
    await pumpQuiz(tester);
    await tester.tap(find.byKey(const ValueKey('answer-a')));
    await settle(tester);
    expect(find.text('Not that one'), findsOneWidget);
    expect(find.text('The answer: Thiruvananthapuram'), findsOneWidget);
    expect(find.text('+0'), findsNothing, reason: 'nothing was won');
    await leave(tester);
  });

  testWidgets('answered, waiting: the verdict is promised, not guessed',
      (tester) async {
    await alreadyIn();
    api.quizStates.add(quizJson(question: quizQuestionJson(timeLeft: 15)));
    await pumpQuiz(tester);
    await tester.tap(find.byKey(const ValueKey('answer-c')));
    await settle(tester);
    expect(find.text('Answer locked in'), findsOneWidget);
    expect(find.text('You’ll see if you were right when time is up.'),
        findsOneWidget);
    expect(find.text('The answer: Thiruvananthapuram'), findsNothing);
    await leave(tester);
  });

  testWidgets('no answer and the clock out: time is up, with the answer',
      (tester) async {
    await alreadyIn();
    api.quizStates.add(quizJson(
        question: quizQuestionJson(timeLeft: 0, correctKey: 'b')));
    await pumpQuiz(tester);
    expect(find.text('Time is up'), findsOneWidget);
    expect(find.text('The answer: Thiruvananthapuram'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget, reason: 'the clock says so too');
    await leave(tester);
  });

  testWidgets('the final board keeps the player\'s own row in sight',
      (tester) async {
    await alreadyIn();
    api.quizStates.add(quizJson(
      status: 'ended',
      score: 120,
      rank: 40,
      name: 'Asha Menon',
      board: [
        for (var i = 1; i <= 10; i++)
          {'rank': i, 'name': 'Player $i', 'score': 1000 - i * 10},
      ],
    ));
    await pumpQuiz(tester);
    expect(find.text('You came 40th with 120 points.'), findsOneWidget);
    final list = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('board-me')), 200,
        scrollable: list);
    expect(find.bySemanticsLabel('40th, Asha Menon, 120 points, you'),
        findsOneWidget);
    await leave(tester);
  });

  testWidgets('the question holds at 320 points wide with the largest text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await alreadyIn();
    api.quizStates.add(quizJson(
      score: 300,
      rank: 4,
      question: quizQuestionJson(timeLeft: 12),
    ));
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveRoomApiProvider.overrideWithValue(api),
        liveIdentityProvider.overrideWithValue(identity),
      ],
      child: MediaQuery(
        data: const MediaQueryData(
            size: Size(320, 760), textScaler: TextScaler.linear(2)),
        child: const MaterialApp(home: QuizPage(eventRef: '7')),
      ),
    ));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: 'nothing clipped');
    expect(find.text('Capital of Kerala?'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('every tap target on a question is big enough and named',
      (tester) async {
    await alreadyIn();
    api.quizStates.add(quizJson(question: quizQuestionJson(timeLeft: 15)));
    await pumpQuiz(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await leave(tester);
  });
}
