import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// A disk cache for pictures that can also hand out resized copies, which
/// `CachedNetworkImage` needs when asked for a smaller one.
class AppImageCacheManager extends CacheManager with ImageCacheManager {
  AppImageCacheManager(super.config);
}

/// Who a picture belongs to, which decides which disk cache keeps it.
enum ImagePrivacy {
  /// Posters, club logos and covers, stock avatars, posts' pictures: the
  /// same for everyone, and kept across sign-outs.
  public,

  /// A person's own picture, someone else's profile picture, a rendered
  /// certificate: emptied when the session ends.
  private,
}

/// The app's two picture caches on disk.
///
/// `CachedNetworkImage` used to run on its default cache with the full URL
/// as the key -- a presigned link, new on every API call -- so nothing hit,
/// and 14 screens used `Image.network`, which keeps nothing on disk at all.
/// Every picture now comes through here ([AppNetworkImage]), keyed by
/// [imageCacheKey].
///
/// Two caches, so a sign-out can empty the private one without throwing
/// away every poster. Each keeps a picture for [stalePeriod] after it was
/// last shown, holds at most a number of files, and is trimmed to its share
/// of [maxBytes] at start-up ([trim]).
class AppImageCaches {
  AppImageCaches._();

  /// About 200 MB on disk for pictures, all told.
  static const maxBytes = 200 * 1024 * 1024;

  /// The public cache's share of [maxBytes]; the private one has the rest.
  static const publicBytes = 160 * 1024 * 1024;
  static const privateBytes = maxBytes - publicBytes;

  /// A picture not shown for this long is deleted.
  static const stalePeriod = Duration(days: 30);

  static BaseCacheManager? _public;
  static BaseCacheManager? _private;

  /// Posters, logos, covers and the like.
  static BaseCacheManager get public => _public ??= AppImageCacheManager(
        Config(
          'moaImagesPublic',
          stalePeriod: stalePeriod,
          // A poster's `large` is a few hundred kilobytes; the byte cap
          // ([trim]) is what really bounds it.
          maxNrOfCacheObjects: 1500,
        ),
      );

  /// Profile pictures and documents.
  static BaseCacheManager get private => _private ??= AppImageCacheManager(
        Config(
          'moaImagesPrivate',
          stalePeriod: stalePeriod,
          maxNrOfCacheObjects: 400,
        ),
      );

  /// The cache for [privacy].
  static BaseCacheManager of(ImagePrivacy privacy) =>
      privacy == ImagePrivacy.private ? private : public;

  /// Replace the caches, for tests: the real ones need a platform channel.
  @visibleForTesting
  static void debugOverride({
    BaseCacheManager? public,
    BaseCacheManager? private,
  }) {
    _public = public;
    _private = private;
  }

  /// Empty the private cache, on disk and in memory. Posters stay on disk.
  ///
  /// Flutter's in-memory image cache holds decoded pictures of either kind
  /// under the same keys; it is cleared whole, which costs a re-decode of
  /// the posters on screen and nothing more.
  static Future<void> clearPrivate() async {
    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    } catch (e) {
      debugPrint('AppImageCaches: could not clear the memory cache: $e');
    }
    try {
      await private.emptyCache();
    } catch (e) {
      debugPrint('AppImageCaches: could not empty the private cache: $e');
    }
  }

  /// Bring each cache under its share of [maxBytes], least recently shown
  /// first. The cache itself only counts files; this counts bytes. Run once
  /// at start-up, in the background; failures are logged and ignored.
  static Future<void> trim() async {
    await _trim(public, publicBytes);
    await _trim(private, privateBytes);
  }

  static Future<void> _trim(BaseCacheManager manager, int budget) async {
    if (manager is! CacheManager) return;
    final repo = manager.config.repo;
    var opened = false;
    try {
      opened = await repo.open();
      final objects = await repo.getAllObjects();
      for (final object in overBudget(
        objects,
        maxBytes: budget,
        size: (o) => o.length ?? 0,
        lastUsed: (o) => o.touched,
      )) {
        await manager.store.removeCachedFile(object);
      }
    } catch (e) {
      debugPrint('AppImageCaches: trim failed: $e');
    } finally {
      // Balance the open: the cache's own connection stays up.
      if (opened) {
        try {
          await repo.close();
        } catch (_) {}
      }
    }
  }
}

/// Which of [objects] to delete to bring their total [size] to at most
/// [maxBytes]: the least recently used first (never used counts as oldest),
/// and no more than needed.
@visibleForTesting
List<T> overBudget<T>(
  List<T> objects, {
  required int maxBytes,
  required int Function(T) size,
  required DateTime? Function(T) lastUsed,
}) {
  var total = objects.fold<int>(0, (sum, o) => sum + size(o));
  if (total <= maxBytes) return const [];
  final oldestFirst = [...objects]..sort((a, b) {
      final at = lastUsed(a), bt = lastUsed(b);
      if (at == null && bt == null) return 0;
      if (at == null) return -1;
      if (bt == null) return 1;
      return at.compareTo(bt);
    });
  final remove = <T>[];
  for (final object in oldestFirst) {
    if (total <= maxBytes) break;
    remove.add(object);
    total -= size(object);
  }
  return remove;
}
