import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The home-screen widgets use the app's own font files (docs/HOME_WIDGETS.md,
/// "Fonts"): iOS copies them from assets/fonts/ into the widget extension,
/// Android reads Bebas Neue from the app's Flutter assets. A file renamed or
/// moved would quietly put the system font back; these hold the three places
/// to the same files.
void main() {
  const fontsDir = 'assets/fonts';
  const dmSans = 'DMSans-VariableFont_opsz,wght.ttf';
  const bebas = 'BebasNeue-Regular.ttf';

  test('the files are in assets/fonts and pubspec bundles them', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final file in [dmSans, bebas]) {
      expect(File('$fontsDir/$file').existsSync(), isTrue, reason: file);
      expect(pubspec, contains('asset: $fontsDir/$file'), reason: file);
    }
  });

  test(
      'iOS: the extension registers both (UIAppFonts) and the Xcode script '
      'copies both', () {
    final plist = File('ios/NextUpWidget/Info.plist').readAsStringSync();
    final fonts =
        RegExp(r'<key>UIAppFonts</key>\s*<array>(.*?)</array>', dotAll: true)
            .firstMatch(plist);
    expect(fonts, isNotNull);
    final listed = [
      for (final m
          in RegExp(r'<string>([^<]+)</string>').allMatches(fonts![1]!))
        m[1]!
    ];
    expect(listed, unorderedEquals([dmSans, bebas]));

    final script = File('tool/ios_add_widget_extension.rb').readAsStringSync();
    expect(script, contains("FONTS_DIR = '../assets/fonts'"));
    expect(script, contains('FONTS = %w[$dmSans $bebas]'));

    final project =
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    for (final file in [dmSans, bebas]) {
      expect(project, contains('path = "../assets/fonts/$file"'), reason: file);
      expect(project, contains('$file in Resources'), reason: file);
    }

    final swift = File('ios/NextUpWidget/WidgetStyle.swift').readAsStringSync();
    expect(swift, contains('static let files = ["$dmSans", "$bebas"]'));
    expect(swift, contains('static let textFamily = "DM Sans"'));
    expect(swift, contains('static let displayFamily = "Bebas Neue"'));
  });

  test('Android: the widget reads Bebas Neue from the Flutter assets', () {
    final kotlin = File(
            'android/app/src/main/kotlin/app/myotherapp/com/widget/WidgetType.kt')
        .readAsStringSync();
    expect(
        kotlin,
        contains(
            'const val DISPLAY_ASSET = "flutter_assets/$fontsDir/$bebas"'));
  });
}
