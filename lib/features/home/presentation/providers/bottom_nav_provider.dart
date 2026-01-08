import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bottom navigation state provider - Riverpod equivalent of BottomNavigatorBloc.
final bottomNavIndexProvider =
    StateNotifierProvider<BottomNavNotifier, int>((ref) {
  return BottomNavNotifier();
});

/// State notifier for bottom navigation index.
class BottomNavNotifier extends StateNotifier<int> {
  BottomNavNotifier() : super(0);

  /// Update the current index.
  void updateIndex(int index) {
    state = index;
  }

  /// Reset to home tab.
  void resetToHome() {
    state = 0;
  }
}
