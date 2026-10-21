import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:finnet/app/app.dart';
import 'package:finnet/app/session_scope.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/services/analytics_service.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/firebase_options.dart';

void main() async {
  // Wrap app in zone to catch all async errors
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Firebase and Crashlytics come first, so errors from the very first
    // frame are reported. Neither waits on the network or on the person.
    var firebaseReady = false;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await AnalyticsService.instance.initialize();
      NotificationService.registerBackgroundHandler();
      firebaseReady = true;
      debugPrint('Firebase and Analytics initialized successfully');
    } catch (e, stack) {
      debugPrint('Firebase initialization error: $e');
      // Still record error if Crashlytics is available
      try {
        await FirebaseCrashlytics.instance.recordError(e, stack);
      } catch (_) {}
    }

    runApp(
      const SessionScope(
        child: MyApp(),
      ),
    );

    // The picture caches count files; this holds them to their bytes too.
    // Off the start-up path, and harmless if it fails.
    unawaited(AppImageCaches.trim());
    // The kept tickets and certificates, held to their cap.
    unawaited(DocumentCache.instance.trim());
    // Saved answers past their week, or over their caps, go the same way.
    unawaited(ApiCache.instance.prune());

    // Push set-up runs alongside the first frames, not ahead of them. It
    // used to be awaited here, and on iOS it asked for push permission and
    // then waited up to ten seconds for an APNs token before the app drew
    // anything. Permission is now asked for after sign-in.
    if (firebaseReady) {
      unawaited(NotificationService().initialize().catchError((Object e) {
        debugPrint('NotificationService initialization error: $e');
      }));
    }
  }, (error, stack) {
    // Catch all uncaught async errors
    debugPrint('Uncaught async error: $error');
    try {
      AnalyticsService.instance.recordUncaughtError(error, stack);
    } catch (_) {
      // Crashlytics not initialized
    }
  });
}
