import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/home_widget/data/widget_store.dart';

/// Where the "Next up" widgets read what to show: one JSON string under
/// `next_up` ([NextUpKind.dataKey]). Their "Today" and "In 3 days" are
/// worked out as they draw, so [WidgetStore.redraw] moves them on.
typedef NextUpStore = WidgetStore;

/// The "Next up" widget's names on each side.
abstract final class NextUpKind {
  /// The key the JSON is kept under (NextUpData.kt, NextUpData.swift).
  static const dataKey = 'next_up';

  /// The widget's kind on iOS (NextUpWidget.swift).
  static const iOSKind = 'NextUpWidget';

  /// The Android provider, by its full class name.
  static const androidProvider =
      'app.myotherapp.com.widget.NextUpWidgetProvider';
}

/// "Next up" through the home_widget plugin.
class HomeWidgetNextUpStore extends HomeWidgetStore {
  HomeWidgetNextUpStore({super.supported})
      : super(
          dataKey: NextUpKind.dataKey,
          iOSKind: NextUpKind.iOSKind,
          androidProvider: NextUpKind.androidProvider,
        );
}

/// The widgets' storage. A provider so tests can swap it.
final nextUpStoreProvider =
    Provider<NextUpStore>((ref) => HomeWidgetNextUpStore());
