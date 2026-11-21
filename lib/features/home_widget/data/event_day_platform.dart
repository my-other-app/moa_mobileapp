import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:finnet/features/home_widget/domain/event_day.dart';

/// The phone's side of the event-day card (docs/HOME_WIDGETS.md): an
/// iPhone's Live Activity (ios/Runner/EventDayActivities.swift), Android's
/// ongoing notification (eventday/EventDayNotifications.kt). One card at a
/// time.
abstract class EventDayPlatform {
  /// Whether this phone can show the card at all (iOS 16.1 and later;
  /// every Android the app runs on).
  Future<bool> supported();

  /// Put up [card], replacing any other. False when it can't be shown: Live
  /// Activities or the app's notifications are turned off.
  Future<bool> start(EventDayCard card);

  /// Bring the card up for [card]'s event up to date, if it is up. False
  /// when it isn't.
  Future<bool> update(EventDayCard card);

  /// Take every card down.
  Future<void> end();

  /// The event whose card is up, if any.
  Future<int?> current();
}

/// [EventDayPlatform] over the app's channel. Never throws: on anything
/// but a phone (tests, the desktop) nothing is shown.
class ChannelEventDayPlatform implements EventDayPlatform {
  ChannelEventDayPlatform({bool? phone})
      : _phone = phone ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  static const channel = MethodChannel('finnet/event_day');

  final bool _phone;

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    if (!_phone) return null;
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } catch (e) {
      debugPrint('EventDayPlatform.$method: $e');
      return null;
    }
  }

  @override
  Future<bool> supported() async => await _call<bool>('supported') ?? false;

  @override
  Future<bool> start(EventDayCard card) async =>
      await _call<bool>('start', card.toChannel()) ?? false;

  @override
  Future<bool> update(EventDayCard card) async =>
      await _call<bool>('update', card.toChannel()) ?? false;

  @override
  Future<void> end() => _call<void>('end');

  @override
  Future<int?> current() => _call<int>('current');
}

final eventDayPlatformProvider =
    Provider<EventDayPlatform>((ref) => ChannelEventDayPlatform());

/// What the phone keeps about the card: the Settings switch ("Event-day
/// card on the lock screen", on unless turned off) and the events whose
/// card was put up already, each with its end, so a card the person put
/// away isn't put back by the next start of the app.
@immutable
class EventDayChoices {
  const EventDayChoices({this.on = true, this.shown = const {}});

  static const defaults = EventDayChoices();

  final bool on;

  /// Event id -> its end (epoch ms).
  final Map<int, int> shown;

  EventDayChoices copyWith({bool? on, Map<int, int>? shown}) =>
      EventDayChoices(on: on ?? this.on, shown: shown ?? this.shown);

  /// Without the events over a day before [now].
  EventDayChoices prunedAt(DateTime now) {
    final cutoff = now.subtract(const Duration(days: 1)).millisecondsSinceEpoch;
    return copyWith(shown: {
      for (final e in shown.entries)
        if (e.value > cutoff) e.key: e.value,
    });
  }

  Map<String, Object?> toJson() => {
        'on': on,
        'shown': {for (final e in shown.entries) '${e.key}': e.value},
      };

  static EventDayChoices fromJson(Object? json) {
    if (json is! Map) return defaults;
    final shown = <int, int>{};
    final raw = json['shown'];
    if (raw is Map) {
      for (final e in raw.entries) {
        final id = int.tryParse('${e.key}');
        final end = e.value;
        if (id != null && end is int) shown[id] = end;
      }
    }
    return EventDayChoices(on: json['on'] != false, shown: shown);
  }

  @override
  bool operator ==(Object other) =>
      other is EventDayChoices &&
      other.on == on &&
      mapEquals(other.shown, shown);

  @override
  int get hashCode => Object.hash(on, Object.hashAll(shown.entries
      .map((e) => Object.hash(e.key, e.value))));
}

abstract class EventDayStore {
  /// The saved choices, or [EventDayChoices.defaults]. Never throws.
  Future<EventDayChoices> read();

  Future<void> write(EventDayChoices choices);
}

/// The choices as a small JSON file in the app's support directory -- the
/// app's own, not the widgets' shared storage. The switch belongs to the
/// phone and stays through a sign-out; the events go with the person
/// (SessionCaches).
class FileEventDayStore implements EventDayStore {
  FileEventDayStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  static const fileName = 'event_day.json';

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  @override
  Future<EventDayChoices> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return EventDayChoices.defaults;
      return EventDayChoices.fromJson(jsonDecode(await file.readAsString()));
    } catch (e) {
      debugPrint('EventDayStore: could not read: $e');
      return EventDayChoices.defaults;
    }
  }

  @override
  Future<void> write(EventDayChoices choices) async {
    try {
      final file = await _file();
      if (!await file.parent.exists()) await file.parent.create(recursive: true);
      final aside = File('${file.path}.tmp');
      await aside.writeAsString(jsonEncode(choices.toJson()), flush: true);
      await aside.rename(file.path);
    } catch (e) {
      debugPrint('EventDayStore: could not write: $e');
    }
  }
}

final eventDayStoreProvider =
    Provider<EventDayStore>((ref) => FileEventDayStore());
