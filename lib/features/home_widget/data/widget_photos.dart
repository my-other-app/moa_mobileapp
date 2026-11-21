import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/features/home_widget/data/widget_store.dart';
import 'package:finnet/features/home_widget/domain/networking.dart';
import 'package:finnet/shared/utils/image_url.dart';

// The photos on the large "Networking" widget's "Recently met"
// (docs/HOME_WIDGETS.md, "Photos"): off unless the person turns on "Show
// people's photos in widgets" in Settings. Then, while a Networking widget is
// on a home screen, the app keeps a small round photo of each of the people
// shown, made from their profile picture, in the storage the widgets read
// (the App Group's container on iOS, the app's files on Android). Turned
// off, signed out, a person no longer shown, or no widget on a home screen:
// their photos are deleted. The widgets show initials for anyone without one.

/// The photos' side, in pixels: sharp in a 28-32 point circle on a 3x
/// screen, and a few kilobytes each.
const widgetPhotoSide = 96;

/// The largest picture file read to make a photo from.
const _maxPictureBytes = 8 * 1024 * 1024;

/// A short, stable fingerprint of the picture at [url] (its cache key, which
/// stays the same through re-signed links and changes with a new picture):
/// so a photo is made again only when the picture changed. Not the link
/// itself, which the widgets' storage has no use for.
String pictureFingerprint(String url) {
  // FNV-1a, 32 bits: stable across runs, unlike String.hashCode.
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(imageCacheKey(url))) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Where the widgets' photos are kept, with the switch that allows them.
abstract class WidgetPhotoStore {
  /// Whether "Show people's photos in widgets" is on. False until turned on.
  Future<bool> isOn();

  Future<void> setOn(bool on);

  /// The photos kept, by key, each with the [pictureFingerprint] it was
  /// made from.
  Future<Map<String, String>> saved();

  /// Keep [png] under [key] (made from the picture [fingerprint] names).
  Future<void> save(String key, String fingerprint, Uint8List png);

  /// Delete the photo under [key].
  Future<void> remove(String key);

  /// Delete every photo, and turn the switch off.
  Future<void> clear();
}

/// [WidgetPhotoStore] through the home_widget plugin: each photo a PNG file
/// in its storage (`home_widget/networking_photo_<id>.png`, the file's path
/// under the photo's key), and what is kept -- the switch and the photos'
/// fingerprints -- as one small JSON string under [indexKey]. On anything
/// but a phone it does nothing, and the switch is off. Never throws.
class HomeWidgetPhotoStore implements WidgetPhotoStore {
  HomeWidgetPhotoStore({bool? supported})
      : _supported =
            supported ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// The key of what is kept: `{"on": true, "saved": {key: fingerprint}}`.
  static const indexKey = 'networking_photos';

  final bool _supported;
  bool _grouped = false;

  /// One change at a time: each reads what is kept, then writes it back.
  Future<void> _turn = Future.value();

  Future<T> _inTurn<T>(Future<T> Function() work, T fallback) {
    final result = _turn.then((_) async {
      if (!_supported) return fallback;
      try {
        if (!_grouped) {
          await HomeWidget.setAppGroupId(HomeWidgetStore.appGroupId);
          _grouped = true;
        }
        return await work();
      } catch (e) {
        debugPrint('WidgetPhotoStore: $e');
        return fallback;
      }
    });
    _turn = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<({bool on, Map<String, String> saved})> _index() async {
    const none = (on: false, saved: <String, String>{});
    final raw = await HomeWidget.getWidgetData<String>(indexKey);
    if (raw == null || raw.isEmpty) return none;
    final json = jsonDecode(raw);
    if (json is! Map) return none;
    final saved = <String, String>{};
    final entries = json['saved'];
    if (entries is Map) {
      for (final MapEntry(:key, :value) in entries.entries) {
        if (key is String && value is String) saved[key] = value;
      }
    }
    return (on: json['on'] == true, saved: saved);
  }

  Future<void> _write(bool on, Map<String, String> saved) async {
    if (!on && saved.isEmpty) {
      await HomeWidget.saveWidgetData<String>(indexKey, null);
      return;
    }
    await HomeWidget.saveWidgetData<String>(
        indexKey, jsonEncode({'on': on, 'saved': saved}));
  }

  @override
  Future<bool> isOn() => _inTurn(() async => (await _index()).on, false);

  @override
  Future<void> setOn(bool on) => _inTurn(() async {
        final index = await _index();
        await _write(on, index.saved);
      }, null);

  @override
  Future<Map<String, String>> saved() =>
      _inTurn(() async => (await _index()).saved, const <String, String>{});

  @override
  Future<void> save(String key, String fingerprint, Uint8List png) =>
      _inTurn(() async {
        await HomeWidget.saveFile(key, png, extension: 'png');
        final index = await _index();
        await _write(index.on, {...index.saved, key: fingerprint});
      }, null);

  @override
  Future<void> remove(String key) => _inTurn(() async {
        // Clearing the key deletes the file it names (home_widget's own).
        await HomeWidget.saveWidgetData<String>(key, null);
        final index = await _index();
        await _write(index.on, {...index.saved}..remove(key));
      }, null);

  @override
  Future<void> clear() => _inTurn(() async {
        final index = await _index();
        for (final key in index.saved.keys) {
          await HomeWidget.saveWidgetData<String>(key, null);
        }
        await HomeWidget.saveWidgetData<String>(indexKey, null);
      }, null);
}

/// Makes the small round photos from people's pictures.
abstract class WidgetThumbnails {
  /// The photo for the picture at [url], as PNG; null if it can't be had.
  Future<Uint8List?> of(String url);
}

/// [WidgetThumbnails] from the app's private picture cache, which already
/// holds the pictures the Network tab showed (and keeps what it fetches
/// here for the tab).
class CachedWidgetThumbnails implements WidgetThumbnails {
  const CachedWidgetThumbnails();

