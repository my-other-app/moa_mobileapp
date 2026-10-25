import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/presentation/pages/live_room_page.dart';
import 'package:finnet/features/live/presentation/pages/quiz_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'live_fakes.dart';

void main() {
  late FakeLiveRoomApi api;

  setUp(() => api = FakeLiveRoomApi());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  Future<void> pumpRoom(WidgetTester tester, {String ref = '7'}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        liveRoomApiProvider.overrideWithValue(api),
        liveIdentityProvider.overrideWithValue(LiveIdentity(MemoryLiveStore())),
      ],
      child: MaterialApp(home: LiveRoomPage(eventRef: ref)),
    ));
    await settle(tester);
  }

  /// Takes the page away, so its reads stop with the test.
  Future<void> leave(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  testWidgets('the room: the update, earlier ones, the quiz, the poll and '
      'the board', (tester) async {
    api.rooms.add(roomJson(
      banner: {'id': 'u2', 'kind': 'room', 'text': 'Demos move to Lab 3B'},
      updates: [
        {'id': 'u2', 'kind': 'room', 'text': 'Demos move to Lab 3B'},
        {'id': 'u1', 'kind': 'schedule', 'text': 'Talks start at 7'},
      ],
      poll: pollJson(),
      questions: [
        questionJson('a', text: 'Will the slides be shared?', votes: 3),
        questionJson('b', text: 'Is there pizza?', pinned: true),
      ],
      quizLive: true,
      quizTitle: 'Warm-up',
    ));
    await pumpRoom(tester);

    expect(find.text('Live room'), findsOneWidget);
    expect(find.text('Hack Night'), findsOneWidget);
    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('Demos move to Lab 3B'), findsOneWidget);
    expect(find.text('Warm-up'), findsOneWidget);
    expect(find.text('Join the quiz'), findsOneWidget);
    expect(find.text('Pizza or dosa?'), findsOneWidget);
    final list = find
        .descendant(of: find.byType(ListView), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Is there pizza?'), 200,
        scrollable: list);
    expect(find.text('Ask the room'), findsOneWidget);
    expect(find.text('On screen'), findsOneWidget);
    // Pinned first.
    final pinned = tester.getTopLeft(find.text('Is there pizza?')).dy;
    final other = tester.getTopLeft(find.text('Will the slides be shared?')).dy;
    expect(pinned, lessThan(other));
    await tester.scrollUntilVisible(find.text('Talks start at 7'), 200,
        scrollable: list);
    expect(find.text('Earlier tonight'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a choice: tapped, sent, and the room\'s counts shown after',
      (tester) async {
    api.rooms.add(roomJson(poll: pollJson()));
    api.respondAnswer = (id, value) => pollJson(
          id: id,
          responses: 3,
          choices: [
            {'label': 'Pizza', 'count': 2, 'pct': 67},
            {'label': 'Dosa', 'count': 1, 'pct': 33},
          ],
          myResponse: value,
        );
    await pumpRoom(tester);
    expect(find.text('67%'), findsNothing, reason: 'results after voting');

    await tester.tap(find.text('Pizza'));
    await settle(tester);
    expect(api.responses.single, ('p1', 'Pizza'));
    expect(find.text('67%'), findsOneWidget);
    expect(find.text('3 answers so far · you answered'), findsOneWidget);
    expect(find.bySemanticsLabel('Pizza, 67 percent, your answer'),
        findsOneWidget);
    await leave(tester);
  });

  testWidgets('a word cloud: a word in, and the room\'s words after',
      (tester) async {
    api.rooms.add(roomJson(poll: pollJson(kind: 'words', options: [])));
    api.respondAnswer = (id, value) => pollJson(
          id: id,
          kind: 'words',
          options: [],
          responses: 5,
          words: [
            {'word': 'fun', 'count': 3},
            {'word': value, 'count': 1},
          ],
          myResponse: value,
        );
    await pumpRoom(tester);
    await tester.enterText(find.byKey(const ValueKey('poll-word')), 'loud');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await settle(tester);
    expect(api.responses.single, ('p1', 'loud'));
    expect(find.text('fun'), findsOneWidget);
    expect(find.text('loud'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a rating: five stars, each a big target with a name',
      (tester) async {
    api.rooms.add(roomJson(poll: pollJson(kind: 'rating', options: [])));
    api.respondAnswer = (id, value) => pollJson(
          id: id,
          kind: 'rating',
          options: [],
          responses: 2,
          rating: {'average': 4.5, 'histogram': []},
          myResponse: value,
        );
    await pumpRoom(tester);
    final star = tester.getSize(find.byKey(const ValueKey('rate-4')));
    expect(star.width, greaterThanOrEqualTo(48));
    expect(star.height, greaterThanOrEqualTo(48));
    expect(find.bySemanticsLabel('4 of 5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rate-4')));
    await settle(tester);
    expect(api.responses.single, ('p1', '4'));
    expect(find.text('Room average 4.5 of 5'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('asking, and voting a question up', (tester) async {
    api.rooms.add(roomJson(questions: [questionJson('a', votes: 2)]));
    api.voteAnswer = (_) => (votes: 3, voted: true);
    await pumpRoom(tester);

    expect(find.bySemanticsLabel('2 votes. Vote this question up'),
        findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('vote-a')));
    await settle(tester);
    expect(api.votes, ['a']);
    expect(find.bySemanticsLabel('3 votes, yours among them. Take your vote '
            'back'),
        findsOneWidget);
    final target = tester.getSize(find.byKey(const ValueKey('vote-a')));
    expect(target.height, greaterThanOrEqualTo(48));

    await tester.enterText(
        find.byKey(const ValueKey('ask-text')), 'Is there pizza?');
    await tester.pump();
    await tester.tap(find.text('Ask'));
    await settle(tester);
    expect(api.asked.single.$1, 'Is there pizza?');
    expect(find.text('Up on the board.'), findsOneWidget);
    expect(find.text('Is there pizza?'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('where the organiser lets questions through, a question waits',
      (tester) async {
    api.rooms.add(roomJson(approveFirst: true));
    api.askAnswer = (text) => questionJson('w', text: text, status: 'pending');
    await pumpRoom(tester);
    expect(find.textContaining('once the organiser lets them through'),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('ask-text')), 'Is there pizza?');
    await tester.pump();
    await tester.tap(find.text('Ask'));
    await settle(tester);
    expect(find.text('Sent — the organiser will put it up.'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('Q&A off (the plan, or the server): no ask box', (tester) async {
    api.rooms.add(roomJson(qaOpen: false, questions: [questionJson('a')]));
    await pumpRoom(tester);
    expect(find.text('Questions from the room'), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-text')), findsNothing);
    await leave(tester);
  });

  testWidgets('an empty room says what will appear', (tester) async {
    api.rooms.add(roomJson(qaOpen: false));
    await pumpRoom(tester);
    expect(find.text('Nothing in the room yet'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a closed room: read-only', (tester) async {
    api.rooms.add(roomJson(
      status: 'closed',
      poll: pollJson(
        responses: 2,
        choices: [
          {'label': 'Pizza', 'count': 2, 'pct': 100},
          {'label': 'Dosa', 'count': 0, 'pct': 0},
        ],
      ),
      questions: [questionJson('a')],
    ));
    await pumpRoom(tester);
    expect(find.textContaining('the live room has closed'), findsOneWidget);
    expect(find.byKey(const ValueKey('ask-text')), findsNothing);
    expect(find.text('100%'), findsOneWidget, reason: 'results, no voting');
    await tester.tap(find.text('Pizza'));
    await settle(tester);
    expect(api.responses, isEmpty);
    await leave(tester);
  });

  testWidgets('kept current while open: the next read shows without '
      'reopening', (tester) async {
    api.rooms
      ..add(roomJson(banner: {'id': 'u1', 'kind': 'room', 'text': 'Doors at 6'}))
      ..add(roomJson(banner: {'id': 'u2', 'kind': 'room', 'text': 'Lab 3B'}));
    await pumpRoom(tester);
    expect(find.text('Doors at 6'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    expect(find.text('Lab 3B'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a room that could not load offers to try again',
      (tester) async {
    api.rooms
      ..add(apiError(500))
      ..add(roomJson(banner: {'id': 'u', 'kind': 'room', 'text': 'Back'}));
    await pumpRoom(tester);
    expect(find.text('The room could not load'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    await settle(tester);
    expect(find.text('Back'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a room the server does not know', (tester) async {
    api.rooms.add(apiError(404));
    await pumpRoom(tester);
    expect(find.text('This live room isn’t available'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('a slug is found first', (tester) async {
    api
      ..resolvedId = 7
      ..rooms.add(roomJson());
    await pumpRoom(tester, ref: 'hack-night');
    expect(find.text('Ask the room'), findsOneWidget);
    await leave(tester);
  });

  testWidgets('the quiz card opens the quiz', (tester) async {
    api.rooms.add(roomJson(quizLive: true, quizTitle: 'Warm-up'));
    await pumpRoom(tester);
    await tester.tap(find.text('Join the quiz'));
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QuizPage), findsOneWidget);
    await leave(tester);
  });

  testWidgets('every tap target is big enough and named', (tester) async {
    api.rooms.add(roomJson(
      poll: pollJson(),
      questions: [questionJson('a')],
      quizLive: true,
    ));
    await pumpRoom(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await leave(tester);
  });
}
