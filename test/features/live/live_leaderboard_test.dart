import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/presentation/widgets/live_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The board as `live/board.py` hands it over: a rank, a name, a score,
/// and tied players sharing a rank.
List<BoardEntry> board(List<(int, String, int)> rows) =>
    [for (final (rank, name, score) in rows) BoardEntry(rank: rank, name: name, score: score)];

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(390, 844),
    double textScale = 1,
    bool stillMotion = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
          disableAnimations: stillMotion,
        ),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(seconds: 1));
  }

  group('the quiz board', () {
    testWidgets('a podium for the first three, the winner in the middle',
        (tester) async {
      await pump(
        tester,
        QuizLeaderboard(
          board: board([(1, 'Asha', 900), (2, 'Ravi', 700), (3, 'Nia', 400)]),
          me: 'Ravi',
          myRank: 2,
          myScore: 700,
        ),
      );

      for (final name in ['Asha', 'Ravi', 'Nia']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.bySemanticsLabel('1st, Asha, 900 points'), findsOneWidget);
      expect(find.bySemanticsLabel('2nd, Ravi, 700 points, you'),
          findsOneWidget);
      expect(find.bySemanticsLabel('3rd, Nia, 400 points'), findsOneWidget);

      // The winner stands between the other two, and highest.
      final first = tester.getCenter(find.text('Asha'));
      final second = tester.getCenter(find.text('Ravi'));
      final third = tester.getCenter(find.text('Nia'));
      expect(second.dx, lessThan(first.dx));
      expect(third.dx, greaterThan(first.dx));
      expect(first.dy, lessThan(second.dy));
      expect(first.dy, lessThan(third.dy));

      // On the board already: no second, pinned copy of their row.
      expect(find.byKey(const ValueKey('board-me')), findsNothing);
    });

    testWidgets('tied players share a rank, as the server gives it',
        (tester) async {
      await pump(
        tester,
        QuizLeaderboard(
          // board.py: 1 + the players strictly above, so two firsts and
          // then a third — never a second.
          board: board([
            (1, 'Asha', 900),
            (1, 'Ravi', 900),
            (3, 'Nia', 400),
            (3, 'Sam', 400),
          ]),
          me: 'Nia',
          myRank: 3,
          myScore: 400,
        ),
      );

      expect(find.text('1'), findsNWidgets(2), reason: 'both firsts read 1');
      expect(find.text('2'), findsNothing, reason: 'nobody came second');
      expect(find.bySemanticsLabel('1st, Asha, 900 points'), findsOneWidget);
      expect(find.bySemanticsLabel('1st, Ravi, 900 points'), findsOneWidget);
      expect(find.bySemanticsLabel('3rd, Nia, 400 points, you'),
          findsOneWidget);
      expect(find.bySemanticsLabel('3rd, Sam, 400 points'), findsOneWidget);
    });

    testWidgets('the player\'s own row is pinned when they are 40th',
        (tester) async {
      await pump(
        tester,
        QuizLeaderboard(
          board: board([
            for (var i = 1; i <= 10; i++) (i, 'Player $i', 1000 - i * 10),
          ]),
          me: 'Asha',
          myRank: 40,
          myScore: 120,
        ),
      );

      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 10'), findsOneWidget);
      // Far off the board, and still on the screen.
      expect(find.byKey(const ValueKey('board-me')), findsOneWidget);
      expect(find.text('Asha · you'), findsOneWidget);
      expect(find.bySemanticsLabel('40th, Asha, 120 points, you'),
          findsOneWidget);
      // Below everything else, under the gap.
      expect(find.text('· · ·'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('board-me'))).dy,
        greaterThan(tester.getTopLeft(find.text('Player 10')).dy),
      );
    });

    testWidgets('an empty board still shows the player their own place',
        (tester) async {
      await pump(
        tester,
        const QuizLeaderboard(board: [], me: 'Asha', myRank: 7, myScore: 50),
      );
      expect(find.byKey(const ValueKey('board-me')), findsOneWidget);
      expect(find.bySemanticsLabel('7th, Asha, 50 points, you'),
          findsOneWidget);
    });

    testWidgets('a board with nothing to say at all draws nothing',
        (tester) async {
      await pump(tester, const QuizLeaderboard(board: [], me: 'Asha'));
      expect(find.byKey(const ValueKey('board-me')), findsNothing);
      expect(find.bySemanticsLabel('Leaderboard'), findsNothing);
    });

    testWidgets('a rank that changed is marked, not flickered',
        (tester) async {
      final before = board([
        (1, 'Asha', 900),
        (2, 'Ravi', 700),
        (3, 'Nia', 400),
        (4, 'Sam', 300),
        (5, 'Ben', 200),
      ]);
      await pump(tester, QuizLeaderboard(board: before, me: 'Ben'));
      expect(find.byIcon(Icons.arrow_drop_up_rounded), findsNothing);

      // Ben climbs past Sam; both are off the podium, so both are rows.
      await pump(
        tester,
        QuizLeaderboard(
          board: board([
            (1, 'Asha', 900),
            (2, 'Ravi', 700),
            (3, 'Nia', 400),
            (4, 'Ben', 350),
            (5, 'Sam', 300),
          ]),
          me: 'Ben',
        ),
      );
      expect(find.byIcon(Icons.arrow_drop_up_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down_rounded), findsOneWidget);
      expect(find.bySemanticsLabel('4th, Ben, 350 points, you, moved up'),
          findsOneWidget);
    });

    testWidgets('it holds at 320 points wide with the largest text',
        (tester) async {
      await pump(
        tester,
        QuizLeaderboard(
          board: board([
            (1, 'Priyadarshini Venkataraman', 1200),
            (2, 'Ravi', 700),
            (3, 'Nia', 400),
            (4, 'Someone With A Very Long Name Indeed', 300),
          ]),
          me: 'Asha',
          myRank: 40,
          myScore: 120,
        ),
        size: const Size(320, 900),
        textScale: 2,
      );
      expect(tester.takeException(), isNull, reason: 'nothing clipped');
      expect(find.byKey(const ValueKey('board-me')), findsOneWidget);
    });

    testWidgets('with motion turned down the score is there at once',
        (tester) async {
      await pump(
        tester,
        QuizLeaderboard(board: board([(1, 'Asha', 900)]), me: 'Asha'),
        stillMotion: true,
      );
      await tester.pump();
      expect(find.text('900'), findsOneWidget);
    });
  });

  group('places', () {
    test('read as English ordinals', () {
      expect(ordinal(1), '1st');
      expect(ordinal(2), '2nd');
      expect(ordinal(3), '3rd');
      expect(ordinal(11), '11th');
      expect(ordinal(21), '21st');
      expect(ordinal(112), '112th');
    });
  });
}
