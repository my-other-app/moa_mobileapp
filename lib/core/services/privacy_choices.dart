import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// What the person has chosen about the data the app sends about itself:
/// usage analytics (Firebase Analytics) and crash reports (Crashlytics).
///
/// Both are on until the person turns them off in Settings. They are kept
/// apart on purpose: someone who does not want their use of the app counted
/// may still want the crash that just hit them fixed.
@immutable
class PrivacyChoices {
  /// "Share usage analytics".
  final bool analytics;

  /// "Send crash reports".
  final bool crashReports;

  const PrivacyChoices({this.analytics = true, this.crashReports = true});

  /// What a phone that has never been asked starts with.
  static const defaults = PrivacyChoices();

  PrivacyChoices copyWith({bool? analytics, bool? crashReports}) =>
      PrivacyChoices(
        analytics: analytics ?? this.analytics,
        crashReports: crashReports ?? this.crashReports,
      );

  Map<String, dynamic> toJson() =>
      {'analytics': analytics, 'crash_reports': crashReports};

  /// Anything missing or not a boolean reads as on, the default: a damaged
  /// file must not turn into a choice the person never made.
  factory PrivacyChoices.fromJson(Object? json) {
    if (json is! Map) return defaults;
    final analytics = json['analytics'];
    final crashReports = json['crash_reports'];
    return PrivacyChoices(
      analytics: analytics is bool ? analytics : true,
      crashReports: crashReports is bool ? crashReports : true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PrivacyChoices &&
      other.analytics == analytics &&
      other.crashReports == crashReports;

  @override
  int get hashCode => Object.hash(analytics, crashReports);

  @override
  String toString() =>
      'PrivacyChoices(analytics: $analytics, crashReports: $crashReports)';
}

/// Where the choices are kept.
abstract class PrivacyChoicesStore {
  /// The saved choices, or [PrivacyChoices.defaults]. Never throws.
  Future<PrivacyChoices> read();

  Future<void> write(PrivacyChoices choices);
}

/// The choices as a small JSON file in the app's support directory.
///
/// Not the keychain: nothing here is secret, and it is read first thing at
/// start-up, before Firebase is told what to collect. It belongs to the
/// phone rather than to an account, so signing out leaves it alone -- the
/// session caches clear their own folders, never this file.
class FilePrivacyChoicesStore implements PrivacyChoicesStore {
  FilePrivacyChoicesStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  static const fileName = 'privacy_choices.json';

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  @override
  Future<PrivacyChoices> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return PrivacyChoices.defaults;
      return PrivacyChoices.fromJson(jsonDecode(await file.readAsString()));
    } catch (e) {
      debugPrint('PrivacyChoicesStore: could not read the choices: $e');
      return PrivacyChoices.defaults;
    }
  }

  @override
  Future<void> write(PrivacyChoices choices) async {
    final file = await _file();
    if (!await file.parent.exists()) await file.parent.create(recursive: true);
    // Written aside and moved into place, so a crash halfway leaves the
    // old choices rather than half a file.
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(choices.toJson()), flush: true);
    await temp.rename(file.path);
  }
}

/// Turns collection on or off in the SDKs. The real one is
/// `AnalyticsService`; tests hand in their own, since Firebase is not there.
abstract class CollectionControl {
  Future<void> applyChoices(PrivacyChoices choices);
}

/// What start-up does first: read the saved choices and apply them, before
/// anything is collected. Answers with what was applied.
Future<PrivacyChoices> applySavedChoices(
  PrivacyChoicesStore store,
  CollectionControl control,
) async {
  final saved = await store.read();
  await control.applyChoices(saved);
  return saved;
}

final privacyChoicesStoreProvider =
    Provider<PrivacyChoicesStore>((ref) => FilePrivacyChoicesStore());
