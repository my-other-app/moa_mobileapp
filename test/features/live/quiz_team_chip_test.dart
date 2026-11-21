import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/presentation/widgets/quiz_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the team chip says a team name once', () {
    test('puts "Team" before a plain name', () {
      expect(QuizTeamChip.spokenLabel('Team', 'Red Rockets'),
          'Team Red Rockets');
      expect(QuizTeamChip.spokenLabel('Team', '  Kotlin '), 'Team Kotlin');
    });

    test('keeps a name that already starts with Team, in any case', () {
      expect(QuizTeamChip.spokenLabel('Team', 'Team Flutter'), 'Team Flutter');
      expect(QuizTeamChip.spokenLabel('Team', 'team flutter'), 'team flutter');
      expect(QuizTeamChip.spokenLabel('Team', 'TEAM-7'), 'TEAM-7');
      expect(QuizTeamChip.spokenLabel('Team', 'Team'), 'Team');
    });

    test('does not mistake a word that only begins with "team"', () {
      expect(QuizTeamChip.spokenLabel('Team', 'Teamwork'), 'Team Teamwork');
      expect(QuizTeamChip.spokenLabel('Team', 'Teal'), 'Team Teal');
    });

    test('another prefix is always said', () {
      expect(QuizTeamChip.spokenLabel('Your team:', 'Team Flutter'),
          'Your team: Team Flutter');
    });

    testWidgets('the chip shows the name and reads it once', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuizTeamChip(
              team: QuizTeam(key: 'flutter', name: 'Team Flutter'),
            ),
          ),
        ),
      ));
      expect(find.text('Team Flutter'), findsOneWidget);
      expect(find.bySemanticsLabel('Team Flutter'), findsOneWidget);
      expect(find.bySemanticsLabel('Team Team Flutter'), findsNothing);
      handle.dispose();
    });
  });
}
