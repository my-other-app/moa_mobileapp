import 'dart:io';

import 'package:finnet/app/router/app_router.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/core/services/push_dedupe.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pushes that carry a link to the website, and the Android settings that
/// decide how every push looks. `routeFor` is static and pure: no Firebase.
void main() {
  group('a push with a url', () {
    test('opens the app\'s screen for a website address', () {
      expect(
        NotificationService.routeFor(const {
          'type': 'announcement',
          'url': 'https://myotherapp.in/events/hack-night-04',
        }),
        '/events/hack-night-04',
      );
      expect(
        NotificationService.routeFor(const {
          'url': 'https://myotherapp.in/clubs/circuit-society?ref=push',
        }),
        '/clubs/circuit-society?ref=push',
      );
      expect(
        NotificationService.routeFor(const {
          'url': 'https://www.myotherapp.in/events/hack-night-04/live',
        }),
        '/events/hack-night-04?live=room',
      );
    });

    test('the feedback survey opens in the app', () {
      expect(
        NotificationService.routeFor(const {
          'type': 'event_feedback',
          'url': 'https://myotherapp.in/feedback/12/34?k=abc',
        }),
        '/feedback/12/34?k=abc',
      );
    });

    test('a page the app does not have opens in the browser instead', () {
      const quiz = {
        'type': 'something_new',
        'url': 'https://myotherapp.in/play/12',
      };
      expect(NotificationService.routeFor(quiz), isNull);
      expect(NotificationService.webUrlFor(quiz).toString(),
          'https://myotherapp.in/play/12');
      expect(
        NotificationService.webUrlFor(const {'url': 'https://example.com/x'})
            .toString(),
        'https://example.com/x',
      );
      // One the app has is never also opened in the browser.
      expect(
          NotificationService.webUrlFor(
              const {'url': 'https://myotherapp.in/events/x'}),
          isNull);
    });

    test('the types the app knows keep their own routes', () {
      // The url only fills in for what the type does not say.
      expect(
        NotificationService.routeFor(const {
          'type': 'event_live_join',
          'event_id': '12',
          'what': 'quiz',
          'url': 'https://myotherapp.in/events/hack-night-04',
        }),
        '/events/12?live=quiz',
      );
      expect(
        NotificationService.routeFor(const {
          'type': 'event_reminder',
          'event_id': '12',
        }),
        '/events/12',
      );
      expect(
        NotificationService.routeFor(const {
          'type': 'club_thread',
          'thread_id': 'abc',
        }),
        '/threads/abc',
      );
    });

    test('nothing to open from a url that is not a link', () {
      for (final data in [
        const {'url': ''},
        const {'url': '   '},
        const {'url': '/events/12'},
        const {'url': 'javascript:alert(1)'},
        const {'url': 'myotherapp://events/12'},
      ]) {
        expect(NotificationService.routeFor(data), isNull, reason: '$data');
        expect(NotificationService.webUrlFor(data), isNull, reason: '$data');
      }
    });

    test('the same push is still opened once, by its push_id', () {
      final dedupe = PushDedupe();
      const data = {
        'push_id': 'p-1',
        'url': 'https://myotherapp.in/events/hack-night-04',
      };
      expect(dedupe.firstOpen(data), isTrue);
      expect(dedupe.firstOpen(data), isFalse);
    });
  });

  group('every route a push can open is one the router has', () {
    test('typed and url pushes alike', () {
      final container = ProviderContainer(overrides: [
        authStateProvider.overrideWith((ref) =>
            _FakeAuth(const AuthState(accessToken: 't', isInitialized: true))),
        routerObserversProvider.overrideWithValue(const []),
      ]);
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      for (final data in [
        const {'type': 'event_live_join', 'event_id': '12', 'what': 'poll'},
        const {'type': 'event_live_update', 'event_id': '12'},
        const {'type': 'event_started', 'event_id': '12'},
        const {'type': 'event_checkin', 'event_id': '12'},
        const {'type': 'club_thread', 'thread_id': 'abc'},
        const {'url': 'https://myotherapp.in/events/hack-night-04'},
        const {'url': 'https://myotherapp.in/tickets/abc-123'},
        const {'url': 'https://myotherapp.in/certificates/abc-123'},
        const {'url': 'https://myotherapp.in/threads/abc'},
        const {'url': 'https://myotherapp.in/events?when=today'},
        const {'url': 'https://myotherapp.in/feedback/12/34?k=abc'},
      ]) {
        final route = NotificationService.routeFor(data)!;
        expect(
            router.configuration.findMatch(Uri.parse(route)).isError, isFalse,
            reason: route);
      }
    });
  });

  group('Android shows pushes on the app\'s own channel and icon', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    String? metaData(String name) => RegExp(
          '<meta-data\\s+android:name="${RegExp.escape(name)}"\\s+'
          'android:(?:value|resource)="([^"]+)"',
        ).firstMatch(manifest)?.group(1);

    test('FCM\'s default channel is the one the app creates', () {
      expect(
        metaData(
            'com.google.firebase.messaging.default_notification_channel_id'),
        NotificationService.androidChannelId,
      );
    });

    test('FCM\'s default icon is the status-bar icon the app uses', () {
      expect(
        metaData('com.google.firebase.messaging.default_notification_icon'),
        NotificationService.androidSmallIcon,
      );
      final name = NotificationService.androidSmallIcon.split('/').last;
      for (final density in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        expect(
          File('android/app/src/main/res/drawable-$density/$name.png')
              .existsSync(),
          isTrue,
          reason: density,
        );
      }
    });

    test('the channel has a name people can read in Settings', () {
      expect(NotificationService.androidChannelName, isNot(contains('High')));
      expect(NotificationService.androidChannelName, isNotEmpty);
    });
  });
}

class _FakeAuth extends StateNotifier<AuthState> implements AuthStateNotifier {
  _FakeAuth(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not needed here');
}
