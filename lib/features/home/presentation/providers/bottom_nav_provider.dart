import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/main/presentation/providers/navigation_index_provider.dart';

/// The bottom bar's tab -- the same provider as [navigationIndexProvider],
/// under its old name.
///
/// This used to be a second, separate index: sign-out reset this one while
/// the bar read the other, so the reset did nothing. It is an alias now so
/// existing callers reset the index the bar actually shows; once they use
/// [navigationIndexProvider] (`profile_page.dart`, `settings_page.dart`),
/// delete this file.
final bottomNavIndexProvider = navigationIndexProvider;

/// The old notifier's methods, on the provider's controller.
extension BottomNavIndexController on StateController<int> {
  /// Update the current index.
  void updateIndex(int index) => state = index;

  /// Reset to home tab.
  void resetToHome() => state = 0;
}
