import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/app/app.dart';
import 'package:finnet/core/services/analytics_service.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/firebase_options.dart';

void main() async {
  // Wrap app in zone to catch all async errors
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize Crashlytics and Analytics
      await AnalyticsService.instance.initialize();

      // Initialize push notifications
      await NotificationService().initialize();

      debugPrint('Firebase and Analytics initialized successfully');
    } catch (e, stack) {
      debugPrint('Firebase initialization error: $e');
      // Still record error if Crashlytics is available
      try {
        await FirebaseCrashlytics.instance.recordError(e, stack);
      } catch (_) {}
    }

    runApp(
      const ProviderScope(
        child: MyApp(),
      ),
    );
  }, (error, stack) {
    // Catch all uncaught async errors
    debugPrint('Uncaught async error: $error');
    try {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    } catch (_) {
      // Crashlytics not initialized
    }
  });
}
