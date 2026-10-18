import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/network/interceptors/topic_change_interceptor.dart';
import 'package:finnet/core/services/pending_notification_route.dart';
import 'package:finnet/core/services/push_dedupe.dart';
import 'package:finnet/core/services/push_topics.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/app/router/app_router.dart';
import 'package:go_router/go_router.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
}

/// Service for handling push notifications via Firebase Cloud Messaging.
///
/// Start-up does not wait on any of this. [initialize] used to run before
/// `runApp`, asking for push permission and then waiting up to ten seconds
/// for an APNs token, so an iPhone showed a blank screen and a permission
/// prompt before it showed the app. Now `main` starts the app first and runs
/// [initialize] alongside it; permission is asked for once the person has
/// signed in ([requestPermissionAndRegister]), and the token is sent only
/// while someone is signed in.
///
/// Broadcasts (a club's posts and events, new events in your topics,
/// announcements) can reach the device through FCM topics: once signed in it
/// subscribes to the topics the server lists for its person
/// ([TopicReconciler]) -- on start, on sign-in, after a follow, a mute or a
/// change of interests -- and leaves them on sign-out. Its token goes to the
/// server with `topics: 1` once it is in all of them. A push the server sent
/// twice (the same `push_id`) is shown and opened once ([PushDedupe]).
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final SecureStorageService _storage = SecureStorageService();

  Future<void>? _initializing;
  String? _fcmToken;

  late final TopicReconciler _topics = TopicReconciler(
    source: DioPushTopicSource(APIService.instance.dio),
    messaging: FirebaseTopicMessaging(_messaging),
    store: SecureAppliedTopicsStore(_storage),
  );
  Timer? _topicsSoon;

  /// Each push shown and opened once, by its `push_id`.
  static final PushDedupe dedupe = PushDedupe();

  /// A token deletion still running from the last sign-out. A token fetched
  /// before it finishes would be the one being deleted.
  Future<void>? _tokenDeletion;

  /// Where the notification that launched the app points, until the splash
  /// screen opens it. Static so it can be read without touching Firebase.
  static final PendingNotificationRoute pendingLaunch =
      PendingNotificationRoute(routeFor);

  /// Get the current FCM token
  String? get fcmToken => _fcmToken;

  /// Register the handler for messages that arrive while the app is in the
  /// background or closed. Cheap and synchronous: call it in `main` before
  /// `runApp`.
  static void registerBackgroundHandler() {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// Set up message handling. Asks for nothing and waits on nothing slow;
  /// safe to run without awaiting, alongside `runApp`.
  Future<void> initialize() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    // Was the app launched by a tap? Read first, ahead of anything slower:
    // the splash screen takes it 1.5 s after start-up and opens it once it
    // has routed home.
    try {
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App launched by notification: ${initialMessage.messageId}');
        pendingLaunch.hold(initialMessage.data);
      }
    } catch (e) {
      debugPrint('NotificationService: could not read the launch message: $e');
    }

    try {
      await _initializeLocalNotifications();
      // The same for a tap on a local notification -- a push re-shown while
      // the app was in the foreground, then tapped after it was closed.
      final launch =
          await _localNotifications.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        pendingLaunch.holdPayload(launch?.notificationResponse?.payload);
      }
    } catch (e) {
      debugPrint('NotificationService: local notifications unavailable: $e');
    }

    _messaging.onTokenRefresh.listen(_handleTokenRefresh);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
    // A follow, a mute, saved interests: the topic list may have changed.
    TopicChangeInterceptor.listener = refreshTopics;

    debugPrint('NotificationService initialized');
  }

  /// Ask for permission to show notifications, then register this device.
  ///
  /// Call after sign-in, not at start-up. The system shows its prompt only
  /// while the answer is undecided; after that this just registers.
  Future<void> requestPermissionAndRegister() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint(
          'NotificationService: permission ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('NotificationService: permission request failed: $e');
    }
    await syncToken();
  }

  /// Send this device's push token to the server, if someone is signed in.
  /// Asks for nothing.
  Future<void> syncToken() async {
    try {
      if (!await _isSignedIn()) return;
      await _tokenDeletion;
      // On iOS the FCM token needs the APNs token, which can take a few
      // seconds to arrive after launch. This runs in the background now, so
      // the wait no longer holds up anything the person can see.
      if (Platform.isIOS && !await _waitForApnsToken()) {
        debugPrint('NotificationService: no APNs token yet; '
            'the token refresh listener will register it when it arrives');
        return;
      }
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('NotificationService: no FCM token');
        return;
      }
      _fcmToken = token;
      await _register(token);
    } catch (e) {
      debugPrint('NotificationService: could not register the push token: $e');
    }
  }

  /// Send the token -- saying whether this device is already in all of its
  /// person's topics, which the last reconcile kept -- then reconcile the
  /// topics, and say it again if that is what made the device ready. The
  /// token is never held up by the topics: they can be a few hundred calls.
  Future<void> _register(String token) async {
    final ready = await _topics.readyFor(token);
    await _sendTokenToServer(token, topics: ready);
    if (await _syncTopics(token) && !ready) {
      await _sendTokenToServer(token, topics: true);
    }
  }

  /// Bring this device's topics in line with the server's list; true when
  /// the device is in all of them now.
  Future<bool> _syncTopics(String token) async {
    try {
      final result = await _topics.reconcile(token);
      debugPrint('NotificationService: topics ${result.name}');
      return result == TopicSync.applied || result == TopicSync.upToDate;
    } catch (e) {
      debugPrint('NotificationService: could not reconcile topics: $e');
      return false;
    }
  }

  /// Reconcile the topics soon: after a follow, a mute, saved interests or a
  /// notification switch (TopicChangeInterceptor). A burst of them -- five
  /// follows from the club list -- is one reconcile, two seconds after the
  /// last. Nothing while signed out or before the token is known.
  void refreshTopics() {
    _topicsSoon?.cancel();
    _topicsSoon = Timer(const Duration(seconds: 2), () async {
      final token = _fcmToken;
      if (token == null || !await _isSignedIn()) return;
      final wasReady = await _topics.readyFor(token);
      if (await _syncTopics(token) && !wasReady) {
        await _sendTokenToServer(token, topics: true);
      }
    });
  }

  /// Tell the server to forget this device's push token, while the session
  /// that registered it is still good. Best effort -- never throws.
  ///
  /// Call before the session is revoked and before [unregister], which
  /// forgets the token.
  Future<void> unregisterOnServer() async {
    try {
      final token = _fcmToken ?? await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      await deletePushTokenOnServer(APIService.instance.dio, token);
    } catch (e) {
      debugPrint('NotificationService: could not read the push token: $e');
    }
  }

  /// Stop this device receiving the signed-out person's notifications.
  ///
  /// The token itself is deleted: FCM then refuses sends to it, even where
  /// the server still holds it (an older server, or a session that ended
  /// before [unregisterOnServer] could run), and the next person to sign in
  /// on this device registers a fresh one. Best effort -- never throws.
  Future<void> unregister() async {
    _topicsSoon?.cancel();
    // Out of the person's topics first: deleting the token ends them too,
    // but a token that could not be deleted (offline) would keep them.
    try {
      await _topics.clear().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('NotificationService: could not leave the topics: $e');
    }
    _fcmToken = null;
    final deletion = _messaging.deleteToken().timeout(
          const Duration(seconds: 10),
        );
    _tokenDeletion = deletion.catchError((Object e) {
      debugPrint('NotificationService: could not delete the push token: $e');
    });
    await _tokenDeletion;
  }

  Future<bool> _waitForApnsToken() async {
    for (var attempt = 0; attempt < 5; attempt++) {
      if (await _messaging.getAPNSToken() != null) return true;
      await Future.delayed(const Duration(seconds: 2));
    }
    return false;
  }

  Future<bool> _isSignedIn() async {
    try {
      final token = await _storage.getAccessToken();
      return token != null && token.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // No permission requests here: that waits for sign-in.
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

  Future<void> _handleTokenRefresh(String token) async {
    _fcmToken = token;
    debugPrint('NotificationService: FCM token refreshed');
    if (await _isSignedIn()) await _register(token);
  }

  Future<void> _sendTokenToServer(String token, {required bool topics}) =>
      registerPushTokenOnServer(
        APIService.instance.dio,
        token,
        platform: Platform.isIOS ? 'ios' : 'android',
        topics: topics,
      );

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
    // A second copy of a broadcast (the same push_id): shown once.
    if (!dedupe.firstShow(message.data)) return;

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
    openFromData(message.data);
  }

  void _handleLocalNotificationTap(NotificationResponse response) {
    debugPrint('Local notification tapped: ${response.payload}');
    if (response.payload == null) return;
    try {
      final data = jsonDecode(response.payload!);
      if (data is Map) openFromData(Map<String, dynamic>.from(data));
    } catch (_) {
      // A payload that is not ours; nothing to open.
    }
  }

  /// Where a notification's data points. A live update from an event opens
  /// that event, whose page shows the room's strip. A club's new post
  /// (`club_thread`) opens that post; if it has been removed since, its page
  /// says so.
  static String? routeFor(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == 'club_thread') {
      final threadId = data['thread_id']?.toString().trim();
      if (threadId == null || threadId.isEmpty) return null;
      return '/threads/${Uri.encodeComponent(threadId)}';
    }
    final eventId = data['event_id']?.toString();
    if (eventId != null && eventId.isNotEmpty && int.tryParse(eventId) != null) {
      if (type == 'event_live_update' || type == 'event_reminder' || type == 'event_started' || type == 'event_checkin') {
        return '/events/$eventId';
      }
    }
    return null;
  }

  void openFromData(Map<String, dynamic> data) {
    // A tap on a second copy of a push already opened does nothing.
    if (!dedupe.firstOpen(data)) return;
    final route = routeFor(data);
    final context = rootNavigatorKey.currentContext;
    if (route == null || context == null) return;
    GoRouter.of(context).push(route);
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

/// `POST /user/fcm-token`: this device gets its person's pushes. With
/// [topics], it also says it is in all of its person's FCM topics
/// (`topics: 1`), and the server stops sending it broadcasts one by one; an
/// older server ignores the field. Without, the body is what it always was.
/// Never throws.
@visibleForTesting
Future<void> registerPushTokenOnServer(
  Dio dio,
  String token, {
  required String platform,
  required bool topics,
}) async {
  try {
    await dio.post<dynamic>('/user/fcm-token', data: {
      'fcm_token': token,
      'platform': platform,
      if (topics) 'topics': 1,
    });
    debugPrint('NotificationService: FCM token sent to server');
  } catch (e) {
    debugPrint('NotificationService: could not send the FCM token: $e');
  }
}

/// `DELETE /user/fcm-token {"token": ...}`: the server stops sending this
/// device the signed-out person's notifications.
///
/// Idempotent on the server (204 whether or not it held the token). A server
/// from before the endpoint existed answers 404 or 405; that is ignored, and
/// [NotificationService.unregister] deleting the token covers it. Never
/// throws.
@visibleForTesting
Future<void> deletePushTokenOnServer(Dio dio, String token) async {
  try {
    await dio.delete('/user/fcm-token', data: {'token': token});
    debugPrint('NotificationService: push token removed on the server');
  } catch (e) {
    final status = statusCodeOf(e);
    if (status == 404 || status == 405) return;
    debugPrint('NotificationService: could not remove the push token: $e');
  }
}
