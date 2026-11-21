import 'dart:async';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/widgets/app_actions_sheet.dart';
import 'package:finnet/shared/widgets/app_chip.dart';
import 'package:finnet/shared/widgets/app_refresh.dart';
import 'package:finnet/shared/widgets/app_select.dart';
import 'package:finnet/shared/widgets/app_share_button.dart';
import 'package:finnet/shared/widgets/app_spinner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

AppSpinnerPainter _painterOf(WidgetTester tester, Finder spinner) => tester
    .widget<CustomPaint>(
        find.descendant(of: spinner, matching: find.byType(CustomPaint)))
    .painter! as AppSpinnerPainter;

void main() {
  group('AppSpinner', () {
    testWidgets('fills the box it is in, and is 28 across alone',
        (tester) async {
      await tester.pumpWidget(_app(const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox.square(dimension: 16, child: AppSpinner(key: Key('small'))),
          AppSpinner(key: Key('alone')),
        ]),
      )));
      expect(
          tester.getSize(find.byKey(const Key('small'))), const Size(16, 16));
      expect(tester.getSize(find.byKey(const Key('alone'))),
          const Size(AppSpinner.defaultSize, AppSpinner.defaultSize));
    });

    testWidgets(
        'the ink arc with round ends on a faint ring of it; white on '
        'a dark fill', (tester) async {
      await tester.pumpWidget(_app(const Column(children: [
        AppSpinner(key: Key('ink')),
        AppSpinner(key: Key('white'), color: Colors.white),
      ])));
      final ink = _painterOf(tester, find.byKey(const Key('ink')));
      expect(ink.arc, AppColors.ink);
      expect(ink.cap, StrokeCap.round);
      expect(ink.ring.a, lessThan(0.2));
      final white = _painterOf(tester, find.byKey(const Key('white')));
      expect(white.arc, Colors.white);
      expect(white.ring.r, closeTo(1, 0.01));
    });

    testWidgets('it turns, and stretches unless less motion is asked for',
        (tester) async {
      await tester.pumpWidget(_app(const AppSpinner()));
      final t0 = _painterOf(tester, find.byType(AppSpinner)).t;
      await tester.pump(const Duration(milliseconds: 300));
      expect(_painterOf(tester, find.byType(AppSpinner)).t, isNot(t0));
      expect(AppSpinnerPainter.sweepAt(0), closeTo(0.1, 1e-9));
      expect(AppSpinnerPainter.sweepAt(0.25), closeTo(0.65, 1e-9));
      expect(AppSpinnerPainter.sweepAt(0.25, steady: true), 0.3);

      await tester.pumpWidget(MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _app(const AppSpinner()),
      ));
      expect(_painterOf(tester, find.byType(AppSpinner)).steady, isTrue);
    });

    testWidgets('with a value: that much of the ring, said as a percentage',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
          _app(const AppSpinner(value: 0.4, semanticsLabel: 'Uploading')));
      expect(_painterOf(tester, find.byType(AppSpinner)).value, 0.4);
      expect(tester.getSemantics(find.byType(AppSpinner)),
          matchesSemantics(label: 'Uploading', value: '40%'));
      semantics.dispose();
    });

    testWidgets('AppLoadingView: the spinner, a line, and "Loading" said',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_app(const AppLoadingView()));
      expect(find.byType(AppSpinner), findsOneWidget);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      await tester.pumpWidget(
          _app(const AppLoadingView(message: 'Reading your tickets…')));
      expect(find.text('Reading your tickets…'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('AppProgressBar: a rounded bar that much of the track',
        (tester) async {
      await tester.pumpWidget(_app(const Center(
        child: SizedBox(width: 200, child: AppProgressBar(value: 0.25)),
      )));
      final fill = find.descendant(
          of: find.byType(AppProgressBar), matching: find.byType(DecoratedBox));
      expect(tester.getSize(fill.last).width, closeTo(50, 0.01));
      expect(tester.getSize(find.byType(AppProgressBar)).height, 4);
    });
  });

  group('AppRefresh', () {
    Widget list(Future<void> Function() onRefresh) => _app(AppRefresh(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [for (var i = 0; i < 40; i++) Text('row $i')],
          ),
        ));

    testWidgets('a pull past the mark refreshes, with the badge spinning',
        (tester) async {
      var refreshed = 0;
      await tester.pumpWidget(list(() async {
        refreshed++;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }));
      expect(find.byType(RefreshIndicator), findsOneWidget);

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('row 2')));
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Pulled: the badge shows, filling.
      final pulled = tester.widget<AppSpinner>(find.descendant(
          of: find.byKey(AppRefresh.badgeKey),
          matching: find.byType(AppSpinner)));
      expect(pulled.value, greaterThan(0));
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(refreshed, 1);
      final spinning = tester.widget<AppSpinner>(find.descendant(
          of: find.byKey(AppRefresh.badgeKey),
          matching: find.byType(AppSpinner)));
      expect(spinning.value, isNull);
      final badge = tester.widget<Container>(find.byKey(AppRefresh.badgeKey));
      expect((badge.decoration! as BoxDecoration).color, AppColors.paleYellow);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('at rest there is no spinner in the tree, before or after',
        (tester) async {
      await tester.pumpWidget(list(() async {}));
      expect(find.byType(AppSpinner), findsNothing);
      unawaited(tester.state<AppRefreshState>(find.byType(AppRefresh)).show());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AppSpinner), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(AppSpinner), findsNothing);
    });

    testWidgets('a short pull does nothing', (tester) async {
      var refreshed = 0;
      await tester.pumpWidget(list(() async => refreshed++));
      await tester.drag(find.text('row 2'), const Offset(0, 40));
      await tester.pumpAndSettle();
      expect(refreshed, 0);
    });

    testWidgets('show() refreshes, as RefreshIndicatorState.show does',
        (tester) async {
      var refreshed = 0;
      await tester.pumpWidget(list(() async => refreshed++));
      unawaited(tester.state<AppRefreshState>(find.byType(AppRefresh)).show());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(refreshed, 1);
    });
  });

  group('the actions sheet', () {
    testWidgets(
        'icon rows; the destructive one red; the current one ticked; '
        'a choice closes it with its value', (tester) async {
      String? chosen;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Center(
          child: AppMenuButton<String>(
            key: const Key('menu'),
            title: 'This person',
            actions: () => const [
              AppAction(value: 'share', label: 'Share', icon: Icons.link),
              AppAction(value: 'sort', label: 'Newest', selected: true),
              AppAction(value: 'off', label: 'Unavailable', enabled: false),
              AppAction(
                  value: 'block',
                  label: 'Block',
                  icon: Icons.block,
                  destructive: true),
            ],
            onSelected: (v) => chosen = v,
          ),
        ),
      )));
      expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('menu'))).height,
          greaterThanOrEqualTo(44));

      await tester.tap(find.byKey(const Key('menu')));
      await tester.pumpAndSettle();
      expect(find.text('THIS PERSON'), findsOneWidget);
      final block = tester.widget<Text>(find.text('Block'));
      expect(block.style!.color, appDestructive);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      for (final row in tester.widgetList<AppActionRow<String>>(
          find.byType(AppActionRow<String>))) {
        expect(row.action.label, isNotEmpty);
      }
      expect(tester.getSize(find.byType(AppActionRow<String>).first).height,
          greaterThanOrEqualTo(56));

      await tester.tap(find.text('Unavailable'));
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      expect(find.text('Share'), findsOneWidget);

      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();
      expect(chosen, 'share');
      expect(find.text('Share'), findsNothing);
    });

    testWidgets('a pill opens it too, and closing it chooses nothing',
        (tester) async {
      var told = 0;
      await tester.pumpWidget(_app(Center(
        child: AppMenuButton<int>(
          tooltip: 'Sort',
          actions: () => const [AppAction(value: 1, label: 'Newest')],
          onSelected: (_) => told++,
          child: const Text('Sort: Newest'),
        ),
      )));
      await tester.tap(find.text('Sort: Newest'));
      await tester.pumpAndSettle();
      expect(find.text('Newest'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(told, 0);
    });
  });

  group('the select field', () {
    const options = [
      AppOption('everyone', 'Everyone', key: Key('opt-everyone')),
      AppOption('met', 'People I saved', key: Key('opt-met')),
      AppOption('nobody', 'Only me', key: Key('opt-nobody')),
    ];

    testWidgets('shows the choice; the sheet ticks it; picking changes it',
        (tester) async {
      var value = 'everyone';
      await tester.pumpWidget(_app(StatefulBuilder(
        builder: (context, setState) => Padding(
          padding: const EdgeInsets.all(16),
          child: AppSelectField<String>(
            key: const Key('field'),
            label: 'Links',
            options: options,
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      )));
      expect(find.text('Everyone'), findsOneWidget);
      expect(find.text('Links'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

      await tester.tap(find.byKey(const Key('field')));
      await tester.pumpAndSettle();
      expect(find.text('LINKS'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.byKey(const Key('opt-met')));
      await tester.pumpAndSettle();
      expect(value, 'met');
      expect(find.text('People I saved'), findsOneWidget);
    });

    testWidgets('searchable: the box filters by label', (tester) async {
      await tester.pumpWidget(_app(Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showAppSelect<String>(context,
                title: 'Visible to', options: options, searchable: true),
            child: const Text('open'),
          ),
        ),
      )));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AppSelectSheet.searchKey), 'saved');
      await tester.pump();
      expect(find.text('People I saved'), findsOneWidget);
      expect(find.text('Everyone'), findsNothing);
    });

    testWidgets('in a form: the validator speaks under it', (tester) async {
      final form = GlobalKey<FormState>();
      await tester.pumpWidget(_app(Form(
        key: form,
        child: AppSelectFormField<String>(
          options: options,
          hint: 'Choose one',
          validator: (v) => v == null ? 'Pick who sees it' : null,
        ),
      )));
      expect(find.text('Choose one'), findsOneWidget);
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Pick who sees it'), findsOneWidget);
    });
  });

  group('AppChip', () {
    testWidgets(
        'soft grey, then pale yellow with an ink edge once chosen; a '
        'tap asks for the other state', (tester) async {
      final semantics = tester.ensureSemantics();
      bool? asked;
      Widget chip(bool selected) => _app(Center(
            child: AppChip(
              key: const Key('chip'),
              label: 'Mutual',
              selected: selected,
              onSelected: (v) => asked = v,
            ),
          ));
      await tester.pumpWidget(chip(false));
      BoxDecoration look() => tester
          .widget<AnimatedContainer>(find.descendant(
              of: find.byKey(const Key('chip')),
              matching: find.byType(AnimatedContainer)))
          .decoration! as BoxDecoration;
      expect(look().color, AppChip.idleFill);
      expect(tester.getSize(find.byKey(const Key('chip'))).height,
          greaterThanOrEqualTo(AppChip.touch));
      await tester.tap(find.byKey(const Key('chip')));
      expect(asked, isTrue);

      await tester.pumpWidget(chip(true));
      await tester.pumpAndSettle();
      expect(look().color, AppChip.chosenFill);
      expect(
          tester.getSemantics(find.byKey(const Key('chip'))),
          matchesSemantics(
            label: 'Mutual',
            isButton: true,
            isEnabled: true,
            hasEnabledState: true,
            isSelected: true,
            hasSelectedState: true,
            hasTapAction: true,
          ));
      semantics.dispose();
    });

    testWidgets('a count after the label', (tester) async {
      await tester.pumpWidget(_app(Center(
          child: AppChip(label: 'DevFest', count: 12, onSelected: (_) {}))));
      expect(find.text('DevFest'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
    });
  });

  testWidgets('AppShareButton: the app share icon, told its own context',
      (tester) async {
    BuildContext? anchor;
    await tester.pumpWidget(_app(Center(
      child: AppShareButton(onPressed: (button) => anchor = button),
    )));
    expect(find.byType(AppShareIcon), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
    await tester.tap(find.byType(AppShareButton));
    expect(anchor, isNotNull);
    final box = anchor!.findRenderObject()! as RenderBox;
    expect(box.size.height, greaterThanOrEqualTo(44));
  });
}
