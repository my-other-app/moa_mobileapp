import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:finnet/app/app.dart';
import 'package:finnet/app/session_scope.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/cache/document_cache.dart';
import 'package:finnet/core/cache/image_caches.dart';
import 'package:finnet/core/services/analytics_service.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/features/discover/data/datasources/discover_place_store.dart';
import 'package:finnet/firebase_options.dart';

void main() async {
  // Errors are reported from three places, all through
  // AnalyticsService.crashReporter (Crashlytics, as the person chose in
  // Settings, with emails, phone numbers and tokens taken out):
  // FlutterError.onError and PlatformDispatcher.onError, set up by
  // AnalyticsService.initialize, and this zone for whatever runs in it.
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
      // Reported if Firebase itself started and the person allows it; the
      // app carries on without push.
      try {
        AnalyticsService.instance.crashReporter
            .recordNonFatal(e, stack, reason: 'during start-up');
      } catch (_) {}
    }

    // The place the discover lists are about, read before the first frame
    // so the first list is already asked about it. One store for the run:
    // a new session after sign-out keeps the place.
    final place = await FileDiscoverPlaceStore.open();

    runApp(
      SessionScope(
        overrides: [discoverPlaceStoreProvider.overrideWithValue(place)],
        child: const MyApp(),
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
    // An error nothing in the zone caught.
    debugPrint('Uncaught async error: $error');
    try {
      AnalyticsService.instance.recordUncaughtError(error, stack);
    } catch (_) {
      // Firebase did not start: AnalyticsService.instance throws.
    }
  });
}
