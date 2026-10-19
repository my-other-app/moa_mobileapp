import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'event_page_fixtures.dart';

void main() {
  group('EventPageDetails.fromJson', () {
    test('reads the whole page', () {
      final page = EventPageDetails.fromJson(discoverEventPage())!;

      expect(page.id, 7);
      expect(page.slug, 'hack-night');
      expect(page.phase, EventPhase.upcoming);
      expect(page.registrationOpen, isTrue);
      expect(page.capacity, 120);
      expect(page.going, 82);
      expect(page.seatsLeft, 38);
      expect(page.hasPoint, isTrue);
      expect(page.lat, 9.9312);
      expect(page.guidelines, 'Bring your laptop.\nNo outside food.');
      expect(page.contact.name, 'Asha');
      expect(page.contact.email, 'hello@tinkerhub.org');
      expect(page.contact.dialable, '+919876543210');
      expect(page.club!.followers, 1200);
      expect(page.club!.tagline, 'We build things');

      final speaker = page.speakers.single;
      expect(speaker.name, 'Ananya Iyer');
      expect(speaker.role, 'ML engineer, Sarvam');
      expect(speaker.bio, startsWith('Ananya builds'));
      expect(speaker.initials, 'AI');
      expect(speaker.links.single.kind, PersonLinkKind.linkedin);

      final lead = page.team.single;
      expect(page.teamSource, TeamSource.event);
      expect(lead.role, 'Lead');
      // A bare "x.com/rahul" is read as https; a javascript: link is not a
      // link at all.
      expect(lead.links.map((l) => l.label), ['Instagram', 'X']);
      expect(lead.links.last.uri.toString(), 'https://x.com/rahul');

      // The event itself is left out of its own rails.
      expect(page.moreFromClub.map((e) => e.id), [8]);
      final similar = page.similar.single;
      expect(similar.name, 'Rust Meetup');
      expect(similar.isOnline, isTrue);
      expect(similar.fee, 99);
      expect(similar.clubName, 'Rust Kerala');
      expect(similar.route, '/events/9');
    });

    test('tolerates every field missing but the id', () {
      final page = EventPageDetails.fromJson({
        'event': {'id': '7'},
      })!;

      expect(page.id, 7);
      expect(page.phase, isNull);
      expect(page.capacity, isNull);
      expect(page.seatsLeft, isNull);
      expect(page.hasPoint, isFalse);
      expect(page.contact.isEmpty, isTrue);
      expect(page.club, isNull);
      expect(page.speakers, isEmpty);
      expect(page.team, isEmpty);
      expect(page.teamSource, isNull);
      expect(page.moreFromClub, isEmpty);
      expect(page.similar, isEmpty);
    });

    test('is null for anything that is not a page', () {
      expect(EventPageDetails.fromJson(null), isNull);
      expect(EventPageDetails.fromJson('nope'), isNull);
      expect(EventPageDetails.fromJson({'event': {}}), isNull);
      expect(EventPageDetails.fromJson({'message': 'Not found'}), isNull);
    });

    test('a capacity of 0 is no limit; 0,0 is no point; bad rows are skipped',
        () {
      final page = EventPageDetails.fromJson(discoverEventPage(
        capacity: 0,
        lat: 0,
        lng: 0,
        speakers: [
          {'name': '  '},
          {'name': 'Ravi', 'photo': {'medium': 'https://cdn/r.jpg'}},
        ],
        team: [],
        more: [
          {'name': 'no id'},
          {'id': 'x'},
        ],
      ))!;

      expect(page.capacity, isNull);
      expect(page.seatsLeft, isNull);
      expect(page.hasPoint, isFalse);
      expect(page.speakers.map((s) => s.name), ['Ravi']);
      expect(page.speakers.single.photo, 'https://cdn/r.jpg');
      expect(page.speakers.single.hasMore, isFalse);
      expect(page.team, isEmpty);
      expect(page.teamSource, isNull);
      expect(page.moreFromClub, isEmpty);
    });

    test('seats left is never below nought, and falls back to capacity less '
        'those going', () {
      expect(
          EventPageDetails.fromJson(discoverEventPage(seatsLeft: -4))!
              .seatsLeft,
          0);
      expect(
          EventPageDetails.fromJson(
                  discoverEventPage(seatsLeft: null, capacity: 100, going: 30))!
              .seatsLeft,
          70);
    });

    test('a team with no source to name is not shown', () {
      final page =
          EventPageDetails.fromJson(discoverEventPage(teamSource: 'none'))!;
      expect(page.team, isEmpty);
      expect(page.teamSource, isNull);
    });
  });

  group('EventInfo, for the page', () {
    test('reads speakers, guidelines, contact and the point', () {
      final info = EventInfo.fromJson(eventInfo(extra: {
        'speakers': [
          {
            'id': 1,
            'name': 'Ananya Iyer',
            'designation': 'ML engineer',
            'photo': {'thumbnail': 'https://cdn/a-t.jpg', 'medium': 'https://cdn/a-m.jpg'},
            'bio': 'Speech models.',
            'link': 'linkedin.com/in/ananya',
            'display_order': 0,
          },
        ],
        'event_guidelines': '  Be kind.  ',
        'contact_name': 'Asha',
        'contact_email': 'hello@tinkerhub.org',
        'contact_phone': '9876543210',
        'lat': 9.93,
        'lng': '76.26',
        'max_participants': 120,
      }));

      expect(info.speakers.single.photo, 'https://cdn/a-m.jpg');
      expect(info.speakers.single.links.single.uri.toString(),
          'https://linkedin.com/in/ananya');
      expect(info.guidelines, 'Be kind.');
      expect(info.contact.name, 'Asha');
      expect(info.contact.email, 'hello@tinkerhub.org');
      expect(info.contact.dialable, '9876543210');
      expect(info.lat, 9.93);
      expect(info.lng, 76.26);
      expect(info.maxParticipants, 120);
      expect(info.feedbackUrl, isNull);
    });

    test('without them, nothing is made up', () {
      final info = EventInfo.fromJson({'id': 7});
      expect(info.speakers, isEmpty);
      expect(info.guidelines, isNull);
      expect(info.contact.isEmpty, isTrue);
      expect(info.lat, isNull);
      expect(info.maxParticipants, isNull);
    });

    test('a question that does not say is required, as on the server', () {
      final info = EventInfo.fromJson(eventInfo(questions: [
        {'key': 'college', 'label': 'College', 'field_type': 'text'},
        {
          'key': 'note',
          'label': 'Anything else',
          'field_type': 'textarea',
          'required': false,
        },
      ]));
      expect(info.additionalDetails.map((q) => q.requiredField),
          [true, false]);
    });
  });

  group('safeWebLink', () {
    test('takes web links, and bare hosts as https', () {
      expect(safeWebLink('https://a.org/x').toString(), 'https://a.org/x');
      expect(safeWebLink('a.org/x').toString(), 'https://a.org/x');
    });

    test('refuses anything else', () {
      for (final bad in [
        null,
        '',
        'javascript:alert(1)',
        'mailto:a@b.org',
        'just words',
        'localhost',
      ]) {
        expect(safeWebLink(bad), isNull, reason: '$bad');
      }
    });
  });
}
