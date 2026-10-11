import 'package:flutter_test/flutter_test.dart';
import 'package:finnet/common/models/events/agenda_model.dart';

void main() {
  group('Agenda', () {
    test('parses the run of show, blanks to null, and groups by day', () {
      final agenda = Agenda.fromJson({
        'timezone': 'Asia/Kolkata',
        'has_programme': false,
        'items': [
          {
            'id': 'a',
            'starts_at': '2026-11-20T03:30:00+00:00',
            'ends_at': '2026-11-20T04:00:00+00:00',
            'title': 'Registration',
            'description': null,
            'speaker': '',
            'speaker_photo_url': null,
            'location': 'Foyer',
            'parallel': false,
          },
          {
            'id': 'b',
            'starts_at': '2026-11-21T04:00:00+00:00',
            'ends_at': null,
            'title': 'Day two',
            'speaker': 'Ananya Iyer',
            'location': 'Main hall',
            'parallel': true,
          },
        ],
      });
      expect(agenda.timezone, 'Asia/Kolkata');
      expect(agenda.items, hasLength(2));
      expect(agenda.items.first.speaker, isNull);
      expect(agenda.items.first.detail, 'Foyer');
      expect(agenda.items.first.endsAt, isNotNull);
      expect(agenda.items.last.endsAt, isNull);
      expect(agenda.items.last.parallel, isTrue);
      expect(agenda.items.last.detail, 'Ananya Iyer · Main hall');
      expect(agenda.byDay.keys, hasLength(2));
    });

    test('an empty or odd payload is an empty agenda, not a crash', () {
      expect(Agenda.fromJson({}).items, isEmpty);
      expect(
          Agenda.fromJson({
            'items': [1, 'x']
          }).items,
          isEmpty);
    });
  });
}
