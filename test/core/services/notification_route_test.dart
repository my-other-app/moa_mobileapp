import 'package:finnet/app/router/route_access.dart';
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

  group('a followed speaker is speaking (speaker_event)', () {
    test('the push and its inbox line open the event', () {
      expect(
        NotificationService.routeFor(const {
          'type': 'speaker_event',
          'event_id': '12',
          'slug': 'ananya-iyer',
        }),
        '/events/12',
      );
      final line = NotificationModel.fromJson({
        'id': 'n-1',
        'user_id': 1,
        'title': 'Ananya Iyer is speaking at Hack Night',
        'description': '',
        'type': 'speaker_event',
        'status': 'unread',
        'data': {'event_id': '12', 'slug': 'ananya-iyer'},
        'created_at': '2026-11-11T10:00:00Z',
      });
      expect(line.route, '/events/12');
      expect(line.iconEmoji, '🎤');
    });
  });

  group("a club's ask for missing details (answers_needed)", () {
    const url = 'https://myotherapp.in/answers/12/reg-1?k=abc.def';

    test('opens the details screen by its personal link, key and all', () {
      expect(
        NotificationService.routeFor(const {
          'type': 'answers_needed',
          'event_id': '12',
          'url': url,
        }),
        '/answers/12/reg-1?k=abc.def',
      );
      // A registration under review: its ref starts with q.
      expect(
        NotificationService.routeFor(const {
          'type': 'answers_needed',
          'event_id': '12',
          'url': 'https://myotherapp.in/answers/12/qabc?k=s',
        }),
        '/answers/12/qabc?k=s',
      );
    });

    test('without a link it opens the event; without either, nothing', () {
      expect(
        NotificationService.routeFor(
            const {'type': 'answers_needed', 'event_id': '12'}),
        '/events/12',
      );
      expect(
        NotificationService.routeFor(const {'type': 'answers_needed'}),
        isNull,
      );
    });

    test('its inbox line opens the same screen as the push', () {
      final line = NotificationModel.fromJson({
        'id': 'n-1',
        'user_id': 1,
        'title': 'Hack Night needs 2 more details',
        'description': 'We need 2 more details for your ticket.',
        'type': 'answers_needed',
        'status': 'unread',
        'event': {'id': 12, 'name': 'Hack Night'},
        'data': {'event_id': '12', 'url': url},
        'created_at': '2026-11-08T10:00:00Z',
      });
      expect(line.route, '/answers/12/reg-1?k=abc.def');
      expect(line.iconEmoji, '📝');
    });

    test('an app build without the screen still opens the link: the push '
        'is routed in the app, never to the browser', () {
      expect(
          NotificationService.webUrlFor(const {
            'type': 'answers_needed',
            'event_id': '12',
            'url': url,
          }),
          isNull);
    });
  });

  group('the support team replied (support_reply)', () {
    test('opens the request, by its case id', () {
      expect(
        NotificationService.routeFor(
            const {'type': 'support_reply', 'case_id': '77', 'number': '1042'}),
        '/profile/help/requests/77',
      );
      // A number, as JSON may carry it.
      expect(
        NotificationService.routeFor(
            const {'type': 'support_reply', 'case_id': 77}),
        '/profile/help/requests/77',
      );
    });

    test('never the event, even with one named; My requests without a case',
        () {
      expect(
        NotificationService.routeFor(const {
          'type': 'support_reply',
          'case_id': '77',
          'event_id': '12',
        }),
        '/profile/help/requests/77',
      );
      expect(NotificationService.routeFor(const {'type': 'support_reply'}),
          '/profile/help/requests');
    });

    test('signed out, it asks for sign-in first', () {
      expect(needsAccount('/profile/help/requests/77'), isTrue);
    });

    test('its inbox line opens the same request', () {
      final line = NotificationModel.fromJson({
        'id': 'n-1',
        'user_id': 1,
        'title': 'We replied to your request #1042',
        'description': 'Found it, check My events.',
        'type': 'support_reply',
        'status': 'unread',
        'data': {'case_id': '77', 'number': '1042'},
        'created_at': '2026-11-11T10:00:00Z',
      });
      expect(line.route, '/profile/help/requests/77');
      expect(line.iconEmoji, '🛟');
    });
  });

  group('an unknown push with a url', () {
    test('a page the app has opens in the app', () {
      expect(
        NotificationService.routeFor(const {
          'type': 'something_new',
          'url': 'https://myotherapp.in/answers/12/reg-1?k=abc',
        }),
        '/answers/12/reg-1?k=abc',
      );
    });

    test('a page it lacks falls back to the browser', () {
      const data = {
        'type': 'something_new',
        'url': 'https://myotherapp.in/some/page',
      };
      expect(NotificationService.routeFor(data), isNull);
      expect(NotificationService.webUrlFor(data),
          Uri.parse('https://myotherapp.in/some/page'));
    });
  });
}
