import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// What the app tells Apple and Google it collects, kept true to the code.
///
/// The privacy manifest is what App Review compares the App Privacy answers
/// against (docs/RELEASE_1.1.0.md §9, §10). Profile photos came in (camera or
/// library, `photo_picker.dart`) while the manifest still said no photos; and
/// the advertising ID went out while a draft still declared it.
void main() {
  final manifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
  final android =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final plist = File('ios/Runner/Info.plist').readAsStringSync();

  /// Each collected data type, with its "linked" and "tracking" flags.
  Map<String, ({bool linked, bool tracking, List<String> purposes})>
      collected() {
    final section = RegExp(
      '<key>NSPrivacyCollectedDataTypes</key>\\s*<array>(.*?)</array>\\s*<key>NSPrivacyAccessedAPITypes',
      dotAll: true,
    ).firstMatch(manifest)!.group(1)!;
    final out =
        <String, ({bool linked, bool tracking, List<String> purposes})>{};
    for (final entry
        in RegExp(r'<dict>(.*?)</dict>', dotAll: true).allMatches(section)) {
      final body = entry.group(1)!;
      String? after(String key) => RegExp(
            '<key>$key</key>\\s*<(true|false)/>',
          ).firstMatch(body)?.group(1);
      final type = RegExp(
        r'<key>NSPrivacyCollectedDataType</key>\s*<string>(.*?)</string>',
      ).firstMatch(body)!.group(1)!;
      out[type] = (
        linked: after('NSPrivacyCollectedDataTypeLinked') == 'true',
        tracking: after('NSPrivacyCollectedDataTypeTracking') == 'true',
        purposes:
            RegExp(r'<string>(NSPrivacyCollectedDataTypePurpose\w+)</string>')
                .allMatches(body)
                .map((m) => m.group(1)!)
                .toList(),
      );
    }
    return out;
  }

  test('declares the profile photo, linked to the person, for the app itself',
      () {
    final photos = collected()['NSPrivacyCollectedDataTypePhotosorVideos'];
    expect(photos, isNotNull,
        reason: 'a profile photo is uploaded from the camera or library');
    expect(photos!.linked, isTrue);
    expect(photos.tracking, isFalse);
    expect(
        photos.purposes, ['NSPrivacyCollectedDataTypePurposeAppFunctionality']);
    // The pickers it comes from are explained to the person.
    expect(plist, contains('<key>NSCameraUsageDescription</key>'));
    expect(plist, contains('<key>NSPhotoLibraryUsageDescription</key>'));
  });

  test('tracks nobody and declares no advertising data', () {
    expect(
        RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(manifest),
        isTrue);
    final types = collected();
    expect(types.keys,
        isNot(contains('NSPrivacyCollectedDataTypeAdvertisingData')));
    expect(types.values.where((t) => t.tracking), isEmpty);
    expect(
        types.values.expand((t) => t.purposes),
        isNot(contains(
            'NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising')));
  });

  test('declares product interaction as linked: the server keeps event views',
      () {
    expect(collected()['NSPrivacyCollectedDataTypeProductInteraction']?.linked,
        isTrue);
  });

  test('the Android app has no advertising ID to declare', () {
    for (final permission in [
      'com.google.android.gms.permission.AD_ID',
      'android.permission.ACCESS_ADSERVICES_AD_ID',
    ]) {
      expect(
          RegExp('<uses-permission android:name="${RegExp.escape(permission)}" tools:node="remove"/>')
              .hasMatch(android),
          isTrue,
          reason: '$permission must be removed');
    }
    expect(
        RegExp(r'android:name="google_analytics_adid_collection_enabled"\s*android:value="false"')
            .hasMatch(android),
        isTrue);
  });

  test('the drafted store answers say the same', () {
    final release = File('docs/RELEASE_1.1.0.md').readAsStringSync();
    expect(
        release,
        contains(
            'User Content → Photos or Videos | Yes | Yes | No | App Functionality'));
    expect(release, contains('Photos and videos → Photos | Yes'));
    expect(
        release, isNot(contains('advertising ID through Firebase Analytics')));
    expect(release, isNot(contains('avatars are picked from presets')));
  });
}
