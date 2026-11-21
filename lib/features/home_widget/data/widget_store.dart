import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Where one kind of home-screen widget reads what to show, and how it is
/// told to draw it again (docs/HOME_WIDGETS.md).
///
/// One JSON string per kind. On iOS it lives in the App Group's
/// `UserDefaults` ([HomeWidgetStore.appGroupId]) the widget extension shares
/// with the app; on Android in home_widget's SharedPreferences, read by the
/// kind's AppWidgetProvider in the app's own process.
abstract class WidgetStore {
  /// Keep [json] for the widgets, and redraw them.
  Future<void> write(String json);

  /// Draw the widgets again from what is kept.
  Future<void> redraw();

  /// Whether a widget of this kind is on a home screen. False when it can't
  /// be told.
  Future<bool> isPlaced();
}

/// [WidgetStore] through the home_widget plugin, for the kind named by
/// [dataKey], [iOSKind] and [androidProvider]. On anything but a phone
/// (tests, the desktop) it does nothing. Never throws: a widget that can't
/// be written to keeps what it had.
class HomeWidgetStore implements WidgetStore {
  HomeWidgetStore({
    required this.dataKey,
    required this.iOSKind,
    required this.androidProvider,
    bool? supported,
  }) : _supported =
            supported ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  /// The App Group the app and its widget extension share
  /// (Runner.entitlements, NextUpWidget.entitlements).
  static const appGroupId = 'group.app.myotherapp.in';

  /// The key the JSON is kept under.
  final String dataKey;

  /// The widget's kind on iOS (its `Widget`'s `kind`).
  final String iOSKind;

  /// The Android provider, by its full class name: the Kotlin package is
  /// app.myotherapp.com (the namespace), not the application id
  /// (app.myotherapp.in) home_widget would prefix a short name with.
  final String androidProvider;

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
      debugPrint('WidgetStore($dataKey): could not save: $e');
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
      debugPrint('WidgetStore($dataKey): could not redraw: $e');
    }
  }

  @override
  Future<bool> isPlaced() async {
    if (!_supported) return false;
    try {
      await _useGroup();
      final placed = await HomeWidget.getInstalledWidgets();
      return placed.any(isThisKind);
    } catch (e) {
      debugPrint('WidgetStore($dataKey): could not list the widgets: $e');
      return false;
    }
  }

  /// Whether [widget], one of the app's widgets on a home screen, is this
  /// kind: by its kind on iOS, its provider's class on Android (which
  /// Android may give relative to the package, `.widget.NextUpWidgetProvider`).
  @visibleForTesting
  bool isThisKind(HomeWidgetInfo widget) {
    if (widget.iOSKind != null) return widget.iOSKind == iOSKind;
    final name = widget.androidClassName;
    if (name == null || name.isEmpty) return false;
    return name == androidProvider ||
        (name.startsWith('.') && androidProvider.endsWith(name));
  }
}
