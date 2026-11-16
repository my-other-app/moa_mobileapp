import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finnet/core/storage/secure_storage_service.dart';

/// What start-up did with the keychain.
enum KeychainStart {
  /// Not an iPhone: Android deletes the app's store with the app, and
  /// leaves it out of backups (backup_rules.xml), so there is nothing to do.
  notIos,

  /// The app was here before (an update, or any later launch): every entry
  /// kept, the session too.
  kept,

  /// A new install: whatever an earlier install of the app left in the
  /// keychain was deleted, so nobody starts signed in as the person who had
  /// the app before.
  cleared,

  /// The check could not finish (the phone not yet unlocked since a
  /// restart, say); nothing was deleted, and the next launch tries again.
  deferred,
}

/// Two jobs for the iPhone's keychain, run at the very start of `main`,
/// before anything reads the session.
///
/// **A new install starts empty.** Deleting the app deletes its folders but
/// not its keychain entries, so a reinstall used to come back signed in,
/// with the last person's saved tickets. The app now leaves a marker file
/// in its support folder ([markerName]). A launch without it is either the
/// first launch of a new install or the first launch after an update from
/// a build that never wrote one (1.2.1, 1.3.0) -- and a missing marker
/// alone can't tell those apart. What does is the app's folders: every
/// launch of those builds left files there ([earlierRunTraces]: the
/// picture caches' indexes and the saved answers' folder, made at every
/// start-up), and a new install's folders are empty. So: no marker and no
/// trace of an earlier run is a new install, and only then is the keychain
/// emptied. No marker but a trace is an update, which keeps everything.
///
/// **Entries stay on this phone.** Builds up to 1.3.0 wrote entries an
/// encrypted backup carries to a new iPhone; they are rewritten at
/// [SecureStorageService.iosAccessibility] ([moveToThisDevice]), the value
/// unchanged.
///
/// Never throws: a check that fails leaves the keychain as it was.
class KeychainStartUp {
  KeychainStartUp({
    required this.supportDirectory,
    required this.cacheDirectory,
    required this.documentsDirectory,
    FlutterSecureStorage Function(KeychainAccessibility level)? storageAt,
    bool? isIos,
  })  : _storageAt = storageAt ?? SecureStorageService.storageAt,
        _isIos = isIos ?? Platform.isIOS;

  /// Both jobs on this phone, with the app's own folders. What `main`
  /// awaits first. Never throws.
  static Future<KeychainStart> runForApp() async {
    if (!Platform.isIOS) return KeychainStart.notIos;
    try {
      final check = KeychainStartUp(
        supportDirectory: await getApplicationSupportDirectory(),
        cacheDirectory: await getApplicationCacheDirectory(),
        documentsDirectory: await getApplicationDocumentsDirectory(),
      );
      // A keychain answers in milliseconds; a platform that never answers
      // must not hold the app on its launch screen.
      return await check.run().timeout(const Duration(seconds: 5),
          onTimeout: () => KeychainStart.deferred);
    } catch (e) {
      debugPrint('KeychainStartUp: the app folders are unknown: $e');
      return KeychainStart.deferred;
    }
  }

  /// Where the app's files live: Application Support, Caches and
  /// Documents on an iPhone. All three go when the app is deleted.
  final Directory supportDirectory;
  final Directory cacheDirectory;
  final Directory documentsDirectory;

  final FlutterSecureStorage Function(KeychainAccessibility level) _storageAt;
  final bool _isIos;

  /// The marker, in the support folder. It says `done` once the check has
  /// been made, and `pending <n>` while a new install's keychain is being
  /// emptied: a launch that finds that empties it again, at most
  /// [maxAttempts] times in all.
  static const markerName = 'keychain_check';

  /// How many launches try to empty a new install's keychain before giving
  /// up (a keychain that refuses every time, which never happens on a
  /// phone that has been unlocked).
  static const maxAttempts = 3;

  /// What builds before the marker left in the support folder. The first
  /// two are made at every start-up (`AppImageCaches.trim` opens both
  /// indexes); the rest are made as the app is used.
  static const supportTraces = [
    'moaImagesPublic.db',
    'moaImagesPrivate.db',
    'libCachedImageData.db',
    'documents',
    'gate_queue',
    'privacy_choices.json',
    'discover_place.json',
    'network_saves.json',
  ];

  /// ... and in the cache folder: the saved answers' folder, made at every
  /// start-up (`ApiCache.prune`).
  static const cacheTraces = ['api_cache'];

  /// ... and in the documents folder: older builds' push pictures, saved
  /// tickets and picture-cache indexes.
  static bool isDocumentsTrace(String name) =>
      name.startsWith('bigPicture-') ||
      name.startsWith('ticket_') ||
      name.endsWith('.db');

  /// Builds up to 1.3.0 wrote at [SecureStorageService.legacyIosAccessibility];
  /// test builds before them at the plugin's default (`unlocked`).
  static const olderLevels = [
    KeychainAccessibility.first_unlock,
    KeychainAccessibility.unlocked,
  ];

