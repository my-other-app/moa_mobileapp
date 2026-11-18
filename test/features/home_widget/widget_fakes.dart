import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:finnet/features/home_widget/data/event_day_platform.dart';
import 'package:finnet/features/home_widget/data/widget_photos.dart';
import 'package:finnet/features/home_widget/data/widget_store.dart';
import 'package:finnet/features/home_widget/domain/event_day.dart';

/// A home-screen widget's storage, kept in memory.
class MemoryWidgetStore implements WidgetStore {
  final writes = <String>[];
  int redraws = 0;
  bool placed = false;

  Map<String, dynamic> get last =>
      jsonDecode(writes.last) as Map<String, dynamic>;

  @override
  Future<void> write(String json) async => writes.add(json);

  @override
  Future<void> redraw() async => redraws++;

  @override
  Future<bool> isPlaced() async => placed;
}

/// The widgets' photos and their switch, kept in memory.
class MemoryPhotoStore implements WidgetPhotoStore {
  bool on = false;

  /// key -> the fingerprint it was made from.
  final index = <String, String>{};

  /// key -> the PNG.
  final files = <String, Uint8List>{};
  final saves = <String>[];
  final removes = <String>[];
  int clears = 0;

  @override
  Future<bool> isOn() async => on;

  @override
  Future<void> setOn(bool value) async => on = value;

  @override
  Future<Map<String, String>> saved() async => Map.of(index);

  @override
  Future<void> save(String key, String fingerprint, Uint8List png) async {
    saves.add(key);
    index[key] = fingerprint;
    files[key] = png;
  }

  @override
  Future<void> remove(String key) async {
    removes.add(key);
    index.remove(key);
    files.remove(key);
  }

  @override
  Future<void> clear() async {
    clears++;
    on = false;
    index.clear();
    files.clear();
  }
}

/// Makes a "photo" -- three bytes -- for every picture asked for, or none
/// for those in [failing]. With [gate] set, each waits for it.
class FakeThumbnails implements WidgetThumbnails {
  final asked = <String>[];
  final failing = <String>{};
  Completer<void>? gate;

  @override
  Future<Uint8List?> of(String url) async {
    asked.add(url);
    await gate?.future;
    if (failing.contains(url)) return null;
    return Uint8List.fromList([1, 2, 3]);
  }
}

/// The phone's card, kept in memory: which event's is up, and every call.
class FakeEventDayPlatform implements EventDayPlatform {
  int? up;
  bool allowed = true;
  bool canShow = true;
  final calls = <String>[];
  final cards = <Map<String, Object?>>[];

  @override
  Future<bool> supported() async => canShow;

  @override
  Future<bool> start(EventDayCard card) async {
    calls.add('start ${card.eventId}');
    cards.add(card.toChannel());
    if (!allowed) return false;
    up = card.eventId;
    return true;
  }

  @override
  Future<bool> update(EventDayCard card) async {
    calls.add('update ${card.eventId}');
    cards.add(card.toChannel());
    return up == card.eventId;
  }

  @override
  Future<void> end() async {
    calls.add('end');
    up = null;
  }

  @override
  Future<int?> current() async => up;

  /// The person swiped the card away.
  void putAway() => up = null;
}

class MemoryEventDayStore implements EventDayStore {
  EventDayChoices saved = EventDayChoices.defaults;
  int writes = 0;

  @override
  Future<EventDayChoices> read() async => saved;

  @override
  Future<void> write(EventDayChoices choices) async {
    writes++;
    saved = choices;
  }
}
