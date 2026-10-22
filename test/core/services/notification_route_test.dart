import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where a tapped push goes. `routeFor` is static and pure, so it is tested
/// without Firebase -- nothing here touches the singleton.
void main() {
  group('NotificationService.routeFor', () {
    test('a club_thread push opens the post', () {
      // The payload exactly as the backend sends it (threads/service.py).
      final route = NotificationService.routeFor(const {
        'type': 'club_thread',
        'thread_id': '7d0f3c2a-1111-4c4c-9a9a-000000000001',
        'club_id': '5',
      });

      expect(route, '/threads/7d0f3c2a-1111-4c4c-9a9a-000000000001');
    });

    test('a club_thread push without a thread id goes nowhere', () {
      expect(
        NotificationService.routeFor(const {'type': 'club_thread'}),
        isNull,
      );
      expect(
        NotificationService.routeFor(const {
          'type': 'club_thread',
          'thread_id': '  ',
        }),
        isNull,
      );
    });

    test('a club_thread push is not mistaken for an event one', () {
      // Even with an event id in the payload, a post opens the post.
      final route = NotificationService.routeFor(const {
        'type': 'club_thread',
        'thread_id': 'abc',
        'event_id': '12',
      });

      expect(route, '/threads/abc');
    });

    test('a thread id that is not path-safe is escaped', () {
      expect(
        NotificationService.routeFor(const {
          'type': 'club_thread',
          'thread_id': 'a/b',
        }),
        '/threads/a%2Fb',
      );
    });

    test('event pushes still open their event', () {
      expect(
        NotificationService.routeFor(const {
          'type': 'event_reminder',
          'event_id': '12',
        }),
        '/events/12',
      );
    });

    test('the check-in push opens People Like You when it says so', () {
      // As checkins/after.py sends it while the event's list is open.
      expect(
        NotificationService.routeFor(const {
          'type': 'event_checkin',
          'event_id': '12',
          'open': 'people',
        }),
        '/events/12/people',
      );
    });

    test('the plain check-in push opens the event', () {
      expect(
        NotificationService.routeFor(const {
          'type': 'event_checkin',
          'event_id': '12',
        }),
        '/events/12',
      );
    });

    test('an unknown type goes nowhere', () {
      expect(
        NotificationService.routeFor(const {'type': 'something_new'}),
        isNull,
      );
    });
  });

  group('club_thread in the notifications list', () {
    NotificationModel model({Map<String, dynamic>? data}) =>
        NotificationModel.fromJson({
          'id': 'n1',
          'user_id': 1,
          'title': 'Tinkerhub CET posted',
          'description': 'Which night works?',
          'type': 'club_thread',
          'status': 'unread',
          'from_club': {'id': 5, 'name': 'Tinkerhub CET'},
          'data': data,
          'created_at': '2026-10-16T08:00:00Z',
          'updated_at': '2026-10-16T08:00:00Z',
        });

    test('is a known type with its own icon', () {
      final n = model(data: {'type': 'club_thread', 'thread_id': 'abc'});

      expect(n.notificationType, NotificationType.clubThread);
      expect(n.iconEmoji, '💬');
    });

    test('carries the post to open', () {
      expect(model(data: {'thread_id': 'abc'}).threadId, 'abc');
    });

    test('without a thread id has nothing to open', () {
      expect(model().threadId, isNull);
      expect(model(data: {'thread_id': ''}).threadId, isNull);
    });
  });

  group('the check-in note in the notifications list', () {
    NotificationModel model(Map<String, dynamic>? data) =>
        NotificationModel.fromJson({
          'id': 'n2',
          'user_id': 1,
          'title': "✅ You're checked in",
          'description':
              'Welcome to Hack Night. See who here shares your interests.',
          'type': 'event_checkin',
          'status': 'unread',
          'event': {'id': 12, 'name': 'Hack Night'},
          'data': data,
          'created_at': '2026-10-16T08:00:00Z',
          'updated_at': '2026-10-16T08:00:00Z',
        });

    test('opens People Like You when it says so', () {
      expect(model({'event_name': 'Hack Night', 'open': 'people'}).opensPeople,
          isTrue);
    });

    test('the plain one opens the event, as before', () {
      expect(model({'event_name': 'Hack Night'}).opensPeople, isFalse);
      expect(model(null).opensPeople, isFalse);
    });
  });
}
