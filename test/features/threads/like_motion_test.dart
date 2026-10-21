import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/threads/presentation/widgets/thread_card.dart';
import 'package:finnet/shared/motion.dart';
import 'package:finnet/shared/widgets/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// A like you can feel and see: the heart pops and fills, the count ticks,
// the phone taps back -- and with less motion asked for, only the tap.

/// What the phone was asked to feel.
List<String> _feel(WidgetTester tester) {
  final felt = <String>[];
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') {
      felt.add(call.arguments as String);
    }
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return felt;
}

const _poll = Poll(
  options: [
    PollOption(id: 'fri', label: 'Friday', votes: 3, share: 75),
    PollOption(id: 'sat', label: 'Saturday', votes: 1, share: 25),
  ],
  votes: 4,
);

Thread _thread({bool liked = false, int likes = 3, Poll? poll}) => Thread(
      id: 't1',
      club: const ThreadClub(id: 5, name: 'Tinkerhub CET'),
      body: 'Doors open at six.',
      poll: poll,
      kind: poll == null ? ThreadKind.post : ThreadKind.poll,
      liked: liked,
      likes: likes,
      comments: 7,
      createdAt: DateTime.now(),
    );

/// A card whose like and vote work as a screen's do: at once, optimistically
/// -- or, with [signedIn] false, not at all (the tap asks to sign in).
class _Host extends StatefulWidget {
  const _Host({required this.thread, this.signedIn = true, this.calm = false});

  final Thread thread;
  final bool signedIn;
  final bool calm;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Thread thread = widget.thread;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: widget.calm),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ThreadCard(
                thread: thread,
                onTap: () {},
                onLike: () {
                  if (!widget.signedIn) return;
                  setState(() => thread = thread.withLikeToggled());
                },
                onVote: (id) {
                  if (!widget.signedIn) return;
                  setState(() => thread =
                      thread.copyWith(poll: thread.poll!.withVote(id)));
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

LikeButtonState _like(WidgetTester tester) =>
    tester.state<LikeButtonState>(find.byType(LikeButton));

Finder get _likeButton => find.byKey(const ValueKey('thread-like'));

void main() {
  testWidgets('a like pops the heart, fills it, ticks the count and is felt',
      (tester) async {
    final felt = _feel(tester);
    await tester.pumpWidget(_Host(thread: _thread()));
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);

    await tester.tap(_likeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(_like(tester).popping, isTrue);
    expect(felt, ['HapticFeedbackType.lightImpact']);
    // The heart on its way to filled; the count on its way from 3 to 4.
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    // The heart is drawn larger than itself mid-pop.
    final pop = tester.widget<ScaleTransition>(find
        .descendant(of: _likeButton, matching: find.byType(ScaleTransition))
        .first);
    expect(pop.scale.value, greaterThan(1));

    await tester.pumpAndSettle();
    expect(_like(tester).popping, isFalse);
    expect(pop.scale.value, 1);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(tester.widget<Icon>(find.byIcon(Icons.favorite)).color,
        LikeButton.likedColor);
    expect(find.text('3'), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('taking a like back is felt, but nothing pops', (tester) async {
    final felt = _feel(tester);
    await tester.pumpWidget(_Host(thread: _thread(liked: true)));

    await tester.tap(_likeButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    expect(_like(tester).popping, isFalse);
    expect(felt, ['HapticFeedbackType.lightImpact']);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('a tap that only asks to sign in neither pops nor is felt',
      (tester) async {
    final felt = _feel(tester);
    await tester.pumpWidget(_Host(thread: _thread(), signedIn: false));

    await tester.tap(_likeButton);
    await tester.pump(const Duration(milliseconds: 60));

    expect(_like(tester).popping, isFalse);
    expect(felt, isEmpty);
    await tester.pumpAndSettle();
  });

  testWidgets('less motion: still felt, but the heart and count just change',
      (tester) async {
    final felt = _feel(tester);
    await tester.pumpWidget(_Host(thread: _thread(), calm: true));

    await tester.tap(_likeButton);
    await tester.pump();

    expect(felt, ['HapticFeedbackType.lightImpact']);
    expect(_like(tester).popping, isFalse);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('3'), findsNothing);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('pressing the heart sinks the heart, not the card',
      (tester) async {
    await tester.pumpWidget(_Host(thread: _thread()));

    final finger = await tester.startGesture(tester.getCenter(_likeButton));
    await tester.pump(Pressable.delay);
    await tester.pump();
    await tester.pump(Motion.fast);

    final heart = tester.state<PressableState>(
        find.descendant(of: _likeButton, matching: find.byType(Pressable)));
    final card = tester.state<PressableState>(find
        .descendant(
            of: find.byType(ThreadCard), matching: find.byType(Pressable))
        .first);
    expect(heart.scale, lessThan(1));
    expect(card.scale, 1);
    await finger.up();
    await tester.pumpAndSettle();
  });

  testWidgets('a vote slides the bars to their new shares and is felt',
      (tester) async {
    final felt = _feel(tester);
    await tester.pumpWidget(_Host(thread: _thread(poll: _poll)));

    double bar(String id) => tester
        .widget<FractionallySizedBox>(find.descendant(
            of: find.byKey(ValueKey('poll-option-$id')),
            matching: find.byType(FractionallySizedBox)))
        .widthFactor!;
    expect(bar('sat'), 0.25);

    // Saturday: 2 of 5 votes, 40%.
    await tester.tap(find.byKey(const ValueKey('poll-option-sat')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(felt, ['HapticFeedbackType.lightImpact']);
    expect(bar('sat'), greaterThan(0.25));
    expect(bar('sat'), lessThan(0.40));

    await tester.pumpAndSettle();
    expect(bar('sat'), closeTo(0.40, 0.0001));
    expect(bar('fri'), closeTo(0.60, 0.0001));
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('60%'), findsOneWidget);
  });

  testWidgets('less motion: the bars move straight to their shares',
      (tester) async {
    await tester.pumpWidget(_Host(thread: _thread(poll: _poll), calm: true));

    await tester.tap(find.byKey(const ValueKey('poll-option-sat')));
    await tester.pump();
    await tester.pump();

    final bar = tester.widget<FractionallySizedBox>(find.descendant(
        of: find.byKey(const ValueKey('poll-option-sat')),
        matching: find.byType(FractionallySizedBox)));
    expect(bar.widthFactor, closeTo(0.40, 0.0001));
  });
}
