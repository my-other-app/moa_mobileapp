import 'dart:io';

import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/home_widget/data/widget_photos.dart';
import 'package:finnet/features/home_widget/domain/networking.dart';
import 'package:finnet/features/network/domain/network_links.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase B's pieces live in three languages -- the JSON the app writes and
/// the widgets read, the photos' keys and folder, the pages the controls
/// and tiles open, the iOS versions each piece needs. These hold them
/// together (docs/HOME_WIDGETS.md).
void main() {
  String read(String path) => File(path).readAsStringSync();
  const kotlin = 'android/app/src/main/kotlin/app/myotherapp/com';
  const res = 'android/app/src/main/res';
  const swift = 'ios/NextUpWidget';
  const manifest = 'android/app/src/main/AndroidManifest.xml';

  group('"Recently met"', () {
    test('the fields the app writes are the ones both widgets read', () {
      final kt = read('$kotlin/widget/NetworkingData.kt');
      final sw = read('$swift/NetworkingData.swift');
      expect(kt, contains('optJSONArray("met")'));
      expect(kt, contains('has("no_note")'));
      expect(sw, contains('case noNote = "no_note"'));
      expect(sw, contains('case network, met'));
      for (final field in ['name', 'initials', 'colour', 'event', 'link']) {
        expect(kt,
            anyOf(contains('optString("$field")'), contains('optInt("$field"')),
            reason: field);
        expect(sw, contains('let $field: '), reason: field);
      }
      expect(kt, contains('optString("photo")'));
      expect(sw, contains('let photo: String?'));
    });

    test('a photo\'s key and folder are the same on every side', () {
      final key = widgetPhotoKey(5);
      expect(key, 'networking_photo_5');
      final prefix = key.substring(0, key.length - 1);
      expect(read('$kotlin/widget/NetworkingData.kt'),
          contains('const val PHOTO_KEY_PREFIX = "$prefix"'));
      expect(read('$swift/WidgetPhotoFiles.swift'),
          contains('key.hasPrefix("$prefix")'));
      // home_widget's own folder, in the app's files (Android) and the App
      // Group's container (iOS).
      expect(read('$kotlin/widget/WidgetPhotos.kt'),
          contains('const val FOLDER = "home_widget"'));
      expect(read('$swift/WidgetPhotoFiles.swift'),
          contains('static let folder = "home_widget"'));
      expect(HomeWidgetPhotoStore.indexKey, isNot(startsWith(prefix)));
    });

    test('four colours, the same on every side', () {
      expect(recentlyMetColours, 4);
      for (var i = 0; i < recentlyMetColours; i++) {
        expect(File('$res/drawable/widget_met_circle_$i.xml').existsSync(),
            isTrue);
        expect(read('$res/values/widget_networking.xml'),
            contains('name="networking_met_fill_$i"'));
      }
      expect(read('$swift/WidgetStyle.swift'),
          contains('static func circle(_ index: Int'));
    });
  });

  group('Scan and My QR: controls (iOS 18) and tiles (Android)', () {
    final pages = {
      'scan': savePersonScanLocation,
      'my_qr': myQrLocation,
    };

    test('open the same pages as the icon\'s shortcuts, signing in first', () {
      final shortcuts = read('$res/values/app_shortcuts.xml');
      final intents = read('$swift/ControlIntents.swift');
      for (final MapEntry(key: id, value: location) in pages.entries) {
        final link = RegExp('name="shortcut_${id}_link"[^>]*>([^<]+)<')
            .firstMatch(shortcuts)![1]!;
        expect(appLocationForLink(Uri.parse(link)), location, reason: id);
        expect(needsAccount(location), isTrue, reason: id);
        expect(intents, contains('URL(string: "$link")!'), reason: id);
      }
      final tiles = read('$kotlin/tiles/PageTiles.kt');
      expect(tiles, contains('R.string.shortcut_scan_link'));
      expect(tiles, contains('R.string.shortcut_my_qr_link'));
    });

    test('Android: two tiles, bound only by the system, with their icons', () {
      final xml = read(manifest);
      for (final (service, icon) in [
        ('ScanTileService', 'ic_tile_scan'),
        ('MyQrTileService', 'ic_tile_qr'),
      ]) {
        final block = RegExp(
                '<service\\s+android:name="\\.tiles\\.$service".*?</service>',
                dotAll: true)
            .firstMatch(xml)?[0];
        expect(block, isNotNull, reason: service);
        expect(block, contains('android.permission.BIND_QUICK_SETTINGS_TILE'));
        expect(block, contains('android.service.quicksettings.action.QS_TILE'));
        expect(block, contains('@drawable/$icon'));
        expect(File('$res/drawable/$icon.xml').existsSync(), isTrue);
      }
      final tiles = read('$kotlin/tiles/PageTiles.kt');
      // Android 14's PendingIntent, the older Intent; unlock first.
      expect(tiles, contains('UPSIDE_DOWN_CAKE'));
      expect(tiles, contains('PendingIntent.FLAG_IMMUTABLE'));
      expect(tiles, contains('unlockAndRun'));
    });

    test('iOS: controls from iOS 18, opening the app (unlocked) on the page',
        () {
      final bundle = read('$swift/WidgetBundle.swift');
      expect(
          bundle,
          matches(RegExp(r'if #available\(iOS 18\.0, \*\) \{\s*'
              r'ScanControl\(\)\s*MyQrControl\(\)\s*\}')));
      final controls = read('$swift/Controls.swift');
      expect(
          controls, contains('ControlWidgetButton(action: OpenScanIntent())'));
      expect(
          controls, contains('ControlWidgetButton(action: OpenMyQrIntent())'));
      expect(controls, contains('systemImage: "qrcode.viewfinder"'));
      expect(controls, contains('systemImage: "qrcode"'));
      final intents = read('$swift/ControlIntents.swift');
      expect('static let openAppWhenRun = true'.allMatches(intents).length, 2);
      expect('.requiresAuthentication'.allMatches(intents).length, 2);
      // The app runs them, and hands the page to Flutter's deep linking.
      expect(read('ios/Runner/AppDelegate.swift'),
          contains('AppLinkHandoff.opener = '));
    });
  });

  group('the iPhone\'s widget extension', () {
    test('lock-screen pieces from iOS 16; My QR there draws no code', () {
      final nextUp = read('$swift/NextUpWidget.swift');
      expect(nextUp, contains('.systemLarge'));
      expect(
          nextUp,
          matches(
              RegExp(r'#available\(iOSApplicationExtension 16\.0, \*\) \{\s*'
                  r'families \+= \[\.accessoryRectangular, \.accessoryInline, '
                  r'\.accessoryCircular\]')));
      final bundle = read('$swift/WidgetBundle.swift');
      expect(
          bundle,
          matches(RegExp(
              r'if #available\(iOS 16\.1, \*\) \{\s*MyQrLockWidget\(\)')));
      final lock = read('$swift/MyQrLockWidget.swift');
      expect(lock, contains('.supportedFamilies([.accessoryCircular])'));
      expect(lock, contains('NetworkingData.myQrLink'));
      expect(lock, isNot(contains('QRCode')));
      final views = read('$swift/NextUpLockScreen.swift');
      expect(views, isNot(contains('QRCode')));
      expect(views, isNot(contains('QRTile')));
    });

    test('every Swift file is in the Xcode script; the intents in the app too',
        () {
      final script = read('tool/ios_add_widget_extension.rb');
      final listed =
          RegExp(r'^SOURCES = %w\[(.*?)\]', dotAll: true, multiLine: true)
              .firstMatch(script)![1]!
              .split(RegExp(r'\s+'))
              .where((f) => f.isNotEmpty)
              .toSet();
      final files = Directory(swift)
          .listSync()
          .map((f) => f.uri.pathSegments.last)
          .where((f) => f.endsWith('.swift'))
          .toSet();
      expect(listed, files);
      expect(
          script,
          contains(
              'APP_SOURCES = %w[ControlIntents.swift EventDayAttributes.swift]'));
      expect(script, contains('RUNNER_SOURCES = %w[EventDayActivities.swift]'));
      final project = read('ios/Runner.xcodeproj/project.pbxproj');
      for (final shared in [
        'ControlIntents.swift',
        'EventDayAttributes.swift'
      ]) {
        expect(
            '/* $shared in Sources */ = {isa = PBXBuildFile'
                .allMatches(project)
                .length,
            2,
            reason: '$shared: built into the extension and the app');
      }
      expect(
          '/* EventDayActivities.swift in Sources */ = {isa = PBXBuildFile'
              .allMatches(project)
              .length,
          1,
          reason: 'the app alone starts the Live Activity');
    });
  });
}
