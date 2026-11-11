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

    test("a session's linked speakers: their pages, and no repeat of names",
        () {
      final agenda = Agenda.fromJson({
        'items': [
          {
            'id': 'a',
            'starts_at': '2026-11-20T04:00:00+00:00',
            'title': 'Keynote',
            // The server's fill-in for older apps: the speakers' names.
            'speaker': 'Ananya Iyer, Ravi K',
            'location': 'Main hall',
            'event_speaker_ids': [11, 12],
            'speakers': [
              {
                'event_speaker_id': 11,
                'name': 'Ananya Iyer',
                'photo_thumbnail': 'https://media.myotherapp.in/a.jpg',
                'profile_slug': 'ananya-iyer',
              },
              // A hidden profile: named, with no page.
              {'event_speaker_id': 12, 'name': 'Ravi K', 'profile_slug': null},
              {'event_speaker_id': 13, 'name': '  '},
              {'event_speaker_id': 14, 'name': 'Odd', 'profile_slug': 'a/b'},
            ],
          },
          {
            'id': 'b',
            'starts_at': '2026-11-20T05:00:00+00:00',
            'title': 'Panel',
            'speaker': 'Moderated by the club',
            'speakers': [
              {'event_speaker_id': 11, 'name': 'Ananya Iyer'},
            ],
          },
        ],
      });
      final keynote = agenda.items.first;
      expect(keynote.speakers.map((s) => s.name),
          ['Ananya Iyer', 'Ravi K', 'Odd']);
      expect(keynote.speakers.first.profileSlug, 'ananya-iyer');
      expect(keynote.speakers.first.photo, 'https://media.myotherapp.in/a.jpg');
      expect(keynote.speakers.first.eventSpeakerId, 11);
      expect(keynote.speakers[1].profileSlug, isNull);
      expect(keynote.speakers.last.profileSlug, isNull);
      // The names are shown by the speakers, not again as text.
      expect(keynote.speakerText, isNull);
      expect(keynote.detail, 'Main hall');
      // Text of the club's own that names none of them stays.
      expect(agenda.items.last.speakerText, 'Moderated by the club');
      expect(agenda.items.last.detail, 'Moderated by the club');
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
