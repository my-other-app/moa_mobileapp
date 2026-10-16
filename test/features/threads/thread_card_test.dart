import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );

const _poll = Poll(
  options: [
    PollOption(id: 'fri', label: 'Friday', votes: 3, share: 75),
    PollOption(id: 'sat', label: 'Saturday', votes: 1, share: 25),
  ],
  votes: 4,
  votedOptionId: 'fri',
);

Thread _thread({
  String body = 'Doors open at six. Bring a laptop.',
  bool pinned = false,
  bool liked = false,
  int likes = 3,
  int comments = 2,
  Poll? poll,
}) =>
    Thread(
      id: 't1',
      club: const ThreadClub(id: 5, name: 'Tinkerhub CET'),
      body: body,
      kind: poll == null ? ThreadKind.post : ThreadKind.poll,
      poll: poll,
      pinned: pinned,
      liked: liked,
      likes: likes,
      comments: comments,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    );

void main() {
  test('counts are compacted to fit beside their icon', () {
    expect(compactCount(0), '0');
    expect(compactCount(999), '999');
    expect(compactCount(1000), '1K');
    expect(compactCount(1250), '1.3K');
    expect(compactCount(12345), '12K');
    expect(compactCount(2500000), '2.5M');
  });

  group('ThreadCard', () {
    testWidgets('shows who posted, when, what they said, and the counts',
        (tester) async {
      await tester.pumpWidget(_host(ThreadCard(thread: _thread())));

      expect(find.text('Tinkerhub CET'), findsOneWidget);
      expect(find.text('2 hours ago'), findsOneWidget);
      expect(find.text('Doors open at six. Bring a laptop.'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // No logo: the club's initial on a tile, not a broken image.
      expect(find.text('T'), findsOneWidget);
      expect(find.text('PINNED'), findsNothing);
    });

    testWidgets('a pinned post says so', (tester) async {
      await tester.pumpWidget(_host(ThreadCard(thread: _thread(pinned: true))));

      expect(find.text('PINNED'), findsOneWidget);
    });

    testWidgets('the like button reflects the like and reports taps',
        (tester) async {
      var likes = 0;
      await tester.pumpWidget(_host(ThreadCard(
        thread: _thread(liked: true),
        onLike: () => likes++,
      )));

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      await tester.tap(find.byKey(const ValueKey('thread-like')));
      expect(likes, 1);
    });

    testWidgets('a poll shows its options, shares, total and the choice',
        (tester) async {
      await tester.pumpWidget(_host(ThreadCard(thread: _thread(poll: _poll))));

      expect(find.text('Friday'), findsOneWidget);
      expect(find.text('Saturday'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('4 votes · You voted'), findsOneWidget);
      // The viewer's choice is ticked, and only that one.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('poll-option-fri')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('poll-option-sat')),
          matching: find.byIcon(Icons.check_circle),
        ),
        findsNothing,
      );
    });

    testWidgets('tapping an option votes for it', (tester) async {
      String? voted;
      await tester.pumpWidget(_host(ThreadCard(
        thread: _thread(poll: _poll),
        onVote: (id) => voted = id,
      )));

      await tester.tap(find.byKey(const ValueKey('poll-option-sat')));

      expect(voted, 'sat');
    });

    testWidgets('one vote reads as "1 vote", and no choice says nothing more',
        (tester) async {
      const poll = Poll(
        options: [PollOption(id: 'a', label: 'Yes', votes: 1, share: 100)],
        votes: 1,
      );
      await tester.pumpWidget(_host(ThreadCard(thread: _thread(poll: poll))));

      expect(find.text('1 vote'), findsOneWidget);
    });

    testWidgets('tapping the card opens the post', (tester) async {
      var opened = 0;
      await tester.pumpWidget(_host(ThreadCard(
        thread: _thread(),
        onTap: () => opened++,
      )));

      await tester.tap(find.text('Doors open at six. Bring a laptop.'));
      expect(opened, 1);
    });

    testWidgets('a list card clips long text; the post page shows it all',
        (tester) async {
      final long = List.filled(40, 'A long line about the sprint.').join(' ');

      await tester.pumpWidget(_host(ThreadCard(thread: _thread(body: long))));
      expect(tester.widget<Text>(find.text(long)).maxLines,
          ThreadCard.collapsedLines);

      await tester.pumpWidget(
          _host(ThreadCard(thread: _thread(body: long), expanded: true)));
      expect(tester.widget<Text>(find.text(long)).maxLines, isNull);
    });

    testWidgets('a narrow phone and a long club name do not overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(ThreadCard(
        thread: Thread(
          id: 't1',
          club: const ThreadClub(
              id: 5, name: 'A Club With Quite A Long Name Indeed, Really'),
          body: 'Body',
          kind: ThreadKind.poll,
          poll: const Poll(options: [
            PollOption(
              id: 'a',
              label: 'An option label that runs on for rather a while',
              votes: 999,
              share: 100,
            ),
          ], votes: 999),
          pinned: true,
          likes: 123456,
          comments: 98765,
          createdAt: DateTime.now(),
        ),
      )));

      expect(tester.takeException(), isNull);
    });
  });
}
