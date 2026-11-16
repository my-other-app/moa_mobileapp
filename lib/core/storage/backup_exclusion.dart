import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Keeps the app's personal files out of the phone's backups.
///
/// - **iPhone:** iCloud and computer backups take the app's support folder
///   unless a file or folder is marked. This marks one, through a method
///   channel of the app's own (`BackupExclusion` in
///   ios/Runner/AppDelegate.swift). A marked folder is left out with all it
///   holds; a folder deleted and made again needs marking again, so the
///   stores mark theirs whenever they make it, and start-up marks the ones
///   already there ([excludeKnown]).
/// - **Android:** the same files are left out by
///   android/app/src/main/res/xml/backup_rules.xml and
///   data_extraction_rules.xml; nothing is done here.
///
/// Left out: a volunteer's unsent door scans (`gate_queue`, other people's
/// ticket codes), the person's kept tickets and certificates (`documents`)
/// and the people they saved offline (`network_saves.json`). Each stays on
/// the phone as before; only the backup goes without it.
class BackupExclusion {
  BackupExclusion({MethodChannel? channel, bool? supported})
      : _channel = channel ?? const MethodChannel(channelName),
        _supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  /// The channel's name, as AppDelegate.swift registers it.
  static const channelName = 'finnet/backup';

  /// The one the app uses.
  static BackupExclusion instance = BackupExclusion();

  /// The support folder's entries left out, by name.
  static const supportEntries = [
    'gate_queue',
    'documents',
    'network_saves.json'
  ];

  final MethodChannel _channel;
  final bool _supported;

  /// Leave [path] out of backups. Never throws: an entry that can't be
  /// marked is only backed up as before.
  Future<void> exclude(String path) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('exclude', path);
    } catch (e) {
      debugPrint('BackupExclusion: could not mark a file: $e');
    }
  }

  /// At start-up: mark the [supportEntries] already in [support] (the
  /// app's support folder unless given). Never throws.
  Future<void> excludeKnown({Directory? support}) async {
    if (!_supported) return;
    try {
      final dir = support ?? await getApplicationSupportDirectory();
      for (final name in supportEntries) {
        final path = '${dir.path}/$name';
        if (await FileSystemEntity.type(path) !=
            FileSystemEntityType.notFound) {
          await exclude(path);
        }
      }
    } catch (e) {
      debugPrint('BackupExclusion: could not mark the known files: $e');
    }
  }
}
