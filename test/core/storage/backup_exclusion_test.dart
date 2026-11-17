import 'dart:io';

import 'package:finnet/core/storage/backup_exclusion.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel(BackupExclusion.channelName);
  late List<MethodCall> calls;
  late Directory support;

  setUp(() {
    calls = [];
    support = Directory.systemTemp.createTempSync('backup_exclusion');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    support.deleteSync(recursive: true);
  });

  group('on an iPhone', () {
    final exclusion = BackupExclusion(supported: true);

    test('marks the path through the app\'s channel', () async {
      await exclusion.exclude('/app/Library/Application Support/gate_queue');

      expect(calls.single.method, 'exclude');
      expect(calls.single.arguments,
          '/app/Library/Application Support/gate_queue');
    });

    test('at start-up, marks the personal entries that are there', () async {
      Directory('${support.path}/gate_queue').createSync();
      File('${support.path}/network_saves.json').writeAsStringSync('{}');
      // Not personal: the picture index and the privacy choices stay in.
      File('${support.path}/moaImagesPublic.db').writeAsStringSync('');
      File('${support.path}/privacy_choices.json').writeAsStringSync('{}');

      await exclusion.excludeKnown(support: support);

      expect(calls.map((c) => c.arguments), [
        '${support.path}/gate_queue',
        '${support.path}/network_saves.json',
      ]);
    });

    test('a refusal is swallowed: the file is only backed up as before',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'exclude_failed');
      });

      await expectLater(exclusion.exclude('/x'), completes);
    });

    test('a build without the channel is no error either', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      await expectLater(exclusion.exclude('/x'), completes);
    });
  });

  test('elsewhere nothing is sent: Android leaves them out by its rules',
      () async {
    final exclusion = BackupExclusion(supported: false);
    Directory('${support.path}/documents').createSync();

    await exclusion.exclude('/x');
    await exclusion.excludeKnown(support: support);

    expect(calls, isEmpty);
  });

  group('Android backup rules', () {
    // Each file the app keeps personal data in, by domain, in both rule
    // files and both of the newer file's sections.
    const excluded = [
      ('sharedpref', 'FlutterSecureStorage.xml'),
      ('sharedpref', 'FlutterSecureKeyStorage.xml'),
      ('file', 'gate_queue'),
      ('file', 'documents'),
      ('file', 'network_saves.json'),
      // What the home-screen widgets show (home_widget's preferences).
      ('sharedpref', 'HomeWidgetPreferences.xml'),
      // The Networking widget's photos, when turned on (home_widget's
      // files; on an iPhone they are in the App Group's container).
      ('file', 'home_widget'),
      ('root', 'app_flutter'),
    ];

    List<(String, String)> excludesIn(String xml) => [
          for (final m
              in RegExp(r'<exclude\s+domain="([^"]+)"\s+path="([^"]+)"\s*/>')
                  .allMatches(xml))
            (m[1]!, m[2]!),
        ];

    test('Android 11 and earlier', () {
      final xml = File('android/app/src/main/res/xml/backup_rules.xml')
          .readAsStringSync();
      expect(excludesIn(xml), unorderedEquals(excluded));
    });

    test('Android 12 and later: cloud backup and phone-to-phone transfer', () {
      final xml = File('android/app/src/main/res/xml/data_extraction_rules.xml')
          .readAsStringSync();
      for (final section in ['cloud-backup', 'device-transfer']) {
        final body =
            RegExp('<$section>(.*?)</$section>', dotAll: true).firstMatch(xml);
        expect(body, isNotNull, reason: section);
        expect(excludesIn(body![1]!), unorderedEquals(excluded),
            reason: section);
      }
    });

    test('the store\'s entry names match the rules', () {
      expect(BackupExclusion.supportEntries, [
        for (final (domain, path) in excluded)
          if (domain == 'file' && path != 'home_widget') path
      ]);
    });
  });
}
