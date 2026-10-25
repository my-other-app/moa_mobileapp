import 'dart:async';

import 'package:flutter/widgets.dart';

/// Draws [app], then starts [pushSetUp] alongside the first frames -- never
/// ahead of them, and never awaited.
///
/// Push set-up used to be awaited before the app was drawn, and on iOS it
/// asked for push permission and then waited up to ten seconds for an APNs
/// token before anything showed. Permission is now asked for after sign-in.
/// A set-up that fails is logged, not thrown: the app carries on without
/// push. [pushSetUp] is null when Firebase did not start.
void runAppThenStartPush(
  Widget app, {
  Future<void> Function()? pushSetUp,
  @visibleForTesting void Function(Widget app) run = runApp,
}) {
  run(app);
  final setUp = pushSetUp;
  if (setUp == null) return;
  unawaited(Future<void>.sync(setUp).catchError((Object e) {
    debugPrint('NotificationService initialization error: $e');
  }));
}
