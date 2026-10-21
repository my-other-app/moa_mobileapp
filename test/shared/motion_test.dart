import 'dart:ui' show AccessibilityFeatures;

import 'package:finnet/shared/motion.dart';
import 'package:finnet/shared/widgets/animated_count.dart';
import 'package:finnet/shared/widgets/app_toggle.dart';
import 'package:finnet/shared/widgets/entrance.dart';
import 'package:finnet/shared/widgets/fade_switch.dart';
import 'package:finnet/shared/widgets/pressable.dart';
import 'package:finnet/shared/widgets/swap_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [child] in an app, with the phone asking for less motion when [calm].
Widget _app(Widget child, {bool calm = false}) => MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: calm),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );

/// What the phone was asked to feel, from `SystemChannels.platform`.
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

PressableState _press(WidgetTester tester, [Finder? of]) =>
    tester.state<PressableState>(of ?? find.byType(Pressable).first);

Widget _card({VoidCallback? onTap, Key? key}) => Pressable(
      key: key,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(width: 200, height: 100, child: Text('card')),
      ),
    );

void main() {
  group('reduceMotion', () {
    Future<bool> ask(WidgetTester tester, {bool calm = false}) async {
      late bool answer;
      await tester.pumpWidget(_app(
        Builder(builder: (context) {
          answer = reduceMotion(context);
          return const SizedBox();
        }),
        calm: calm,
      ));
      return answer;
    }

    testWidgets('no by default', (tester) async {
      expect(await ask(tester), isFalse);
    });

    testWidgets('yes when the phone turns animations off', (tester) async {
      expect(await ask(tester, calm: true), isTrue);
    });

    testWidgets('yes with a screen reader running', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const _Features(accessibleNavigation: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      expect(await ask(tester), isTrue);
    });

    testWidgets("yes with iOS's Reduce Motion", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const _Features(reduceMotion: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      expect(await ask(tester), isTrue);
    });

    testWidgets('a duration becomes none', (tester) async {
      late Duration calm;
      late Duration lively;
      await tester.pumpWidget(_app(Builder(builder: (context) {
        lively = motionDuration(context, Motion.medium);
        return const SizedBox();
      })));
      await tester.pumpWidget(_app(
        Builder(builder: (context) {
          calm = motionDuration(context, Motion.medium);
          return const SizedBox();
        }),
        calm: true,
      ));
      expect(lively, Motion.medium);
      expect(calm, Duration.zero);
    });
  });

  group('Pressable', () {
    testWidgets('sinks under a finger and springs back when it lifts',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(_card(onTap: () => taps++)));
      expect(_press(tester).scale, 1);

      final finger =
          await tester.startGesture(tester.getCenter(find.text('card')));
      // A moment's rest before it shows (a scroll would have moved by now)...
      await tester.pump(const Duration(milliseconds: 20));
      expect(_press(tester).scale, 1);
      // ...then down to its pressed size.
      await tester.pump(Pressable.delay);
      await tester.pump();
      await tester.pump(Motion.fast);
      expect(_press(tester).pressed, isTrue);
      expect(_press(tester).scale, closeTo(Motion.pressedScale, 0.001));
      final transform = tester.widget<Transform>(find
          .descendant(
              of: find.byType(Pressable), matching: find.byType(Transform))
          .first);
      // Drawn at that size: x and y scaled (z is left alone).
      expect(
          transform.transform.storage[0], closeTo(Motion.pressedScale, 0.001));
      expect(
          transform.transform.storage[5], closeTo(Motion.pressedScale, 0.001));

      await finger.up();
      await tester.pumpAndSettle();
      expect(_press(tester).scale, 1);
      // The tap itself is still the child's.
      expect(taps, 1);
    });

    testWidgets('a quick tap still dips once, then comes back', (tester) async {
      await tester.pumpWidget(_app(_card(onTap: () {})));

      final finger =
          await tester.startGesture(tester.getCenter(find.text('card')));
      await tester.pump(const Duration(milliseconds: 10));
      await finger.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(_press(tester).scale, lessThan(1));

      await tester.pumpAndSettle();
      expect(_press(tester).scale, 1);
    });

    testWidgets('a finger that moves is a scroll: nothing sinks',
        (tester) async {
      await tester.pumpWidget(_app(_card(onTap: () {})));

      final finger =
          await tester.startGesture(tester.getCenter(find.text('card')));
      await finger.moveBy(const Offset(0, 40));
      await tester.pump(const Duration(milliseconds: 200));
      expect(_press(tester).scale, 1);
      await finger.up();
      await tester.pumpAndSettle();
    });

    testWidgets('pressing a button on a card presses the button, not the card',
        (tester) async {
      await tester.pumpWidget(_app(Pressable(
        key: const ValueKey('card'),
        child: InkWell(
          onTap: () {},
          child: SizedBox(
            width: 240,
            height: 120,
            child: Center(
              child: Pressable(
                key: const ValueKey('button'),
                scale: 0.9,
                child: TextButton(onPressed: () {}, child: const Text('like')),
              ),
            ),
          ),
        ),
      )));

      final finger =
          await tester.startGesture(tester.getCenter(find.text('like')));
      await tester.pump(Pressable.delay);
      await tester.pump();
      await tester.pump(Motion.fast);
      expect(_press(tester, find.byKey(const ValueKey('button'))).scale,
          closeTo(0.9, 0.001));
      expect(_press(tester, find.byKey(const ValueKey('card'))).scale, 1);
      await finger.up();
      await tester.pumpAndSettle();
    });

    testWidgets('stays still when it cannot be tapped', (tester) async {
      await tester.pumpWidget(_app(_card()));

      final finger =
          await tester.startGesture(tester.getCenter(find.text('card')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_press(tester).scale, 1);
      await finger.up();
    });

    testWidgets('stays still when the phone asks for less motion',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(_card(onTap: () => taps++), calm: true));

      final finger =
          await tester.startGesture(tester.getCenter(find.text('card')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(_press(tester).scale, 1);
      await finger.up();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_press(tester).scale, 1);
      expect(taps, 1);
    });
  });

  group('Entrance', () {
    Widget list({int rows = 12, bool calm = false}) => _app(
          EntranceScope(
            child: ListView.builder(
              itemCount: rows,
              itemExtent: 100,
              itemBuilder: (_, i) => Entrance(
                index: i,
                child: Text('row $i'),
              ),
            ),
          ),
          calm: calm,
        );

    double opacityOf(WidgetTester tester, String text) {
      final opacity =
          find.ancestor(of: find.text(text), matching: find.byType(Opacity));
      return opacity.evaluate().isEmpty
          ? 1
          : tester.widget<Opacity>(opacity.first).opacity;
    }

    testWidgets("the first rows come in one after another", (tester) async {
      await tester.pumpWidget(list());
      await tester.pump(const Duration(milliseconds: 100));

      // The first is on its way in; the fourth has barely started.
      expect(
          opacityOf(tester, 'row 0'), greaterThan(opacityOf(tester, 'row 3')));
      expect(opacityOf(tester, 'row 0'), lessThan(1));

      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'row 0'), 1);
      expect(opacityOf(tester, 'row 3'), 1);
    });

    testWidgets('scrolled away and back, they do not come in again',
        (tester) async {
      await tester.pumpWidget(list(rows: 40));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -2500));
      await tester.pumpAndSettle();
      expect(find.text('row 0'), findsNothing);

      await tester.drag(find.byType(ListView), const Offset(0, 2500));
      await tester.pump();
      expect(find.text('row 0'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 50));
      expect(opacityOf(tester, 'row 0'), 1);
    });

    testWidgets('less motion: every row is simply there', (tester) async {
      await tester.pumpWidget(list(calm: true));
      await tester.pump();

      expect(opacityOf(tester, 'row 0'), 1);
      expect(opacityOf(tester, 'row 3'), 1);
    });
  });

  group('FadeSwitch', () {
    Widget screen(ScreenPhase phase, {bool calm = false}) => _app(
          SizedBox(
            width: 300,
            height: 300,
            child: FadeSwitch(
              phase: phase,
              child: phase == ScreenPhase.loading
                  ? const Text('skeleton')
                  : const Text('content'),
            ),
          ),
          calm: calm,
        );

    testWidgets('the skeleton fades out as the content fades in',
        (tester) async {
      await tester.pumpWidget(screen(ScreenPhase.loading));
      await tester.pumpWidget(screen(ScreenPhase.content));
      await tester.pump(const Duration(milliseconds: 60));

      expect(find.text('skeleton'), findsOneWidget);
      expect(find.text('content'), findsOneWidget);
      // The leaving one takes no taps.
      expect(
          find.ancestor(
              of: find.text('skeleton'), matching: find.byType(IgnorePointer)),
          findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('skeleton'), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });

    testWidgets('less motion: the content simply replaces it', (tester) async {
      await tester.pumpWidget(screen(ScreenPhase.loading, calm: true));
      await tester.pumpWidget(screen(ScreenPhase.content, calm: true));
      await tester.pump();

      expect(find.text('skeleton'), findsNothing);
      expect(find.text('content'), findsOneWidget);
    });
  });

  group('AnimatedCount', () {
    testWidgets('a new count rolls in; the old one rolls out', (tester) async {
      await tester.pumpWidget(
          _app(const AnimatedCount(value: 3, style: TextStyle(fontSize: 14))));
      await tester.pumpWidget(
          _app(const AnimatedCount(value: 4, style: TextStyle(fontSize: 14))));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      // On its way up into place, from below.
      final slide = tester.widget<SlideTransition>(find
          .ancestor(of: find.text('4'), matching: find.byType(SlideTransition))
          .first);
      expect(slide.position.value.dy, greaterThan(0));

      await tester.pumpAndSettle();
      expect(find.text('3'), findsNothing);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('less motion: it just changes', (tester) async {
      await tester.pumpWidget(
          _app(const AnimatedCount(value: 3, style: TextStyle()), calm: true));
      await tester.pumpWidget(
          _app(const AnimatedCount(value: 4, style: TextStyle()), calm: true));
      await tester.pump();

      expect(find.text('3'), findsNothing);
      expect(find.text('4'), findsOneWidget);
    });
  });

  testWidgets('a label swaps with a fade: FOLLOW, then UNFOLLOW',
      (tester) async {
    await tester.pumpWidget(_app(const SwapLabel('FOLLOW')));
    await tester.pumpWidget(_app(const SwapLabel('UNFOLLOW')));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.text('FOLLOW'), findsOneWidget);
    expect(find.text('UNFOLLOW'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('FOLLOW'), findsNothing);
    expect(find.text('UNFOLLOW'), findsOneWidget);
  });

  testWidgets('less motion: the label just changes, and nothing breaks',
      (tester) async {
    await tester.pumpWidget(_app(const SwapLabel('FOLLOW'), calm: true));
    await tester.pumpWidget(_app(const SwapLabel('UNFOLLOW'), calm: true));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('FOLLOW'), findsNothing);
    expect(find.text('UNFOLLOW'), findsOneWidget);
  });

  group('AppToggle', () {
    testWidgets('a switch is felt, and slides on the shared timing',
        (tester) async {
      final felt = _feel(tester);
      var on = false;
      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) => _app(AppToggle(
          value: on,
          onChanged: (v) => setState(() => on = v),
        )),
      ));

      await tester.tap(find.byType(AppToggle));
      await tester.pump();
      expect(on, isTrue);
      expect(felt, ['HapticFeedbackType.selectionClick']);
      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      expect(align.duration, Motion.medium);
      expect(align.curve, Motion.curve);
    });

    testWidgets('less motion: it switches at once', (tester) async {
      await tester.pumpWidget(_app(
        AppToggle(value: true, onChanged: (_) {}),
        calm: true,
      ));
      expect(tester.widget<AnimatedAlign>(find.byType(AnimatedAlign)).duration,
          Duration.zero);
    });
  });
}

/// Accessibility features for a test: only the flags a test sets.
class _Features implements AccessibilityFeatures {
  const _Features(
      {this.accessibleNavigation = false, this.reduceMotion = false});

  @override
  final bool accessibleNavigation;
  @override
  final bool reduceMotion;

  @override
  bool get boldText => false;
  @override
  bool get disableAnimations => false;
  @override
  bool get highContrast => false;
  @override
  bool get invertColors => false;
  @override
  bool get onOffSwitchLabels => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}
