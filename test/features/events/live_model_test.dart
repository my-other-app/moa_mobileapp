import 'package:finnet/common/models/events/live_model.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LiveFeed', () {
    test('reads the room and knows whether it is worth a strip', () {
      final feed = LiveFeed.fromJson(<String, dynamic>{
        'event': {'id': 68, 'name': 'Hack Night 04', 'status': 'live'},
        'banner': {'kind': 'room', 'text': 'Demos move to Lab 3B'},
        'poll': {'id': 'p1', 'prompt': 'What are you building?'},
        'questions': [{}, {}],
        'quiz': {'live': true, 'title': 'Warm-up'},
      });
      expect(feed.eventId, 68);
      expect(feed.eventStatus, 'live');
      expect(feed.isEventLive, isTrue);
      expect(feed.isActive, isTrue);
      expect(feed.headline, 'Demos move to Lab 3B');
      expect(feed.quizLive, isTrue);
      expect(feed.questions, 2);
    });

    test('a quiet room earns nothing', () {
      final feed = LiveFeed.fromJson(<String, dynamic>{
        'event': {'id': 68},
        'banner': null,
        'poll': null,
        'questions': <dynamic>[],
        'quiz': {'live': false, 'title': null},
      });
      expect(feed.isActive, isFalse);
      expect(feed.isEventLive, isFalse, reason: 'no status: not live');
      expect(LiveFeed.empty.isActive, isFalse);
      expect(LiveFeed.empty.isEventLive, isFalse);
    });

    test('only status live is live', () {
      for (final status in ['published', 'closed', 'archived', 'draft']) {
        final feed = LiveFeed.fromJson(<String, dynamic>{
          'event': {'id': 68, 'status': status},
        });
        expect(feed.isEventLive, isFalse, reason: status);
      }
    });

    test('the headline falls back from the banner to the quiz to the poll', () {
      expect(const LiveFeed(eventId: 1, quizLive: true).headline, contains('quiz'));
      expect(const LiveFeed(eventId: 1, pollPrompt: 'Rate it').headline, 'Rate it');
      expect(const LiveFeed(eventId: 1, questions: 3).headline, contains('floor'));
    });

    test('reads the strip\'s banner view: a live event is worth a strip even '
        'with nothing up', () {
      final feed = LiveFeed.fromJson(<String, dynamic>{
        'event': {
          'id': 68,
          'name': 'Hack Night 04',
          'status': 'live',
          'starts_at': '2026-10-25T12:30:00Z',
          'ends_at': '2026-10-25T15:30:00Z',
        },
        'banner': null,
      });
      expect(feed.startsAt, DateTime.utc(2026, 10, 25, 12, 30));
      expect(feed.endsAt, DateTime.utc(2026, 10, 25, 15, 30));
      expect(feed.isActive, isTrue);
      expect(feed.headline, contains('live room is open'));
      expect(feed.isClosed, isFalse);
      expect(
          LiveFeed.fromJson(<String, dynamic>{
            'event': {'id': 68, 'status': 'closed'},
          }).isClosed,
          isTrue);
    });
  });

  group('a tapped notification', () {
    test('a live update opens the event\'s live room', () {
      expect(NotificationService.routeFor({'type': 'event_live_update', 'event_id': '68'}), '/events/68/live');
      expect(NotificationService.routeFor({'type': 'event_reminder', 'event_id': 7}), '/events/7');
    });

    test('anything else opens nothing', () {
      expect(NotificationService.routeFor({'type': 'new_event'}), isNull);
      expect(NotificationService.routeFor({'type': 'event_live_update', 'event_id': 'abc'}), isNull);
      expect(NotificationService.routeFor(<String, dynamic>{}), isNull);
    });
  });
}
