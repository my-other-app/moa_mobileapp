import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The number on the app's icon on an iPhone: the person's unread inbox
/// count (`GET /notifications/unread-count`), and 0 when nothing is unread
/// or nobody is signed in.
///
/// It was only ever set by pushes, and the server sent every one with a
/// badge of 1: after one push the icon said 1 for good, whatever was read.
/// Now the app sets it whenever it learns the count -- at start-up, each
/// time it comes to the front (a tap on a push included), and when the
/// inbox is read or a line is marked read (NotificationsNotifier) -- and
/// clears it when the session ends (AuthStateNotifier).
///
/// Through a method channel of the app's own (`AppIconBadge` in
/// ios/Runner/AppDelegate.swift): `UNUserNotificationCenter.setBadgeCount`
/// from iOS 16, `applicationIconBadgeNumber` before. Elsewhere it does
/// nothing: Android's launcher dots follow the notifications in the tray.
///
/// Every count is sent, even one equal to the last: a push can change the
/// number on the icon while the app is in the background, so the app never
/// knows what the icon says now.
class AppBadge {
  AppBadge({MethodChannel? channel, bool? supported})
      : _channel = channel ?? const MethodChannel(channelName),
        _supported = supported ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS);

  /// The channel's name, as AppDelegate.swift registers it.
  static const channelName = 'finnet/app_badge';

  /// The one the app uses ([appBadgeProvider]).
  static final AppBadge instance = AppBadge();

  final MethodChannel _channel;
  final bool _supported;

  /// Put [unread] on the icon (0 takes the number away). Never throws: a
  /// badge that cannot be set -- notifications not allowed, say -- is
  /// left as it is.
  Future<void> show(int unread) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('set', unread < 0 ? 0 : unread);
    } catch (e) {
      debugPrint('AppBadge: could not set the badge: $e');
    }
  }

  /// No number on the icon.
  Future<void> clear() => show(0);
}

/// The icon's badge. A provider so tests can swap it.
final appBadgeProvider = Provider<AppBadge>((ref) => AppBadge.instance);
