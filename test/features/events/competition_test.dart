import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/data/models/competition_model.dart';
import 'package:finnet/features/events/domain/entities/competition.dart';
import 'package:finnet/features/events/presentation/pages/competition_page.dart';
import 'package:finnet/features/events/presentation/providers/competition_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

/// `GET /events/7/competition/me`, as production sends it (`MyState`).
Map<String, dynamic> myState({
  bool onTeam = false,
  bool locked = false,
  bool board = false,
  bool seeking = false,
  String submissionStatus = 'in_progress',
}) =>
    {
      'event_id': 7,
      'enabled': true,
      'registration_id': '6f1c2d4e-0000-4000-8000-000000000001',
      'name': 'Asha Menon',
      'team_min': 2,
      'team_max': 4,
      'teams_locked': locked,
      'tracks': [
        {
          'id': 1,
          'name': 'AI for Bharat',
          'description': 'Models for Indian languages.',
          'sponsor': 'Sarvam',
          'prize': '₹50,000',
          'sort_order': 0,
          'teams': 3,
        },
        {
          'id': 2,
          'name': 'Open hardware',
          'description': null,
          'sponsor': null,
          'prize': null,
          'sort_order': 1,
          'teams': 1,
        },
      ],
      'requirements': [
        {'key': 'repo', 'label': 'Code repository', 'required': true},
        {'key': 'demo', 'label': 'Demo video', 'required': false},
      ],
      'submissions_open': true,
      'submissions_close_at': '2030-12-02T12:00:00+00:00',
      'team': onTeam
          ? {
              'id': 12,
              'name': 'Byte Me',
              'track_id': 1,
              'track': 'AI for Bharat',
              'stage': 'shortlisted',
              'members': [
                {
                  'registration_id': '6f1c2d4e-0000-4000-8000-000000000001',
                  'name': 'Asha Menon',
                },
                {
                  'registration_id': '6f1c2d4e-0000-4000-8000-000000000002',
                  'name': 'Ravi Kumar',
                },
              ],
              'open_spots': 2,
              'submission': {
                'fields': {'repo': 'https://github.com/byteme/app'},
                'status': submissionStatus,
                'missing': submissionStatus == 'complete' ? [] : ['demo'],
                'completed_at': null,
                'updated_at': '2030-12-01T11:00:00+00:00',
              },
              'score': null,
              'judges_scored': 0,
              'created_at': '2030-12-01T10:00:00+00:00',
            }
          : null,
      'open_teams': onTeam
          ? []
          : [
              {
                'id': 12,
                'name': 'Byte Me',
                'track': 'AI for Bharat',
                'members': 2,
                'open_spots': 2,
              },
            ],
      'seeking': seeking
          ? {
              'registration_id': '6f1c2d4e-0000-4000-8000-000000000001',
              'name': 'Asha Menon',
              'skills': ['ML', 'pitching'],
              'note': null,
            }
          : null,
      'seekers': [
        {
          'registration_id': '6f1c2d4e-0000-4000-8000-000000000003',
          'name': 'Neha',
          'skills': ['PCB'],
          'note': null,
        },
      ],
      'mentors': [
        {
          'id': 3,
          'name': 'Dr. Iyer',
          'topic': 'Speech models',
          'sort_order': 0,
          'slots': [
            {
              'id': 5,
              'starts_at': '2030-12-01T14:00:00+00:00',
              'minutes': 15,
              'team_id': null,
              'team': null,
            },
            {
              'id': 6,
              'starts_at': '2030-12-01T14:15:00+00:00',
              'minutes': 15,
              'team_id': 12,
              'team': 'Byte Me',
            },
            {
              'id': 7,
              'starts_at': '2030-12-01T14:30:00+00:00',
              'minutes': 15,
              'team_id': 99,
              'team': 'Others',
            },
          ],
        },
      ],
      'board': board
          ? [
              {
                'rank': 1,
                'team_id': 12,
                'name': 'Byte Me',
                'track': 'AI for Bharat',
                'stage': 'finalist',
                'score': 8.25,
                'judges_scored': 3,
                'judges_total': 3,
              },
            ]
          : null,
    };

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<void> _pump(WidgetTester tester,
    {String ref = '7', bool signedIn = true}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [isAuthenticatedProvider.overrideWithValue(signedIn)],
    child: MaterialApp(
      home: CompetitionPage(eventRef: ref, eventName: 'Hack Night'),
    ),
  ));
  await _settle(tester);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  late RouteAdapter api;

  setUp(() => api = useFakeApi());

  group('myCompetitionFromJson', () {
    test('reads the whole state', () {
      final me = myCompetitionFromJson(myState(onTeam: true, board: true))!;
      expect(me.eventId, 7);
      expect(me.teamSizeLine, 'Teams are 2 to 4 people.');
      expect(me.tracks.first.line, 'Sponsored by Sarvam · ₹50,000 · 3 teams');
      expect(me.tracks.last.line, '1 team');
      expect(me.team!.stage, TeamStage.shortlisted);
      expect(me.team!.members.map((m) => m.name), ['Asha Menon', 'Ravi Kumar']);
      expect(me.team!.submission.status, SubmissionStatus.inProgress);
      expect(me.team!.submission.missing, ['demo']);
      expect(me.requirementLabel('demo'), 'Demo video');
      expect(me.mentors.single.slots.map((s) => s.teamId), [null, 12, 99]);
      expect(me.board!.single.score, 8.25);
      expect(me.seekers.single.skills, ['PCB']);
    });

    test('tolerates missing fields and bad rows', () {
      final me = myCompetitionFromJson({
        'event_id': '7',
        'tracks': [
          {'id': 1},
          {'name': 'no id'},
        ],
        'open_teams': [
          {'id': 'x'},
        ],
        'mentors': [
          {
            'id': 3,
            'name': 'M',
            'slots': [
              {'id': 1},
            ],
          },
        ],
      })!;
      expect(me.tracks, isEmpty);
      expect(me.openTeams, isEmpty);
      expect(me.mentors.single.slots, isEmpty);
      expect(me.team, isNull);
      expect(me.board, isNull);
      expect(me.teamSizeLine, 'Teams are 1 person.');
    });

    test('is null for what is not one', () {
      expect(myCompetitionFromJson(null), isNull);
      expect(myCompetitionFromJson({'enabled': true}), isNull);
    });

    test('skillsFrom keeps eight, trimmed', () {
      expect(skillsFrom(' ML, PCB ,, pitching '), ['ML', 'PCB', 'pitching']);
      expect(skillsFrom(List.filled(10, 'x').join(',')), hasLength(8));
    });
  });

  group('Your team', () {
    testWidgets('without a team: tracks, make a team, the open ones',
        (tester) async {
      api
        ..on('GET', '/events/7/competition/me', myState())
        ..on('POST', '/events/7/competition/me/team', myState(onTeam: true));
      await _pump(tester);

      expect(find.text('Tracks'), findsOneWidget);
      expect(find.text('AI for Bharat'), findsOneWidget);
      expect(find.text('Find your team'), findsOneWidget);
      expect(
          find.text(
              'Teams are 2 to 4 people. Make one, or join one with a spot.'),
          findsOneWidget);
      expect(find.text('Byte Me'), findsOneWidget);
      expect(find.text('AI for Bharat · 2 of 4'), findsOneWidget);
      expect(find.text('Neha'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('competition-team-name')), '  Byte Me  ');
      await tester.pump();
      await _tap(tester, find.widgetWithText(FilledButton, 'Make a team'));

      final sent = api.sent('POST', '/events/7/competition/me/team').single;
      expect(sent.data, {'name': 'Byte Me', 'track_id': null});
      expect(find.byKey(const ValueKey('competition-my-team')), findsOneWidget);
      expect(find.text('Your submission'), findsOneWidget);
    });

    testWidgets('joins an open team', (tester) async {
      api
        ..on('GET', '/events/7/competition/me', myState())
        ..on('POST', '/events/7/competition/me/team/join/12',
            myState(onTeam: true));
      await _pump(tester);

      await _tap(tester, find.widgetWithText(OutlinedButton, 'Join'));
      expect(api.sent('POST', '/events/7/competition/me/team/join/12'),
          hasLength(1));
      expect(find.text('Ravi Kumar'), findsOneWidget);
    });

    testWidgets('says they are looking for a team', (tester) async {
      api
        ..on('GET', '/events/7/competition/me', myState())
        ..on('PUT', '/events/7/competition/me/seeking', myState(seeking: true));
      await _pump(tester);

      await _tap(tester, find.byKey(const ValueKey('competition-seeking')));
      final sent = api.sent('PUT', '/events/7/competition/me/seeking').single;
      expect((sent.data as Map)['on'], isTrue);
      expect(find.text('What you bring'), findsOneWidget);
    });

    testWidgets('on a team: members, the submission and the office hours',
        (tester) async {
      api
        ..on('GET', '/events/7/competition/me', myState(onTeam: true))
        ..on('PUT', '/events/7/competition/me/submission',
            myState(onTeam: true, submissionStatus: 'complete'))
        ..on('POST', '/events/7/competition/me/slots/5', myState(onTeam: true))
        ..on('DELETE', '/events/7/competition/me/slots/6',
            myState(onTeam: true));
      await _pump(tester);

      expect(find.text('Byte Me'), findsOneWidget);
      expect(find.text('AI for Bharat · 2 of 4 · Shortlisted'), findsOneWidget);
      expect(find.text('Ravi Kumar'), findsOneWidget);
      expect(find.text('Still missing: Demo video'), findsOneWidget);
      expect(find.text('https://github.com/byteme/app'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('submission-demo')),
          'https://youtu.be/demo');
      await _tap(tester, find.widgetWithText(FilledButton, 'Save submission'));
      final submitted =
          api.sent('PUT', '/events/7/competition/me/submission').single;
      expect(submitted.data, {
        'fields': {
          'repo': 'https://github.com/byteme/app',
          'demo': 'https://youtu.be/demo',
        },
      });
      expect(find.text('Everything required is in.'), findsOneWidget);

      // A free slot is booked; their own is freed; someone else's is taken.
      await _tap(tester, find.byKey(const ValueKey('slot-5')));
      expect(
          api.sent('POST', '/events/7/competition/me/slots/5'), hasLength(1));
      await _tap(tester, find.byKey(const ValueKey('slot-6')));
      expect(
          api.sent('DELETE', '/events/7/competition/me/slots/6'), hasLength(1));
      final taken =
          tester.widget<ChoiceChip>(find.byKey(const ValueKey('slot-7')));
      expect(taken.onSelected, isNull);
    });

    testWidgets('leaving asks first', (tester) async {
      api
        ..on('GET', '/events/7/competition/me', myState(onTeam: true))
        ..on('POST', '/events/7/competition/me/team/leave', myState());
      await _pump(tester);

      await _tap(tester, find.text('Leave the team'));
      expect(find.text('Leave your team?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await _settle(tester);
      expect(api.sent('POST', '/events/7/competition/me/team/leave'),
          hasLength(1));
      expect(find.text('Find your team'), findsOneWidget);
    });

    testWidgets('locked teams: nothing to change, and it says why',
        (tester) async {
      api.on('GET', '/events/7/competition/me', myState(locked: true));
      await _pump(tester);

      expect(find.text('Teams are locked. Ask the organisers to move you.'),
          findsOneWidget);
      final join = tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Join'));
      expect(join.onPressed, isNull);
    });

    testWidgets("a refused change is said in the server's words",
        (tester) async {
      api
        ..on('GET', '/events/7/competition/me', myState())
        ..on('POST', '/events/7/competition/me/team/join/12',
            {'message': 'Teams are locked; ask the organisers'},
            status: 409);
      await _pump(tester);

      await _tap(tester, find.widgetWithText(OutlinedButton, 'Join'));
      expect(find.text('Teams are locked; ask the organisers'), findsOneWidget);
      expect(find.text('Find your team'), findsOneWidget);
    });

    testWidgets('the board, once public, with their team marked',
        (tester) async {
      api.on('GET', '/events/7/competition/me',
          myState(onTeam: true, board: true));
      await _pump(tester);

      expect(find.text('Leaderboard'), findsOneWidget);
      expect(find.text('8.3'), findsOneWidget);
    });

    testWidgets('by slug, the event is found first', (tester) async {
      api
        ..on('GET', '/events/info/hack-night', {'id': 7, 'name': 'Hack Night'})
        ..on('GET', '/events/7/competition/me', myState());
      await _pump(tester, ref: 'hack-night');

      expect(api.sent('GET', '/events/7/competition/me'), hasLength(1));
      expect(find.text('Find your team'), findsOneWidget);
    });
  });

  group('when it cannot be shown', () {
    testWidgets('not registered', (tester) async {
      api.on('GET', '/events/7/competition/me',
          {'message': 'Register for the event first'},
          status: 403);
      await _pump(tester);
      expect(find.text('Register for the event first, then come back here.'),
          findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('no competition', (tester) async {
      api.on('GET', '/events/7/competition/me',
          {'message': 'This event has no competition'},
          status: 404);
      await _pump(tester);
      expect(find.text('This event has no competition.'), findsOneWidget);
    });

    testWidgets('the network: a retry', (tester) async {
      api
        ..on('GET', '/events/7/competition/me', {'message': 'Oops'},
            status: 503)
        ..on('GET', '/events/7/competition/me', myState());
      await _pump(tester);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(find.text('Find your team'), findsOneWidget);
    });

    testWidgets('signed out: sign in, and nothing asked', (tester) async {
      await _pump(tester, signedIn: false);
      expect(find.text('Sign in to see your team.'), findsOneWidget);
      expect(api.requests, isEmpty);
    });
  });
}
