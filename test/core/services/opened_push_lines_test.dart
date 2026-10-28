import 'dart:convert';

import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/core/services/opened_push_lines.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tap on a push notes the inbox line it names (`notification_id`), for
/// the inbox to mark read once someone is signed in. None of this touches
/// Firebase: the launch holds are static.
void main() {
  setUp(() {
    OpenedPushLines.clear();
    NotificationService.pendingLaunch.clear();
  });
  tearDown(() {
    OpenedPushLines.clear();
    NotificationService.pendingLaunch.clear();
  });

  group('OpenedPushLines', () {
    test('notes the line a push names, once', () {
      var bumps = 0;
      void bump() => bumps++;
      OpenedPushLines.count.addListener(bump);
      addTearDown(() => OpenedPushLines.count.removeListener(bump));

      OpenedPushLines.opened({'type': 'club_thread', 'notification_id': 'n-1'});
      OpenedPushLines.opened({'notification_id': 'n-1'});
      OpenedPushLines.opened({'notification_id': ' key-2 '});

      expect(OpenedPushLines.waiting, ['n-1', 'key-2']);
      expect(bumps, 2);
    });

    test(
        'a push that names no line (an older server, no inbox line) adds '
        'nothing', () {
      OpenedPushLines.opened({'type': 'waitlist_offer', 'event_id': '4'});
      OpenedPushLines.opened({'notification_id': ''});

      expect(OpenedPushLines.waiting, isEmpty);
    });

    test('take hands them over once; clear forgets them', () {
      OpenedPushLines.opened({'notification_id': 'n-1'});
      expect(OpenedPushLines.take(), ['n-1']);
      expect(OpenedPushLines.take(), isEmpty);

      OpenedPushLines.opened({'notification_id': 'n-2'});
      OpenedPushLines.clear();
      expect(OpenedPushLines.take(), isEmpty);
    });
  });

  group('a cold start from a tap', () {
    test('a push that launched the app: its screen is held, its line noted',
        () {
      NotificationService.holdLaunchMessage({
        'type': 'volunteer_assigned',
        'event_id': '7',
        'notification_id': 'line-launch',
      });

      expect(NotificationService.pendingLaunch.take(), isNotNull);
      expect(OpenedPushLines.waiting, ['line-launch']);
    });

    test('a re-shown push (a local notification) that launched it: the same',
        () {
      NotificationService.holdLaunchPayload(jsonEncode({
        'type': 'club_thread',
        'thread_id': 'abc',
        'notification_id': 'line-local',
      }));

      expect(NotificationService.pendingLaunch.take(), '/threads/abc');
      expect(OpenedPushLines.waiting, ['line-local']);
    });

    test('a push with no line still opens its screen', () {
      NotificationService.holdLaunchMessage(
          {'type': 'volunteer_assigned', 'event_id': '8'});

      expect(NotificationService.pendingLaunch.take(), isNotNull);
      expect(OpenedPushLines.waiting, isEmpty);
    });

    test('a second copy of a push already opened notes nothing again', () {
      const push = {
        'type': 'new_event',
        'event_id': '12',
        'push_id': 'new_event:cold-12',
        'notification_id': 'key-new-event',
      };
      NotificationService.holdLaunchMessage(push);
      OpenedPushLines.take();
      NotificationService.pendingLaunch.clear();

      NotificationService.holdLaunchMessage(push);

      expect(OpenedPushLines.waiting, isEmpty);
      expect(NotificationService.pendingLaunch.take(), isNull);
    });
  });
}
