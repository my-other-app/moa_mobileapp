import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The iOS build is an iPhone app that stays upright. These are platform
/// settings, not Dart: read from the files Xcode builds from, so a change
/// to either shows up here.
void main() {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  final project =
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  /// The <string> entries of the array under [key] in Info.plist, or null
  /// when the key is absent.
  List<String>? plistArray(String key) {
    final match = RegExp(
      '<key>${RegExp.escape(key)}</key>\\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    if (match == null) return null;
    return RegExp('<string>(.*?)</string>')
        .allMatches(match.group(1)!)
        .map((m) => m.group(1)!)
        .toList();
  }

  test('portrait only', () {
    expect(plistArray('UISupportedInterfaceOrientations'),
        ['UIInterfaceOrientationPortrait']);
  });

  test('no iPad orientations: there is no iPad app', () {
    expect(plistArray('UISupportedInterfaceOrientations~ipad'), isNull);
  });

  test('every build configuration targets the iPhone alone', () {
    final families = RegExp(r'TARGETED_DEVICE_FAMILY = ([^;]+);')
        .allMatches(project)
        .map((m) => m.group(1)!.replaceAll('"', '').trim())
        .toList();

    // Debug, Release and Profile, at every level that sets it.
    expect(families, isNotEmpty);
    expect(families.toSet(), {'1'}, reason: '1 is iPhone; 2 would be iPad');
  });
}
