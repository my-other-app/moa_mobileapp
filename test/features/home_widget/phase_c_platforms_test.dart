import 'dart:io';

import 'package:finnet/features/home_widget/data/event_day_platform.dart';
import 'package:finnet/features/home_widget/data/for_you_store.dart';
import 'package:finnet/features/home_widget/domain/event_day.dart';
import 'package:finnet/features/home_widget/domain/events_for_you.dart';
import 'package:finnet/features/home_widget/presentation/for_you_widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

/// "For you" and the event-day card live in three languages: the names,
/// keys, fields and gates that have to agree, and what the native sides
/// may and may not hold.
void main() {
  String read(String path) => File(path).readAsStringSync();
  const kotlin = 'android/app/src/main/kotlin/app/myotherapp/com';
  const swift = 'ios/NextUpWidget';
  final manifest = read('android/app/src/main/AndroidManifest.xml');

  group('"For you"', () {
    test('the data key, the kind and the provider match', () {
      expect(read('$kotlin/widget/ForYouData.kt'),
          contains('const val DATA_KEY = "${ForYouKind.dataKey}"'));
      expect(read('$swift/ForYouData.swift'),
          contains('static let dataKey = "${ForYouKind.dataKey}"'));
      expect(read('$swift/ForYouWidget.swift'),
          contains('let kind = "${ForYouKind.iOSKind}"'));
      expect(read('$swift/WidgetBundle.swift'), contains('ForYouWidget()'));
      final provider = ForYouKind.androidProvider.split('.').last;
      expect(File('$kotlin/widget/$provider.kt').existsSync(), isTrue);
      expect(manifest, contains('android:name=".widget.$provider"'));
    });

    test('the same links, sizes and limits on every side', () {
      final kt = read('$kotlin/widget/ForYouData.kt');
      final sw = read('$swift/ForYouData.swift');
      expect(kt, contains('const val SEE_ALL_LINK = "$forYouSeeAllLink"'));
      expect(sw, contains('static let seeAllLink = "$forYouSeeAllLink"'));
      expect(kt, contains('const val MEDIUM_ROWS = $forYouMediumRows'));
      expect(kt, contains('const val LARGE_ROWS = $forYouLargeRows'));
      expect(sw, contains('static let mediumRows = $forYouMediumRows'));
      expect(sw, contains('static let largeRows = $forYouLargeRows'));
      expect(kt, contains('const val LIMIT = $forYouLimit'));
      expect(sw, contains('static let limit = $forYouLimit'));
      for (final header in ForYouHeader.values) {
        expect(kt, contains('"${header.words}"'), reason: header.name);
        expect(sw, contains('"${header.words}"'), reason: header.name);
      }
      // Asked again three hours after a read.
      expect(kt, contains('REFRESH_EVERY_MS = 3 * 60 * 60 * 1000L'));
      expect(sw, contains('refreshEvery: TimeInterval = 3 * 3600'));
    });

    test('the widgets ask only the public page, with no token', () {
      for (final file in [
        '$kotlin/widget/ForYouRefreshWorker.kt',
        '$kotlin/widget/ForYouData.kt',
        '$swift/ForYouData.swift',
        '$swift/ForYouWidget.swift',
      ]) {
        final text = read(file);
        // The address is made in ForYouData; the others take it from there.
        if (file.contains('ForYouData')) {
          expect(text, contains('/discover/home'), reason: file);
        }
        for (final secret in [
          'Authorization',
          'Bearer',
          'access_token',
          'Cookie'
        ]) {
          expect(text, isNot(contains(secret)), reason: '$file: $secret');
        }
      }
      // Over https only.
      expect(read('$kotlin/widget/ForYouData.kt'),
          contains('uri.scheme != "https"'));
      expect(
          read('$swift/ForYouData.swift'), contains('parts.scheme == "https"'));
      // With the last answer's ETag.
      expect(read('$kotlin/widget/ForYouRefreshWorker.kt'),
          contains('If-None-Match'));
      expect(read('$swift/ForYouData.swift'), contains('If-None-Match'));
    });

    test('the app\'s default API is the one the widgets fall back to', () {
      expect(
          read('$kotlin/widget/ForYouData.kt'),
          contains(
              'const val DEFAULT_API = "https://api.myotherapp.in/api/v1"'));
      expect(
          read('$swift/ForYouData.swift'),
          contains(
              'static let defaultApi = "https://api.myotherapp.in/api/v1"'));
    });

    test(
        'Android: WorkManager on any network, every three hours; home screen only',
        () {
      final worker = read('$kotlin/widget/ForYouRefreshWorker.kt');
      expect(worker, contains('NetworkType.CONNECTED'));
      expect(worker, contains('3, TimeUnit.HOURS'));
      expect(worker, contains('ExistingPeriodicWorkPolicy.KEEP'));
      final gradle = read('android/app/build.gradle');
      // The version home_widget 0.10.0 already brings.
      expect(gradle,
          contains("implementation 'androidx.work:work-runtime:2.11.2'"));
      final info = read('android/app/src/main/res/xml/for_you_widget_info.xml');
      expect(info, contains('android:widgetCategory="home_screen"'));
      // Rows 2 and 3 exist only in the large layout, which only it fills.
      final medium =
          read('android/app/src/main/res/layout/widget_for_you_medium.xml');
      expect(medium, contains('for_you_row_1'));
      expect(medium, isNot(contains('for_you_row_2')));
      expect(read('android/app/src/main/res/layout/widget_for_you_large.xml'),
          contains('for_you_row_3'));
    });

    test('iOS: medium and large on the home screen only', () {
      final widget = read('$swift/ForYouWidget.swift');
      expect(widget,
          contains('.supportedFamilies([.systemMedium, .systemLarge])'));
      expect(widget, isNot(contains('accessory')));
      expect(widget, contains('policy: .after('));
    });
  });

  group('the event-day card', () {
    final card = EventDayCard(
      eventId: 7,
      name: 'DevFest Kochi',
      startsAt: DateTime.utc(2026, 11, 28, 4),
      endsAt: DateTime.utc(2026, 11, 28, 12),
      place: 'Le Méridien, Kochi',
    );

    test('one channel name on every side', () {
      expect(ChannelEventDayPlatform.channel.name, 'finnet/event_day');
      expect(read('$kotlin/eventday/EventDayNotifications.kt'),
          contains('const val CHANNEL = "finnet/event_day"'));
      expect(read('ios/Runner/EventDayActivities.swift'),
          contains('static let channelName = "finnet/event_day"'));
      expect(read('$kotlin/MainActivity.kt'),
          contains('EventDayNotifications.register('));
      expect(read('ios/Runner/AppDelegate.swift'),
          contains('EventDayActivities.register(with: registrar)'));
    });

    test('the native sides read the fields Dart sends, and nothing of a ticket',
        () {
      final fields = card.toChannel().keys.toSet()..remove('date');
      final kt = read('$kotlin/eventday/EventDayCard.kt');
      final sw = read('ios/Runner/EventDayActivities.swift');
      for (final field in fields) {
        expect(kt, contains('map["$field"]'), reason: 'Kotlin: $field');
        expect(sw, contains('map["$field"]'), reason: 'Swift: $field');
      }
      for (final text in [kt, sw, read('$swift/EventDayAttributes.swift')]) {
        // No field for a ticket's code, link or QR (the comments say so).
        for (final secret in [
          '"code"',
          '"ticket_url"',
          'ticketUrl',
          '"qr',
          'ticketCode'
        ]) {
          expect(text, isNot(contains(secret)), reason: secret);
        }
      }
      // Only the website's https address is opened.
      expect(
          kt, contains('uri.scheme == "https" && uri.host == "myotherapp.in"'));
      expect(read('$swift/EventDayAttributes.swift'),
          contains('url.scheme == "https" && url.host == "myotherapp.in"'));
    });

    test('iOS: a Live Activity from 16.1, in the one extension, no push', () {
      final bundle = read('$swift/WidgetBundle.swift');
      final gate = RegExp(r'if #available\(iOS 16\.1, \*\) \{([^}]*)\}')
          .firstMatch(bundle)![1]!;
      expect(gate, contains('EventDayLiveActivity()'));
      expect(read('ios/Runner/Info.plist'),
          contains('<key>NSSupportsLiveActivities</key>\n\t<true/>'));
      final runner = read('ios/Runner/EventDayActivities.swift');
      expect(runner, contains('pushType: nil'));
      expect(runner, isNot(contains('pushType: .token')));
      expect(runner, contains('areActivitiesEnabled'));
      final activity = read('$swift/EventDayLiveActivity.swift');
      for (final part in [
        'compactLeading',
        'compactTrailing',
        'minimal',
        'DynamicIslandExpandedRegion'
      ]) {
        expect(activity, contains(part));
      }
      // The countdown runs on the system's clock.
      expect(
          read('$swift/EventDayViews.swift'), contains('Text(timerInterval:'));
    });

    test('Android: a quiet channel of its own, a countdown, the permission',
        () {
      final kt = read('$kotlin/eventday/EventDayNotifications.kt');
      expect(kt, contains('const val CHANNEL_ID = "event_day"'));
      expect(kt, contains('setChronometerCountDown(true)'));
      expect(kt, contains('setUsesChronometer(soon)'));
      expect(kt, contains('setOngoing(true)'));
      expect(kt, contains('areNotificationsEnabled()'));
      expect(kt, contains('IMPORTANCE_NONE'));
      expect(kt, contains('setTimeoutAfter('));
      expect(kt, contains('channel.setSound(null, null)'));
      expect(kt, contains('PageTiles.intentFor(context, link)'));
      expect(
          manifest,
          contains(
              '<receiver\n          android:name=".eventday.EventDayReceiver"\n'
              '          android:exported="false" />'));
      expect(read('android/app/src/main/res/values/event_day.xml'),
          contains('<string name="event_day_channel">Event day</string>'));
    });

    test('the card goes no earlier than the Live Activity\'s eight hours', () {
      expect(eventDayLead, const Duration(hours: 8));
      expect(forYouApiBaseProvider, isNotNull);
    });
  });
}
