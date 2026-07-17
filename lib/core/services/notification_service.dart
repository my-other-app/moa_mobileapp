import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:finnet/core/api/api_helper.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

/// Service for handling push notifications via Firebase Cloud Messaging.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  String? _fcmToken;

  /// Get the current FCM token
  String? get fcmToken => _fcmToken;

  /// Force register FCM token with backend (e.g. after login)
  Future<void> registerToken() async {
    if (_fcmToken != null) {
      await _sendTokenToServer(_fcmToken!);
    } else {
      await _getToken();
    }
  }

  /// Initialize the notification service.
  /// Call this in main() after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (iOS)
    await _requestPermission();

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token
    await _getToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen(_handleTokenRefresh);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a notification
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _isInitialized = true;
    debugPrint('NotificationService initialized');
  }

  Future<void> _requestPermission() async {
    debugPrint('🔔 [Notifications] Requesting permission...');

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
        '🔔 [Notifications] Permission status: ${settings.authorizationStatus}');
    debugPrint('🔔 [Notifications] Alert: ${settings.alert}');
    debugPrint('🔔 [Notifications] Badge: ${settings.badge}');
    debugPrint('🔔 [Notifications] Sound: ${settings.sound}');

    // For iOS, we MUST wait for APNs token before getting FCM token
    if (Platform.isIOS) {
      debugPrint('🔔 [Notifications] iOS - Waiting for APNs token...');

      // Retry getting APNs token a few times
      String? apnsToken;
      for (int i = 0; i < 5; i++) {
        apnsToken = await _messaging.getAPNSToken();
        if (apnsToken != null) break;
        await Future.delayed(const Duration(seconds: 2));
        debugPrint(
            '🔔 [Notifications] Retry ${i + 1}/5 waiting for APNs token...');
      }

      debugPrint(
          '🔔 [Notifications] APNs token: ${apnsToken ?? "NULL - THIS IS THE PROBLEM!"}');

      if (apnsToken == null) {
        debugPrint(
            '🔔 [Notifications] ⚠️ APNs token is NULL! Push notifications will NOT work.');
        debugPrint(
            '🔔 [Notifications] Check: 1) Push capability in Xcode, 2) APNs key in Firebase, 3) Bundle ID matches');
        // Don't return here, try to get FCM token anyway, sometimes it works if APNs was cached
      }
    }
  }

  void _showToast(String message) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'high_importance_channel',
        'High Importance Notifications',
        description: 'This channel is used for important notifications.',
        importance: Importance.high,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> _getToken() async {
    debugPrint('🔔 [Notifications] Getting FCM token...');
    try {
      _fcmToken = await _messaging.getToken();
      debugPrint('🔔 [Notifications] FCM Token: ${_fcmToken ?? "NULL"}');

      if (_fcmToken != null) {
        debugPrint(
            '🔔 [Notifications] ✅ FCM token obtained, sending to server...');
        await _sendTokenToServer(_fcmToken!);
      } else {
        debugPrint(
            '🔔 [Notifications] ❌ FCM token is NULL - cannot register for push notifications');
        debugPrint(
            '🔔 [Notifications] This usually means APNs is not properly configured');
      }
    } catch (e, stackTrace) {
      debugPrint('🔔 [Notifications] ❌ Error getting FCM token: $e');
      debugPrint('🔔 [Notifications] Stack trace: $stackTrace');
      _showToast("Error getting FCM token: $e");
    }
  }

  void _handleTokenRefresh(String token) {
    _fcmToken = token;
    debugPrint('FCM Token refreshed: $token');
    _sendTokenToServer(token);
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      _showToast("Registering push token...");
      await APIService.instance.request(
        '/user/fcm-token',
        DioMethod.post,
        param: {
          'fcm_token': token,
          'platform': Platform.isIOS ? 'ios' : 'android'
        },
      );
      debugPrint('FCM token sent to server');
      _showToast("Push notifications enabled! ✅");
    } catch (e) {
      debugPrint('Error sending FCM token to server: $e');
      _showToast("Failed to register push token: $e");
    }
  }

  Future<String> _downloadAndSaveFile(String url, String fileName) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final String filePath = '${directory.path}/$fileName';
    final http.Response response = await http.get(Uri.parse(url));
    final File file = File(filePath);
    await file.writeAsBytes(response.bodyBytes);
    return filePath;
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('Received foreground message: ${message.messageId}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    // Show local notification for foreground messages
    if (notification != null) {
      _showLocalNotification(
        id: message.hashCode,
        title: notification.title ?? 'Notification',
        body: notification.body ?? '',
        payload: jsonEncode(message.data),
        imageUrl: android?.imageUrl ?? message.data['image_url'],
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('Notification tapped: ${message.messageId}');
    // TODO: Navigate to specific screen based on message.data
    // Example: if (message.data['type'] == 'event') navigateTo('/event/${message.data['id']}');
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    if (response.payload != null) {
      // TODO: Handle navigation based on payload
      // final data = jsonDecode(response.payload!);
    }
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    // Android Style
    AndroidNotificationDetails androidDetails;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final String bigPicturePath = await _downloadAndSaveFile(
            imageUrl, 'bigPicture-${DateTime.now().millisecondsSinceEpoch}');

        final BigPictureStyleInformation bigPictureStyleInformation =
            BigPictureStyleInformation(
          FilePathAndroidBitmap(bigPicturePath),
          hideExpandedLargeIcon: true,
          contentTitle: title,
          htmlFormatContentTitle: true,
          summaryText: body,
          htmlFormatSummaryText: true,
        );

        androidDetails = AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: bigPictureStyleInformation,
        );
      } catch (e) {
        debugPrint('Error downloading image for notification: $e');
        // Fallback to text only
        androidDetails = const AndroidNotificationDetails(
          'high_importance_channel',
          'High Importance Notifications',
          channelDescription:
              'This channel is used for important notifications.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        );
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        'high_importance_channel',
        'High Importance Notifications',
        channelDescription: 'This channel is used for important notifications.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );
    }

    // iOS Style
    DarwinNotificationDetails iosDetails;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final String bigPicturePath = await _downloadAndSaveFile(imageUrl,
            'bigPicture-${DateTime.now().millisecondsSinceEpoch}.jpg');

        iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          attachments: [DarwinNotificationAttachment(bigPicturePath)],
        );
      } catch (e) {
        debugPrint('Error downloading image for iOS notification: $e');
        iosDetails = const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
      }
    } else {
      iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
    }

    NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(id, title, body, details, payload: payload);
  }

  /// Subscribe to a topic for targeted notifications
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }
}
