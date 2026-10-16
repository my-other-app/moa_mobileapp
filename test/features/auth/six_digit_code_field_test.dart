import 'package:finnet/features/auth/presentation/widgets/six_digit_code_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _box(WidgetTester tester, int i) {
  final text = tester.widget<Text>(find.descendant(
    of: find.byKey(ValueKey('code-box-$i')),
    matching: find.byType(Text),
  ));
  return text.data ?? '';
}

void main() {
  late TextEditingController controller;
  late List<String> completed;

  Future<void> pump(WidgetTester tester, {bool enabled = true}) async {
    controller = TextEditingController();
    addTearDown(controller.dispose);
    completed = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: SixDigitCodeField(
            controller: controller,
            enabled: enabled,
            onCompleted: completed.add,
          ),
        ),
      ),
    ));
  }

  const input = ValueKey('code-input');

  testWidgets('each digit lands in its own box; the sixth submits',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(input), '12');
    await tester.pump();
    expect([for (var i = 0; i < 6; i++) _box(tester, i)],
        ['1', '2', '', '', '', '']);
    expect(completed, isEmpty);

    await tester.enterText(find.byKey(input), '123456');
    await tester.pump();
    expect([for (var i = 0; i < 6; i++) _box(tester, i)],
        ['1', '2', '3', '4', '5', '6']);
    expect(completed, ['123456']);
  });

  testWidgets('a pasted code keeps only its digits and submits at once',
      (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(input), 'Your code: 482 913.');
    await tester.pump();

    expect(controller.text, '482913');
    expect(completed, ['482913']);
  });

  testWidgets('more than six digits are cut to six', (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(input), '12345678');
    await tester.pump();

    expect(controller.text, '123456');
    expect(completed, ['123456']);
  });

  testWidgets('letters never get in', (tester) async {
    await pump(tester);

    await tester.enterText(find.byKey(input), 'abc');
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(completed, isEmpty);
  });

  test('the formatter on its own', () {
    const formatter = CodeDigitsFormatter();
    final out = formatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(text: '12-34 56 78'),
    );
    expect(out.text, '123456');
    expect(out.selection.baseOffset, 6);
  });
}
