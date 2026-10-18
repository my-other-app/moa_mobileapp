import 'package:finnet/core/services/push_dedupe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PushDedupe', () {
    test('a push sent twice (by topic and to the device) is shown once', () {
      final d = PushDedupe();
      const topicCopy = {
        'type': 'club_thread',
        'thread_id': 'abc',
        'push_id': 'club_thread:abc'
      };
      const deviceCopy = {
        'type': 'club_thread',
        'thread_id': 'abc',
        'push_id': 'club_thread:abc'
      };

      expect(d.firstShow(topicCopy), isTrue);
      expect(d.firstShow(deviceCopy), isFalse);
      expect(d.firstShow({'push_id': 'club_thread:other'}), isTrue);
    });

    test('and opened once, whatever was shown', () {
      final d = PushDedupe();
      const data = {
        'type': 'new_event',
        'event_id': '42',
        'push_id': 'new_event:42'
      };

      expect(d.firstShow(data), isTrue);
      expect(d.firstOpen(data), isTrue);
      expect(d.firstOpen(data), isFalse);
    });

    test(
        'a push without an id -- anything personal -- is always shown and opened',
        () {
      final d = PushDedupe();
      const ticket = {'type': 'check_in', 'event_id': '7'};

      expect(d.firstShow(ticket), isTrue);
      expect(d.firstShow(ticket), isTrue);
      expect(d.firstOpen(ticket), isTrue);
      expect(d.firstOpen(ticket), isTrue);
      expect(d.firstShow({'push_id': '  '}), isTrue);
      expect(d.firstShow(null), isTrue);
    });

    test('remembers the most recent ids only', () {
      final d = PushDedupe(capacity: 2);

      expect(d.firstShow({'push_id': 'a'}), isTrue);
      expect(d.firstShow({'push_id': 'b'}), isTrue);
      expect(d.firstShow({'push_id': 'c'}), isTrue); // a is forgotten
      expect(d.firstShow({'push_id': 'c'}), isFalse);
      expect(d.firstShow({'push_id': 'a'}), isTrue);
    });
  });
}
