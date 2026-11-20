import 'dart:io';

import 'package:finnet/shared/utils/share_origin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// share_plus refuses a sheet with no origin inside the screen whenever iOS
/// shows it as a popover (an iPad, and an iPhone since iOS 26), and the
/// refusal is thrown from the tap: the button just does nothing.
void main() {
  const screen = Size(390, 844);

  group('anchoredShareOrigin', () {
    test('a real rect on the screen is kept', () {
      const button = Rect.fromLTWH(24, 600, 342, 50);
      expect(anchoredShareOrigin(button, screen: screen), button);
    });

    test('none, an empty one or one off the screen: the fallback', () {
      final fallback = fallbackShareOrigin(screen: screen);
      expect(fallback.isEmpty, isFalse);
      expect((Offset.zero & screen).contains(fallback.center), isTrue);
      for (final origin in [
        null,
        Rect.zero,
        const Rect.fromLTWH(10, 10, 0, 40),
        const Rect.fromLTWH(-500, -500, 20, 20),
        const Rect.fromLTWH(double.nan, 0, 10, 10),
      ]) {
        expect(anchoredShareOrigin(origin, screen: screen), fallback,
            reason: '$origin');
      }
    });

    test('a rect running off the edge is cut to the screen', () {
      const wide = Rect.fromLTWH(300, 780, 120, 100);
      expect(anchoredShareOrigin(wide, screen: screen),
          const Rect.fromLTRB(300, 780, 390, 844));
    });

    test('with no screen known, still a point', () {
      expect(fallbackShareOrigin(screen: Size.zero),
          const Rect.fromLTWH(0, 0, 1, 1));
    });
  });

  testWidgets("shareOriginOf: the button's rect on the screen", (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
              key: key, width: 120, height: 44, child: const Text('Share')),
        ),
      ),
    ));
    expect(shareOriginOf(key.currentContext), tester.getRect(find.byKey(key)));
    expect(shareOriginOf(null).isEmpty, isFalse);
  });

  test('every share sheet in the app is given somewhere to point', () {
    // A share call without an anchored origin throws on iOS 26 iPhones;
    // this keeps a new one from slipping in.
    final calls = RegExp(r'Share\.share(XFiles)?\(');
    final unanchored = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in calls.allMatches(source)) {
        final call = _callAt(source, match.end - 1);
        if (!call.contains('sharePositionOrigin: anchoredShareOrigin(')) {
          final line = '\n'.allMatches(source.substring(0, match.start)).length;
          unanchored.add('${file.path}:${line + 1}');
        }
      }
    }
    expect(unanchored, isEmpty);
  });
}

/// The text of the call whose `(` is at [open], to its matching `)`.
String _callAt(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '(') depth++;
    if (c == ')' && --depth == 0) return source.substring(open, i + 1);
  }
  return source.substring(open);
}
