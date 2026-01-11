import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/app/app.dart';
import 'package:myotherapp/core/services/notification_service.dart';
import 'package:myotherapp/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (optional - will skip if not configured)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize push notifications only if Firebase initialized successfully
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase initialization skipped: $e');
    debugPrint(
        'Push notifications will not be available until Firebase is configured.');
  }

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
