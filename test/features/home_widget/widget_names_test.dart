import 'dart:io';

import 'package:finnet/features/home_widget/data/networking_store.dart';
import 'package:finnet/features/home_widget/data/next_up_store.dart';
import 'package:finnet/features/home_widget/domain/networking.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app writes each widget's JSON under a key and redraws it by its kind
/// (iOS) and provider (Android); the native widgets read the same key and
/// fall back to the same links. Those names live in three languages: these
/// hold them together.
void main() {
  String read(String path) => File(path).readAsStringSync();
  const kotlin = 'android/app/src/main/kotlin/app/myotherapp/com/widget';
  const swift = 'ios/NextUpWidget';

  test('Networking: the data key, the kind and the provider match', () {
    final data = read('$kotlin/NetworkingData.kt');
    expect(data, contains('const val DATA_KEY = "${NetworkingKind.dataKey}"'));
    expect(read('$swift/NetworkingData.swift'),
        contains('static let dataKey = "${NetworkingKind.dataKey}"'));
    expect(read('$swift/NetworkingWidget.swift'),
        contains('let kind = "${NetworkingKind.iOSKind}"'));
    expect(read('$swift/WidgetBundle.swift'), contains('NetworkingWidget()'));

    final provider = NetworkingKind.androidProvider.split('.').last;
    expect(File('$kotlin/$provider.kt').existsSync(), isTrue);
    expect(read('android/app/src/main/AndroidManifest.xml'),
        contains('android:name=".widget.$provider"'));
  });

  test('Networking: the native fallbacks are the links the app writes', () {
    final data = read('$kotlin/NetworkingData.kt');
    final swiftData = read('$swift/NetworkingData.swift');
    for (final (kotlinName, swiftName, key) in [
      ('MY_QR_LINK', 'myQrLink', 'qr'),
      ('SCAN_LINK', 'scanLink', 'scan'),
      ('NETWORK_LINK', 'networkLink', 'network'),
    ]) {
      final link = networkingLinks[key]!;
      expect(data, contains('const val $kotlinName = "$link"'), reason: key);
      expect(swiftData, contains('static let $swiftName = "$link"'),
          reason: key);
    }
  });

  test('Next up: the data key, the kind and the provider match', () {
    expect(read('$kotlin/NextUpData.kt'),
        contains('const val DATA_KEY = "${NextUpKind.dataKey}"'));
    expect(read('$swift/NextUpData.swift'),
        contains('static let dataKey = "${NextUpKind.dataKey}"'));
    expect(read('$swift/NextUpWidget.swift'),
        contains('let kind = "${NextUpKind.iOSKind}"'));
    final provider = NextUpKind.androidProvider.split('.').last;
    expect(read('android/app/src/main/AndroidManifest.xml'),
        contains('android:name=".widget.$provider"'));
  });

  test('Networking stays off the lock screen', () {
    final info =
        read('android/app/src/main/res/xml/networking_widget_info.xml');
    expect(info, contains('android:widgetCategory="home_screen"'));
    expect(info, isNot(contains('keyguard')));
    final widget = read('$swift/NetworkingWidget.swift');
    expect(
        widget, contains('.supportedFamilies([.systemSmall, .systemMedium])'));
    expect(widget, isNot(contains('accessory')));
    expect(widget, contains('privacySensitive()'));
  });
}
