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
import 'package:finnet/core/services/push_arrivals.dart';
import 'package:finnet/core/services/push_dedupe.dart';
import 'package:finnet/core/services/push_topics.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/shared/utils/external_links.dart';
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

  /// The Android channel every push is shown on: created at start-up, and
  /// named in the manifest as FCM's default
  /// (`com.google.firebase.messaging.default_notification_channel_id`), so
  /// a push the system shows while the app is in the background lands here
  /// too rather than in "Miscellaneous". The id is the one the app has
  /// always used: a channel's importance is fixed once created on a phone.
  static const androidChannelId = 'high_importance_channel';
  static const androidChannelName = 'Events and clubs';
  static const androidChannelDescription =
      'Reminders, check-ins, live updates and posts from clubs you follow.';

  /// The status-bar icon: white on transparent, as Android draws it. The
  /// launcher icon there was a white blob. Named in the manifest too
  /// (`default_notification_icon`), for pushes the system shows itself.
  static const androidSmallIcon = '@drawable/ic_stat_notification';

  /// The accent Android tints the small icon and the app name with.
  static const androidAccent = Color(0xFF17A58F);

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
      if (initialMessage != null &&
          // The launch tap counts as this push's one opening: a second copy
          // tapped later (the same push_id) opens nothing again.
          dedupe.firstOpen(initialMessage.data)) {
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
        holdLaunchPayload(launch?.notificationResponse?.payload);
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
        AndroidInitializationSettings(androidSmallIcon);

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
        androidChannelId,
        androidChannelName,
        description: androidChannelDescription,
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
    // Its line is in the inbox already (the server writes it before it
    // sends): have the inbox read itself now, not when it is next opened.
    PushArrivals.arrived();

    // Show local notification for foreground messages
    final showing = foregroundShowing(message);
    if (showing != null) {
      _showLocalNotification(
        id: message.hashCode,
        title: showing.title,
        body: showing.body,
        payload: showing.payload,
        imageUrl: showing.imageUrl,
      );
    }
  }

  /// What a push that arrives while the app is open shows, as a local
  /// notification: its title (or "Notification") and body, its data as the
  /// tap's payload, and its picture -- the Android notification's image,
  /// else the data's `image_url`. Null for a data-only push, which shows
  /// nothing.
  @visibleForTesting
  static ({String title, String body, String payload, String? imageUrl})?
      foregroundShowing(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return null;
    final image = notification.android?.imageUrl ?? message.data['image_url'];
    return (
      title: notification.title ?? 'Notification',
      body: notification.body ?? '',
      payload: jsonEncode(message.data),
      imageUrl: image is String && image.trim().isNotEmpty ? image : null,
    );
  }

  /// How a push shown while the app is open looks: on the app's own channel
  /// (high importance, so it drops down) with its status-bar icon and
  /// accent. With [picturePath] -- its picture, downloaded -- the picture
  /// expanded under the text on Android, and attached on an iPhone; without
  /// one, the text alone.
  @visibleForTesting
  static NotificationDetails foregroundDetails({
    required String title,
    required String body,
    String? picturePath,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannelId,
        androidChannelName,
        channelDescription: androidChannelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: androidSmallIcon,
        color: androidAccent,
        styleInformation: picturePath == null
            ? null
            : BigPictureStyleInformation(
                FilePathAndroidBitmap(picturePath),
                hideExpandedLargeIcon: true,
                contentTitle: title,
                htmlFormatContentTitle: true,
                summaryText: body,
                htmlFormatSummaryText: true,
              ),
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        attachments: picturePath == null
            ? null
            : [DarwinNotificationAttachment(picturePath)],
      ),
    );
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
  /// that event, whose page shows the room's strip. A host starting a quiz
  /// or a poll (`event_live_join`) opens the event and, on top of it, the
  /// live room in the app ([liveJoinRoute]), so Back lands on the event. A
  /// club's new post (`club_thread`) opens that post; if it has been removed
  /// since, its page says so. The check-in push (`event_checkin`) opens
  /// People Like You when it says `open: people`, else the event.
  ///
  /// Any other push that carries a `url` to the website opens the app's
  /// screen for that address (`/events/{slug}`, `/clubs/{slug}`, ...: see
  /// web_links.dart). A `url` the app has no screen for opens in the
  /// browser instead ([webUrlFor]).
  static String? routeFor(Map<String, dynamic> data) =>
      _typedRoute(data) ?? _urlRoute(data);

  /// The website (or other) address a push opens outside the app's own
  /// screens: its `url`, when the app has no screen for it -- a feedback
  /// survey, say. Only http(s).
  static Uri? webUrlFor(Map<String, dynamic> data) {
    if (routeFor(data) != null) return null;
    final url = _url(data);
    if (url == null || !(url.isScheme('https') || url.isScheme('http'))) {
      return null;
    }
    return url;
  }

  static Uri? _url(Map<String, dynamic> data) {
    final text = data['url']?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return Uri.tryParse(text);
  }

  static String? _urlRoute(Map<String, dynamic> data) {
    final url = _url(data);
    if (url == null) return null;
    // Absolute links only: a bare path is not the server's to send.
    if (!url.hasScheme) return null;
    return webLocation(url);
  }

  static String? _typedRoute(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == 'club_thread') {
      final threadId = data['thread_id']?.toString().trim();
      if (threadId == null || threadId.isEmpty) return null;
      return '/threads/${Uri.encodeComponent(threadId)}';
    }
    final eventId = int.tryParse(data['event_id']?.toString().trim() ?? '');
    if (eventId != null) {
      if (type == 'event_live_join') {
        return liveJoinRoute(eventId, data['what']);
      }
      if (type == 'event_checkin' && data['open']?.toString() == 'people') {
        return '/events/$eventId/people';
      }
      if (type == 'event_live_update' || type == 'event_reminder' || type == 'event_started' || type == 'event_checkin') {
        return '/events/$eventId';
      }
    }
    return null;
  }

  /// The event's page, told to open its live room at once: what a "join
  /// now" push and its inbox row open. [what] is the push's `what` (`quiz`
  /// or `poll`); anything else is just the room.
  static String liveJoinRoute(int eventId, Object? what) {
    final kind = what == 'quiz' || what == 'poll' ? what as String : 'room';
    return '/events/$eventId?live=$kind';
  }

  /// A local notification's payload that launched the app: held to open
  /// once the app is up, and counted as that push's one opening.
  @visibleForTesting
  static void holdLaunchPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map && dedupe.firstOpen(Map<String, dynamic>.from(data))) {
        pendingLaunch.holdPayload(payload);
      }
    } catch (_) {
      // Not ours: nothing to open.
    }
  }

  void openFromData(Map<String, dynamic> data) {
    // A tap on a second copy of a push already opened does nothing.
    if (!dedupe.firstOpen(data)) return;
    final route = routeFor(data);
    if (route == null) {
      final url = webUrlFor(data);
      // Our own pages inside the app; anything else in the browser.
      if (url != null) {
        unawaited(
            isOwnSite(url) ? openInAppThenBrowser(url) : openExternally(url));
      }
      return;
    }
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).push(route);
  }

  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? imageUrl,
  }) async {
    // The picture, downloaded once -- it was fetched twice, once for each
    // platform's details, on every phone. A .jpg name: an iPhone's
    // attachment is typed by it; Android reads the file whatever its name.
    String? picturePath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        picturePath = await _downloadAndSaveFile(imageUrl,
            'bigPicture-${DateTime.now().millisecondsSinceEpoch}.jpg');
      } catch (e) {
        // The text alone, then.
        debugPrint('Error downloading image for notification: $e');
      }
    }

    await _localNotifications.show(
      id,
      title,
      body,
      foregroundDetails(title: title, body: body, picturePath: picturePath),
      payload: payload,
    );
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
