import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Available tabs in the main navigation.
enum MainTab {
  home,
  events,
  clubs,
  profile,
}

/// Extension for tab properties.
extension MainTabExtension on MainTab {
  String get label {
    switch (this) {
      case MainTab.home:
        return 'Home';
      case MainTab.events:
        return 'Events';
      case MainTab.clubs:
        return 'Clubs';
      case MainTab.profile:
        return 'Profile';
    }
  }

  String get path {
    switch (this) {
      case MainTab.home:
        return '/home';
      case MainTab.events:
        return '/events';
      case MainTab.clubs:
        return '/clubs';
      case MainTab.profile:
        return '/profile';
    }
  }

  int get index {
    switch (this) {
      case MainTab.home:
        return 0;
      case MainTab.events:
        return 1;
      case MainTab.clubs:
        return 2;
      case MainTab.profile:
        return 3;
    }
  }

  static MainTab fromIndex(int index) {
    switch (index) {
      case 0:
        return MainTab.home;
      case 1:
        return MainTab.events;
      case 2:
        return MainTab.clubs;
      case 3:
        return MainTab.profile;
      default:
        return MainTab.home;
    }
  }

  static MainTab fromPath(String path) {
    for (final tab in MainTab.values) {
      if (path.startsWith(tab.path)) {
        return tab;
      }
    }
    return MainTab.home;
  }
}

/// Provider for current main navigation tab.
final currentTabProvider = StateProvider<MainTab>((ref) {
  return MainTab.home;
});

/// Provider for current tab index (for compatibility with IndexedStack).
final currentTabIndexProvider = Provider<int>((ref) {
  return ref.watch(currentTabProvider).index;
});

/// State for home page tabs (For You / Following).
enum HomeTab { forYou, following }

/// Provider for current home tab.
final currentHomeTabProvider = StateProvider<HomeTab>((ref) {
  return HomeTab.forYou;
});
