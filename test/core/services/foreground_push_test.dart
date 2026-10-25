// A push that arrives while the app is open is shown by the app itself (the
// system shows nothing then): with its picture on Android, on the app's own
// channel and status-bar icon, and tapped, it opens what it points at.

import 'dart:convert';

import 'package:finnet/core/services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

const _post = {
  'type': 'club_thread',
  'thread_id': '7d0f3c2a-1111-4c4c-9a9a-000000000001',
  'push_id': 'p-1',
};

RemoteMessage _push({
  String? title = 'Circuit Society posted',
  String? body = 'Demo day is on Friday',
  String? androidImage,
  Map<String, dynamic> data = _post,
}) =>
    RemoteMessage(
      messageId: 'm-1',
      data: data,
      notification: RemoteNotification(
        title: title,
        body: body,
        android: AndroidNotification(imageUrl: androidImage),
      ),
    );

void main() {
  group('what a push shows while the app is open', () {
    test("its title, its body, and the Android notification's picture", () {
      final showing = NotificationService.foregroundShowing(
          _push(androidImage: 'https://cdn.myotherapp.in/p/demo.jpg'))!;

      expect(showing.title, 'Circuit Society posted');
      expect(showing.body, 'Demo day is on Friday');
      expect(showing.imageUrl, 'https://cdn.myotherapp.in/p/demo.jpg');
    });

    test("without one, the data's image_url", () {
      final showing = NotificationService.foregroundShowing(_push(
          data: {..._post, 'image_url': 'https://cdn.myotherapp.in/p/x.png'}))!;

      expect(showing.imageUrl, 'https://cdn.myotherapp.in/p/x.png');
    });

    test('no picture, or a blank one: none', () {
      expect(NotificationService.foregroundShowing(_push())!.imageUrl, isNull);
      expect(
          NotificationService.foregroundShowing(
                  _push(data: {..._post, 'image_url': '  '}))!
              .imageUrl,
          isNull);
    });

    test('no title says "Notification"; no body, nothing', () {
      final showing =
          NotificationService.foregroundShowing(_push(title: null, body: null))!;

      expect(showing.title, 'Notification');
      expect(showing.body, '');
    });

    test('a data-only push shows nothing', () {
      expect(
          NotificationService.foregroundShowing(
              const RemoteMessage(data: _post)),
          isNull);
    });

    test('tapped, its payload opens the screen the push points at', () {
      final showing = NotificationService.foregroundShowing(_push())!;
      final data = jsonDecode(showing.payload) as Map<String, dynamic>;

      expect(data, _post);
      expect(NotificationService.routeFor(data),
          NotificationService.routeFor(_post));
      expect(NotificationService.routeFor(data), isNotNull);
    });
  });

  group('how it looks', () {
    void expectTheAppsChannelAndIcon(AndroidNotificationDetails android) {
      expect(android.channelId, NotificationService.androidChannelId);
      expect(android.channelId, 'high_importance_channel');
      expect(android.channelName, NotificationService.androidChannelName);
      expect(android.channelDescription,
          NotificationService.androidChannelDescription);
      // It drops down from the top, as a push does.
      expect(android.importance, Importance.high);
      expect(android.priority, Priority.high);
      expect(android.icon, '@drawable/ic_stat_notification');
      expect(android.color, NotificationService.androidAccent);
    }

    test(
        'with its picture: big under the text on Android, attached on an '
        'iPhone', () {
      final details = NotificationService.foregroundDetails(
        title: 'Circuit Society posted',
        body: 'Demo day is on Friday',
        picturePath: '/data/files/bigPicture-1.jpg',
      );

      final android = details.android!;
      expectTheAppsChannelAndIcon(android);
      final style = android.styleInformation;
      expect(style, isA<BigPictureStyleInformation>());
      style as BigPictureStyleInformation;
      expect(style.bigPicture, isA<FilePathAndroidBitmap>());
      expect((style.bigPicture as FilePathAndroidBitmap).data,
          '/data/files/bigPicture-1.jpg');
      expect(style.contentTitle, 'Circuit Society posted');
      expect(style.summaryText, 'Demo day is on Friday');
      expect(style.hideExpandedLargeIcon, isTrue);

      final ios = details.iOS!;
      expect(ios.attachments!.single.filePath, '/data/files/bigPicture-1.jpg');
      expect(ios.presentAlert, isTrue);
      expect(ios.presentSound, isTrue);
      expect(ios.presentBadge, isTrue);
    });

    test('without one (none sent, or it failed to download): the text alone, '
        'on the same channel and icon', () {
      final details = NotificationService.foregroundDetails(
        title: 'Circuit Society posted',
        body: 'Demo day is on Friday',
      );

      expectTheAppsChannelAndIcon(details.android!);
      expect(details.android!.styleInformation, isNull);
      expect(details.iOS!.attachments, isNull);
      expect(details.iOS!.presentAlert, isTrue);
    });
  });
}
