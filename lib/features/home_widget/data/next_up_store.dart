import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

/// Where the "Next up" widgets read what to show, and how they are told
/// to draw it again.
///
/// One JSON string under [dataKey] (`next_up`). On iOS it lives in the App
/// Group's `UserDefaults` ([appGroupId]) the widget extension shares with
/// the app; on Android in home_widget's SharedPreferences, read by the
/// AppWidgetProvider in the app's own process.
abstract class NextUpStore {
  /// Keep [json] for the widgets, and redraw them.
  Future<void> write(String json);

  /// Draw the widgets again from what is kept: their "Today" and "In 3
  /// days" are worked out as they draw.
  Future<void> redraw();

  /// Whether any "Next up" widget is on a home screen. False when it cannot
  /// be told.
  Future<bool> isPlaced();
}

/// [NextUpStore] through the home_widget plugin. On anything but a phone
/// (tests, the desktop) it does nothing. Never throws: a widget that cannot
/// be written to keeps what it had.
class HomeWidgetNextUpStore implements NextUpStore {
  HomeWidgetNextUpStore({bool? supported})
      : _supported = supported ??
            (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// The App Group the app and its widget extension share
  /// (Runner.entitlements, NextUpWidget.entitlements).
  static const appGroupId = 'group.app.myotherapp.in';

  /// The key the JSON is kept under.
  static const dataKey = 'next_up';

  /// The widget's kind on iOS (NextUpWidget.swift).
  static const iOSKind = 'NextUpWidget';

  /// The Android provider, by its full class name: the Kotlin package is
  /// app.myotherapp.com (the namespace), not the application id
  /// (app.myotherapp.in) home_widget would prefix a short name with.
  static const androidProvider =
      'app.myotherapp.com.widget.NextUpWidgetProvider';

  final bool _supported;
  bool _grouped = false;

  Future<void> _useGroup() async {
    if (_grouped) return;
    await HomeWidget.setAppGroupId(appGroupId);
    _grouped = true;
  }

  @override
  Future<void> write(String json) async {
    if (!_supported) return;
    try {
      await _useGroup();
      await HomeWidget.saveWidgetData<String>(dataKey, json);
    } catch (e) {
      debugPrint('NextUpStore: could not save: $e');
      return;
    }
    await redraw();
  }

  @override
  Future<void> redraw() async {
    if (!_supported) return;
    try {
      await _useGroup();
      await HomeWidget.updateWidget(
        iOSName: iOSKind,
        qualifiedAndroidName: androidProvider,
      );
    } catch (e) {
      debugPrint('NextUpStore: could not redraw: $e');
    }
  }

  @override
  Future<bool> isPlaced() async {
    if (!_supported) return false;
    try {
      await _useGroup();
      final placed = await HomeWidget.getInstalledWidgets();
      return placed.isNotEmpty;
    } catch (e) {
      debugPrint('NextUpStore: could not list the widgets: $e');
      return false;
    }
  }
}

/// The widgets' storage. A provider so tests can swap it.
final nextUpStoreProvider =
    Provider<NextUpStore>((ref) => HomeWidgetNextUpStore());
