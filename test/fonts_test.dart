import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Families declared in pubspec.yaml's `fonts:` section.
Set<String> _declaredFamilies() {
  final pubspec = File('pubspec.yaml').readAsLinesSync();
  final family = RegExp(r'^\s*-\s*family:\s*(.+?)\s*$');
  return {
    for (final line in pubspec)
      if (!line.trimLeft().startsWith('#') && family.hasMatch(line))
        family.firstMatch(line)!.group(1)!.replaceAll(RegExp('["\']'), ''),
  };
}

/// Every literal `fontFamily:` in lib/.
Set<String> _usedFamilies() {
  final used = <String>{};
  final literal = RegExp(r'''fontFamily:\s*['"]([^'"]+)['"]''');
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    for (final m in literal.allMatches(file.readAsStringSync())) {
      used.add(m.group(1)!);
    }
  }
  return used;
}

void main() {
  test('every font family the code names is declared', () {
    // 'DM Sans' and 'Bebas Neue' were used ~100 times without being
    // declared, so that text quietly rendered in the system font.
    //
    // 'Jaro' (onboarding_initial_page.dart, in auth) has no font file in
    // assets/fonts at all, so it cannot be declared from here; it is the
    // one known gap, listed so that any new undeclared family still fails.
    const knownMissing = {'Jaro'};
    final missing = _usedFamilies()
        .difference(_declaredFamilies())
        .difference(knownMissing);
    expect(missing, isEmpty, reason: 'undeclared font families: $missing');
  });

  test('both spellings of each family point at the same file', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    String assetOf(String family) {
      final at = pubspec.indexOf('- family: $family\n');
      expect(at, isNot(-1), reason: '$family is not declared');
      return RegExp(r'asset:\s*(\S+)')
          .firstMatch(pubspec.substring(at))!
          .group(1)!;
    }

    expect(assetOf('DM Sans'), assetOf('DMSans'));
    expect(assetOf('Bebas Neue'), assetOf('BebasNeue'));
    expect(File(assetOf('DMSans')).existsSync(), isTrue);
    expect(File(assetOf('BebasNeue')).existsSync(), isTrue);
  });

  testWidgets('the variable DM Sans renders real weights from one file',
      (tester) async {
    final bytes =
        File('assets/fonts/DMSans-VariableFont_opsz,wght.ttf').readAsBytesSync();
    final loader = FontLoader('DMSansWeightProbe')
      ..addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    await loader.load();

    double width(FontWeight weight, {List<ui.FontVariation>? axes}) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Hamburgefonstiv',
          style: TextStyle(
            fontFamily: 'DMSansWeightProbe',
            fontSize: 40,
            fontWeight: weight,
            fontVariations: axes,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      return painter.width;
    }

    // Bold sets wider than regular, exactly as the wght axis at 700 does:
    // the engine maps fontWeight onto the axis, so one file is enough.
    expect(width(FontWeight.w700), greaterThan(width(FontWeight.w400)));
    expect(
      width(FontWeight.w700),
      width(FontWeight.w400, axes: const [ui.FontVariation('wght', 700)]),
    );
  });
}
