import 'dart:convert';

import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/core/services/pending_notification_route.dart';
import 'package:flutter_test/flutter_test.dart';

/// The route a launch tap asks for, held until the splash screen opens it.
/// Built on the real `NotificationService.routeFor`, which is static and pure.
void main() {
  late PendingNotificationRoute pending;

  setUp(() => pending = PendingNotificationRoute(NotificationService.routeFor));

  const threadPush = {'type': 'club_thread', 'thread_id': 'abc', 'club_id': '5'};
  const eventPush = {'type': 'event_reminder', 'event_id': '12'};

  test('a launch tap is held and handed over exactly once', () {
    pending.hold(threadPush);

    expect(pending.take(), '/threads/abc');
    // Cleared as it was taken: a second start-up must not open it again.
    expect(pending.take(), isNull);
  });

  test('nothing held means nothing to open', () {
    expect(pending.take(), isNull);
  });

  test('data that routes nowhere is ignored', () {
    pending.hold(const {'type': 'something_new'});
    pending.hold(const {'type': 'club_thread'}); // no thread id
    pending.hold(null);

    expect(pending.take(), isNull);
  });

  test('ignored data does not wipe a route already held', () {
    pending.hold(threadPush);
    pending.hold(const {'type': 'something_new'});

    expect(pending.take(), '/threads/abc');
  });

  test('it is set once: a second launch report does not replace the first',
      () {
    pending.hold(threadPush);
    pending.hold(eventPush);

    expect(pending.take(), '/threads/abc');
    expect(pending.take(), isNull);
  });

  test('after it is taken, a new tap can be held again', () {
    pending.hold(threadPush);
    pending.take();
    pending.hold(eventPush);

    expect(pending.take(), '/events/12');
  });

  test('clear drops it unopened', () {
    pending.hold(eventPush);
    pending.clear();

    expect(pending.take(), isNull);
  });

  group('a local notification payload', () {
    test('is the push data as JSON, and routes the same way', () {
      pending.holdPayload(jsonEncode(threadPush));

      expect(pending.take(), '/threads/abc');
    });

    test('that is not ours is ignored', () {
      pending.holdPayload('not json');
      pending.holdPayload('[1, 2]');
      pending.holdPayload('');
      pending.holdPayload(null);

      expect(pending.take(), isNull);
    });
  });

  test('the service holds one, readable without Firebase', () {
    // Touching it must not construct the singleton, whose fields reach for
    // FirebaseMessaging.instance.
    NotificationService.pendingLaunch.clear();
    expect(NotificationService.pendingLaunch.take(), isNull);
  });
}
