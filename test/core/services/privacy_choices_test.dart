import 'dart:io';

import 'package:finnet/core/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what it was told to collect.
class RecordingControl implements CollectionControl {
  final applied = <PrivacyChoices>[];

  @override
  Future<void> applyChoices(PrivacyChoices choices) async {
    applied.add(choices);
  }
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('privacy_choices_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  FilePrivacyChoicesStore store() =>
      FilePrivacyChoicesStore(directory: () async => dir);

  group('the saved choices', () {
    test('a phone that was never asked shares both', () async {
      expect(await store().read(), PrivacyChoices.defaults);
      expect(PrivacyChoices.defaults.analytics, isTrue);
      expect(PrivacyChoices.defaults.crashReports, isTrue);
    });

    test('survive a restart: a new store reads what the last one wrote',
        () async {
      await store()
          .write(const PrivacyChoices(analytics: false, crashReports: true));

      // A fresh store, as after the app is killed and opened again.
      expect(await store().read(),
          const PrivacyChoices(analytics: false, crashReports: true));

      await store()
          .write(const PrivacyChoices(analytics: false, crashReports: false));
      expect(await store().read(),
          const PrivacyChoices(analytics: false, crashReports: false));
    });

    test('a damaged file reads as the defaults, never as a choice', () async {
      await File('${dir.path}/${FilePrivacyChoicesStore.fileName}')
          .writeAsString('{not json');
      expect(await store().read(), PrivacyChoices.defaults);
    });

    test('a missing or odd value reads as on', () {
      expect(PrivacyChoices.fromJson({'analytics': false}),
          const PrivacyChoices(analytics: false, crashReports: true));
      expect(PrivacyChoices.fromJson({'crash_reports': 'no'}),
          PrivacyChoices.defaults);
      expect(PrivacyChoices.fromJson(null), PrivacyChoices.defaults);
    });
  });

  group('at start-up', () {
    test('the saved choices are applied before anything is collected',
        () async {
      await store()
          .write(const PrivacyChoices(analytics: false, crashReports: false));
      final control = RecordingControl();

      final applied = await applySavedChoices(store(), control);

      expect(
          applied, const PrivacyChoices(analytics: false, crashReports: false));
      expect(control.applied, [applied]);
    });

    test('with nothing saved, both are applied on', () async {
      final control = RecordingControl();
      await applySavedChoices(store(), control);
      expect(control.applied, [PrivacyChoices.defaults]);
    });
  });

  group('what is collected', () {
    const off = PrivacyChoices(analytics: false, crashReports: false);

    test('analytics needs both the build and the person', () {
      expect(analyticsCollected(PrivacyChoices.defaults, buildAllows: true),
          isTrue);
      expect(analyticsCollected(off, buildAllows: true), isFalse);
      // ENABLE_ANALYTICS=false: a development build collects nothing.
      expect(analyticsCollected(PrivacyChoices.defaults, buildAllows: false),
          isFalse);
    });

    test('crash reports: never from a debug build, else as chosen', () {
      expect(
          crashReportsCollected(PrivacyChoices.defaults, debug: false), isTrue);
      expect(crashReportsCollected(off, debug: false), isFalse);
      expect(
          crashReportsCollected(PrivacyChoices.defaults, debug: true), isFalse);
    });

    test('the two switches are independent', () {
      const analyticsOnly =
          PrivacyChoices(analytics: true, crashReports: false);
      expect(analyticsCollected(analyticsOnly, buildAllows: true), isTrue);
      expect(crashReportsCollected(analyticsOnly, debug: false), isFalse);
    });
  });
}
