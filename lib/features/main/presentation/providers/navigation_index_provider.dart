import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The bottom bar's selected tab: 0 home, 1 events, 2 clubs, 3 profile.
///
/// The one tab index in the app. There used to be three: the bar read this,
/// sign-out reset `bottomNavIndexProvider`, and `currentTabProvider` was
/// read by nothing -- so after signing out from the Profile tab and back in,
/// the bar still had Profile selected over the home page.
final navigationIndexProvider = StateProvider<int>((ref) => 0);
