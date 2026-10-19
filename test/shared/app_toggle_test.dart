import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/widgets/app_toggle.dart';
import 'package:finnet/shared/widgets/settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Holds the value the way a screen does.
class _Harness extends StatefulWidget {
  const _Harness({this.initial = false, this.enabled = true});

  final bool initial;
  final bool enabled;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late bool value = widget.initial;
  final told = <bool>[];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: AppToggle(
            value: value,
            onChanged: !widget.enabled
                ? null
                : (on) => setState(() {
                      told.add(on);
                      value = on;
                    }),
          ),
        ),
      ),
    );
  }
}

/// The track: the pill around the knob.
BoxDecoration _track(WidgetTester tester) => tester
    .widget<AnimatedContainer>(find
        .descendant(
            of: find.byType(AppToggle),
            matching: find.byType(AnimatedContainer))
        .first)
    .decoration! as BoxDecoration;

BoxDecoration _knob(WidgetTester tester) => tester
    .widget<AnimatedContainer>(find
        .descendant(
            of: find.byType(AppToggle),
            matching: find.byType(AnimatedContainer))
        .last)
    .decoration! as BoxDecoration;

void main() {
  group('the toggle', () {
    testWidgets('on: the yellow pill with an ink edge, the ink knob right',
        (tester) async {
      await tester.pumpWidget(const _Harness(initial: true));

      expect(tester.getSize(find.byType(AppToggle)), const Size(52, 28));
      expect(_track(tester).color, AppColors.paleYellow);
      expect((_track(tester).border! as Border).top.color, AppColors.ink);
      expect(_knob(tester).color, AppColors.ink);
      final knob = find
          .descendant(
              of: find.byType(AppToggle),
              matching: find.byType(AnimatedContainer))
          .last;
      expect(tester.getCenter(knob).dx,
          greaterThan(tester.getCenter(find.byType(AppToggle)).dx));
    });

    testWidgets('off: white with a grey edge, the grey knob left',
        (tester) async {
      await tester.pumpWidget(const _Harness());

      expect(_track(tester).color, Colors.white);
      final edge = (_track(tester).border! as Border).top.color;
      expect(edge, isNot(AppColors.ink));
      expect(_knob(tester).color, isNot(AppColors.ink));
      final knob = find
          .descendant(
              of: find.byType(AppToggle),
              matching: find.byType(AnimatedContainer))
          .last;
      expect(tester.getCenter(knob).dx,
          lessThan(tester.getCenter(find.byType(AppToggle)).dx));
      // Not Material's switch.
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('a tap calls back with the other value, and it moves',
        (tester) async {
      await tester.pumpWidget(const _Harness());
      final state = tester.state<_HarnessState>(find.byType(_Harness));

      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();
      expect(state.told, [true]);
      expect(_track(tester).color, AppColors.paleYellow);

      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();
      expect(state.told, [true, false]);
      expect(_track(tester).color, Colors.white);
    });

    testWidgets('without onChanged it does nothing', (tester) async {
      await tester.pumpWidget(const _Harness(enabled: false));
      final state = tester.state<_HarnessState>(find.byType(_Harness));

      await tester.tap(find.byType(AppToggle));
      await tester.pumpAndSettle();

      expect(state.told, isEmpty);
      expect(_track(tester).color, Colors.white);
    });

    testWidgets('a screen reader hears a switch, and its state',
        (tester) async {
      await tester.pumpWidget(const _Harness(initial: true));

      expect(
        tester.getSemantics(find.byType(AppToggle)),
        isSemantics(hasToggledState: true, isToggled: true, hasTapAction: true),
      );
    });
  });

  group('a settings row', () {
    testWidgets('its emoji in a grey circle, the name, nothing else',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsRow(
              emoji: '🚨', label: 'Help Centre', onTap: () => taps++),
        ),
      ));

      final circle = find.byKey(const ValueKey('settings-row-emoji'));
      expect(tester.getSize(circle), const Size(48, 48));
      expect(
          (tester.widget<Container>(circle).decoration! as BoxDecoration).color,
          AppColors.softGrey);
      expect(find.text('🚨'), findsOneWidget);
      expect(find.text('Help Centre'), findsOneWidget);
      expect(tester.getSize(find.byType(SettingsRow)).height, 64);
      expect(find.byType(Icon), findsNothing);
      expect(find.byType(AppToggle), findsNothing);

      await tester.tap(find.byType(SettingsRow));
      expect(taps, 1);
    });

    testWidgets('a switch row: the toggle at the right, the row flips it',
        (tester) async {
      final told = <bool>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SettingsRow(
            emoji: '📈',
            label: 'Usage Analytics',
            value: true,
            onChanged: told.add,
          ),
        ),
      ));

      expect(find.byType(AppToggle), findsOneWidget);
      expect(tester.getTopRight(find.byType(AppToggle)).dx,
          tester.getTopRight(find.byType(SettingsRow)).dx - 16);

      await tester.tap(find.text('Usage Analytics'));
      await tester.tap(find.byType(AppToggle));
      expect(told, [false, false]);
      expect(
        tester.getSemantics(find.byType(SettingsRow)),
        isSemantics(
            label: 'Usage Analytics',
            hasToggledState: true,
            isToggled: true,
            hasTapAction: true),
      );
    });
  });
}
