import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/home_widget/data/widget_store.dart';

/// The "Networking" widget's names on each side (docs/HOME_WIDGETS.md).
abstract final class NetworkingKind {
  /// The key the JSON is kept under (NetworkingData.kt,
  /// NetworkingData.swift).
  static const dataKey = 'networking';

  /// The widget's kind on iOS (NetworkingWidget.swift).
  static const iOSKind = 'NetworkingWidget';

  /// The Android provider, by its full class name.
  static const androidProvider =
      'app.myotherapp.com.widget.NetworkingWidgetProvider';
}

/// "Networking" through the home_widget plugin.
class HomeWidgetNetworkingStore extends HomeWidgetStore {
  HomeWidgetNetworkingStore({super.supported})
      : super(
          dataKey: NetworkingKind.dataKey,
          iOSKind: NetworkingKind.iOSKind,
          androidProvider: NetworkingKind.androidProvider,
        );
}

/// The Networking widget's storage. A provider so tests can swap it.
final networkingStoreProvider =
    Provider<WidgetStore>((ref) => HomeWidgetNetworkingStore());
