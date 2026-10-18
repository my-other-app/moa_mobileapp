import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State for home page tabs (For You / Following).
enum HomeTab { forYou, following }

/// Provider for current home tab.
final currentHomeTabProvider = StateProvider<HomeTab>((ref) {
  return HomeTab.forYou;
});
