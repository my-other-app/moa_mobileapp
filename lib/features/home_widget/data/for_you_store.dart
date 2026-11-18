import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/home_widget/data/widget_store.dart';

/// The "For you" events widget's names on each side (docs/HOME_WIDGETS.md).
abstract final class ForYouKind {
  /// The key the JSON is kept under (ForYouData.kt, ForYouData.swift).
  static const dataKey = 'events_for_you';

  /// The widget's kind on iOS (ForYouWidget.swift).
  static const iOSKind = 'ForYouWidget';

  /// The Android provider, by its full class name.
  static const androidProvider =
      'app.myotherapp.com.widget.ForYouWidgetProvider';
}

/// "For you" through the home_widget plugin.
class HomeWidgetForYouStore extends HomeWidgetStore {
  HomeWidgetForYouStore({super.supported})
      : super(
          dataKey: ForYouKind.dataKey,
          iOSKind: ForYouKind.iOSKind,
          androidProvider: ForYouKind.androidProvider,
        );
}

/// The events widget's storage. A provider so tests can swap it.
final forYouStoreProvider =
    Provider<WidgetStore>((ref) => HomeWidgetForYouStore());