  @override
  Future<Uint8List?> of(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.isScheme('https') || uri.host.isEmpty) return null;
    try {
      final file = await AppImageCaches.private
          .getSingleFile(url, key: imageCacheKey(url));
      if (await file.length() > _maxPictureBytes) return null;
      return await roundThumbnail(await file.readAsBytes());
    } catch (e) {
      debugPrint('WidgetThumbnails: no photo made: $e');
      return null;
    }
  }
}

/// [encoded], any picture Flutter can decode, as a [side] x [side] PNG: its
/// middle square scaled down, in a circle, clear outside it (the Android
/// widget shows it as it is). Null if it can't be decoded.
Future<Uint8List?> roundThumbnail(Uint8List encoded,
    {int side = widgetPhotoSide}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(encoded);
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  ui.Picture? picture;
  ui.Image? out;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    if (width <= 0 || height <= 0) return null;
    // Decoded straight at the size drawn, the short side [side] long.
    final scale = side / math.min(width, height);
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(side, (width * scale).round()),
      targetHeight: math.max(side, (height * scale).round()),
    );
    image = (await codec.getNextFrame()).image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final square = ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble());
    canvas.clipPath(ui.Path()..addOval(square));
    canvas.drawImage(
      image,
      ui.Offset((side - image.width) / 2, (side - image.height) / 2),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    picture = recorder.endRecording();
    out = await picture.toImage(side, side);
    final png = await out.toByteData(format: ui.ImageByteFormat.png);
    return png?.buffer.asUint8List();
  } catch (e) {
    debugPrint('roundThumbnail: $e');
    return null;
  } finally {
    out?.dispose();
    picture?.dispose();
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// The photos of the people "Recently met" shows: kept, matched to the
/// people, and deleted. One per session; the Networking widget's sync uses
/// it, the switch in Settings and sign-out empty it.
class WidgetPhotos {
  WidgetPhotos(this.store, this.thumbnails);

  final WidgetPhotoStore store;
  final WidgetThumbnails thumbnails;

  /// Moved on by [removeAll] and [clear]: a photo still being made when the
  /// photos were deleted is not kept, nor shown.
  int _epoch = 0;
  int get epoch => _epoch;

  /// The photo of each of [people] who has a picture, by
  /// [RecentlyMetPerson.id]: made now when it isn't kept yet or the picture
  /// changed ([download]), else only those already kept. Empty when the
  /// photos were deleted meanwhile.
  Future<Map<int, String>> keep(List<RecentlyMetPerson> people,
      {bool download = true}) async {
    final started = _epoch;
    final saved = await store.saved();
    final keys = <int, String>{};
    for (final person in people) {
      final url = person.picture;
      if (url == null) continue;
      final key = widgetPhotoKey(person.id);
      final fingerprint = pictureFingerprint(url);
      if (saved[key] != fingerprint) {
        if (!download) continue;
        final png = await thumbnails.of(url);
        if (_epoch != started) return const {};
        if (png == null) continue;
        await store.save(key, fingerprint, png);
      }
      keys[person.id] = key;
    }
    return _epoch == started ? keys : const {};
  }

  /// Delete every photo but [kept]'s.
  Future<void> dropAllBut(Iterable<String> kept) async {
    final keep = kept.toSet();
    for (final key in (await store.saved()).keys) {
      if (!keep.contains(key)) await store.remove(key);
    }
  }

  /// Every photo deleted (the switch turned off); the switch stays as set.
  Future<void> removeAll() async {
    _epoch++;
    await dropAllBut(const []);
  }

  /// Every photo deleted and the switch off: the session ended.
  Future<void> clear() async {
    _epoch++;
    await store.clear();
  }
}

/// The photos' storage. A provider so tests can swap it.
final widgetPhotoStoreProvider =
    Provider<WidgetPhotoStore>((ref) => HomeWidgetPhotoStore());

/// What makes the photos. A provider so tests can swap it.
final widgetThumbnailsProvider =
    Provider<WidgetThumbnails>((ref) => const CachedWidgetThumbnails());

/// The session's [WidgetPhotos].
final widgetPhotosProvider = Provider<WidgetPhotos>((ref) => WidgetPhotos(
    ref.watch(widgetPhotoStoreProvider), ref.watch(widgetThumbnailsProvider)));

/// What signing out does to the photos (SessionCaches): every one deleted,
/// and the switch back to off -- the next person to sign in starts with
/// initials.
Future<void> clearWidgetPhotos(WidgetPhotos photos) => photos.clear();