  /// Every level the app has written at.
  static const usedLevels = [
    SecureStorageService.iosAccessibility,
    ...olderLevels,
  ];

  /// Both jobs, in order. Never throws.
  Future<KeychainStart> run() async {
    if (!_isIos) return KeychainStart.notIos;
    final KeychainStart outcome;
    try {
      outcome = await clearIfNewInstall();
    } catch (e) {
      debugPrint('KeychainStartUp: the install check failed: $e');
      return KeychainStart.deferred;
    }
    if (outcome == KeychainStart.deferred) return outcome;
    try {
      await moveToThisDevice();
    } catch (e) {
      debugPrint('KeychainStartUp: could not move older entries: $e');
    }
    return outcome;
  }

  File get _marker => File('${supportDirectory.path}/$markerName');

  /// The first job: empty the keychain when this is a new install.
  @visibleForTesting
  Future<KeychainStart> clearIfNewInstall() async {
    final marker = _marker;
    var attempt = 1;
    if (await marker.exists()) {
      final String state;
      try {
        state = (await marker.readAsString()).trim();
      } catch (e) {
        // Unreadable until the phone is first unlocked: decide next time.
        debugPrint('KeychainStartUp: the marker is unreadable: $e');
        return KeychainStart.deferred;
      }
      // Anything but a clear left halfway is a launch after the first.
      final pending = RegExp(r'^pending (\d+)$').firstMatch(state);
      if (pending == null) return KeychainStart.kept;
      attempt = int.parse(pending.group(1)!) + 1;
      if (attempt > maxAttempts) {
        await _writeMarker('done');
        return KeychainStart.kept;
      }
    } else if (await hasEarlierRun()) {
      // An update from a build without the marker: the session stays.
      await _writeMarker('done');
      return KeychainStart.kept;
    }
    // A new install. Marked first, so a clear cut short (the app killed,
    // the keychain refusing) is finished at the next launch -- by then this
    // launch's own files would look like an earlier run.
    await _writeMarker('pending $attempt');

    // Every level, though the app has only ever written three of them
    // ([usedLevels]); a refusal of one of those is tried again next time.
    var refused = false;
    for (final level in KeychainAccessibility.values) {
      try {
        await _storageAt(level).deleteAll();
      } catch (e) {
        // The other levels still go.
        debugPrint('KeychainStartUp: could not clear ${level.name}: $e');
        if (usedLevels.contains(level)) refused = true;
      }
    }
    if (refused) return KeychainStart.deferred;
    await _writeMarker('done');
    return KeychainStart.cleared;
  }

  /// Whether the app's folders hold anything an earlier launch made.
  @visibleForTesting
  Future<bool> hasEarlierRun() async {
    for (final name in supportTraces) {
      if (await _exists('${supportDirectory.path}/$name')) return true;
    }
    for (final name in cacheTraces) {
      if (await _exists('${cacheDirectory.path}/$name')) return true;
    }
    try {
      if (await documentsDirectory.exists()) {
        await for (final entry in documentsDirectory.list()) {
          final segments = entry.uri.pathSegments.where((s) => s.isNotEmpty);
          if (segments.isNotEmpty && isDocumentsTrace(segments.last)) {
            return true;
          }
        }
      }
    } catch (e) {
      // Unlistable: an earlier run, then. Keeping a session is the safe
      // mistake; clearing one is not.
      debugPrint('KeychainStartUp: could not list the documents: $e');
      return true;
    }
    return false;
  }

  static Future<bool> _exists(String path) async =>
      await FileSystemEntity.type(path) != FileSystemEntityType.notFound;

  Future<void> _writeMarker(String state) async {
    try {
      final marker = _marker;
      if (!await marker.parent.exists()) {
        await marker.parent.create(recursive: true);
      }
      await marker.writeAsString(state, flush: true);
    } catch (e) {
      // Without it the next launch decides again, and by then this one's
      // files say "an earlier run": the session is kept.
      debugPrint('KeychainStartUp: could not write the marker: $e');
    }
  }

  /// The second job: rewrite entries older builds left at [olderLevels] at
  /// [SecureStorageService.iosAccessibility]. Answers how many moved.
  ///
  /// Run before the app's first request: a token the app refreshes is
  /// written at the new level already, and an entry whose value changed
  /// since the listing is left as it is now.
  @visibleForTesting
  Future<int> moveToThisDevice() async {
    final current = _storageAt(SecureStorageService.iosAccessibility);
    var moved = 0;
    for (final level in olderLevels) {
      final Map<String, String> older;
      try {
        older = await _storageAt(level).readAll();
      } catch (e) {
        debugPrint('KeychainStartUp: could not list ${level.name}: $e');
        continue;
      }
      for (final MapEntry(:key, :value) in older.entries) {
        try {
          if (await current.read(key: key) != value) continue;
          await current.write(key: key, value: value);
          moved++;
        } catch (e) {
          // Still read, listed and deleted where it is
          // (SecureStorageService); moved at a later launch.
          debugPrint('KeychainStartUp: could not move an entry: $e');
        }
      }
    }
    return moved;
  }
}
