import 'package:flutter/foundation.dart';

/// Counts the pushes that arrived while the app was open, so what shows
/// their lines -- the inbox -- can read itself again at once rather than
/// the next time it is opened. Bumped by the push service; listened to by
/// `PersonalDataSync`. A plain counter, kept apart from the push service so
/// a listener does not have to load Firebase to hear it.
class PushArrivals {
  PushArrivals._();

  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  static void arrived() => count.value++;
}
