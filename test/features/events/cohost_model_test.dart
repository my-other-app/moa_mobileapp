import 'package:finnet/common/models/events/cohost_model.dart';
import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/services/notification_routes.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:finnet/features/clubs/presentation/pages/club_events_page.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/notifications/data/models/notification_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../discover/discover_fixtures.dart';
import 'event_page_fixtures.dart';

// Co-hosted events (feature-register cohosts-contract.md): the host stays
// the event's `club`; the clubs that accepted come as `cohosts`, each
// `{club_id, name, slug, logo}` -- the logo the S3 sizes under `/events/*`
// and `/clubs/*`, one URL under `/discover/*`. A server older than the
// feature sends no `cohosts`, and every screen is as it was.

const _sizes = {
  'thumbnail': 'https://media.example/robotics.thumb.png',
  'medium': 'https://media.example/robotics.medium.png',
  'large': 'https://media.example/robotics.large.png',
  'original': 'https://media.example/robotics.png',
};

const _robotics = {
  'club_id': 9,
  'name': 'Robotics Club',
  'slug': 'robotics-club',
  'logo': _sizes,
};

const _drama = {
  'club_id': 11,
  'name': 'Drama Society',
  'slug': 'drama-society',
  'logo': null,
};

const _quiz = {
  'club_id': 12,
  'name': 'Quiz Club',
  'slug': 'quiz-club',
  'logo': 'https://media.example/quiz.png',
};

void main() {
  group('a co-host (CohostRef)', () {
    test('reads its club, name, slug and the smallest logo', () {
      final cohost = EventCohost.fromJson(_robotics)!;
      expect(cohost.clubId, 9);
      expect(cohost.name, 'Robotics Club');
      expect(cohost.slug, 'robotics-club');
      expect(cohost.logo, 'https://media.example/robotics.thumb.png');
      expect(cohost.initials, 'RC');
    });

    test('a logo as one URL (under /discover), or none', () {
      expect(EventCohost.fromJson(_quiz)!.logo, 'https://media.example/quiz.png');
      expect(EventCohost.fromJson(_drama)!.logo, isNull);
      expect(EventCohost.fromJson({..._drama, 'logo': '  '})!.logo, isNull);
    });

    test('an id as `id` or a string is read; none is 0', () {
      expect(EventCohost.fromJson({'id': 4, 'name': 'A'})!.clubId, 4);
      expect(EventCohost.fromJson({'club_id': '7', 'name': 'A'})!.clubId, 7);
      expect(EventCohost.fromJson({'name': 'A'})!.clubId, 0);
      expect(EventCohost.fromJson({'club_id': -2, 'name': 'A'})!.clubId, 0);
    });

    test('a row without a name is no co-host', () {
      expect(EventCohost.fromJson({'club_id': 9}), isNull);
      expect(EventCohost.fromJson({'club_id': 9, 'name': '   '}), isNull);
    });

    test('a list keeps its order, skips nonsense, and names each club once',
        () {
      final cohosts = EventCohost.listFrom([
        _robotics,
        'nonsense',
        {'club_id': 10},
        _drama,
        _robotics,
        // The host is never its own co-host.
        {'club_id': 3, 'name': 'Tinkerhub'},
        _quiz,
      ], hostId: 3);
      expect(cohosts.map((c) => c.name),
          ['Robotics Club', 'Drama Society', 'Quiz Club']);
    });

    test('none from an older server: absent, null or not a list', () {
      expect(EventCohost.listFrom(null), isEmpty);
      expect(EventCohost.listFrom('Robotics Club'), isEmpty);
      expect(EventCohost.listFrom({'club_id': 9, 'name': 'Robotics'}), isEmpty);
      expect(EventCohost.listFrom(const []), isEmpty);
    });
  });

  group('the wording', () {
    test('"Hosted by A and B", "Hosted by A, B and C"', () {
      expect(hostedByText('Design Society', ['Robotics Club']),
          'Hosted by Design Society and Robotics Club');
      expect(hostedByText('Design Society', ['Robotics Club', 'Quiz Club']),
          'Hosted by Design Society, Robotics Club and Quiz Club');
      expect(hostedByText('Design Society', const []),
          'Hosted by Design Society');
    });

    test('a card\'s line: "A", "A and B", "A + 2"', () {
      expect(hostNamesCompact('Design Society', const []), 'Design Society');
      expect(hostNamesCompact('Design Society', ['Robotics Club']),
          'Design Society and Robotics Club');
      expect(hostNamesCompact('Design Society', ['Robotics Club', 'Quiz Club']),
          'Design Society + 2');
      expect(
          hostNamesCompact(
              'Design Society', ['Robotics Club', 'Quiz Club', 'Drama']),
          'Design Society + 3');
    });

    test('names joined as a sentence, blanks left out', () {
      expect(joinClubNames(const []), '');
      expect(joinClubNames(['A']), 'A');
      expect(joinClubNames(['A', ' ', 'B']), 'A and B');
      expect(joinClubNames(['A', 'B', 'C', 'D']), 'A, B, C and D');
    });
  });

  group('the event (GET /events/info)', () {
    test('reads its co-hosts beside its club, the host', () {
      final info = EventInfo.fromJson(eventInfo(extra: {
        'cohosts': [_robotics, _drama],
        'viewer_role': null,
      }));
      expect(info.club.id, 3);
      expect(info.club.name, 'Tinkerhub');
      expect(info.cohosts.map((c) => c.clubId), [9, 11]);
      expect(info.cohosts.first.logo, 'https://media.example/robotics.thumb.png');
    });

    test('has none from an older server, or when nobody co-hosts', () {
      expect(EventInfo.fromJson(eventInfo()).cohosts, isEmpty);
      expect(EventInfo.fromJson(eventInfo(extra: {'cohosts': null})).cohosts,
          isEmpty);
      expect(EventInfo.fromJson(eventInfo(extra: {'cohosts': []})).cohosts,
          isEmpty);
    });
  });

  group("the website's event page (GET /discover/events)", () {
    test('reads the co-hosts beside its club (logos as URLs)', () {
      final page = EventPageDetails.fromJson({
        ...discoverEventPage(),
        'cohosts': [
          {..._robotics, 'logo': 'https://media.example/robotics.medium.png'},
        ],
      })!;
      expect(page.club!.name, 'Tinkerhub');
      expect(page.cohosts.single.name, 'Robotics Club');
      expect(page.cohosts.single.logo, 'https://media.example/robotics.medium.png');
    });

    test('or on the event, should they come there', () {
      final json = discoverEventPage();
      (json['event'] as Map<String, dynamic>)['cohosts'] = [_drama];
      expect(EventPageDetails.fromJson(json)!.cohosts.single.clubId, 11);
    });

    test('has none from an older server', () {
      expect(EventPageDetails.fromJson(discoverEventPage())!.cohosts, isEmpty);
    });
  });

  group('the discover cards', () {
    test('an EventCard reads its co-hosts (logos as URLs)', () {
      final e = parseEvent({
        ...eventCard(7),
        'cohosts': [_quiz, _robotics],
      })!;
      expect(e.club!.name, 'Tinkerhub');
      expect(e.cohosts.map((c) => c.id), [12, 9]);
      expect(e.cohosts.first.logo, 'https://media.example/quiz.png');
    });

    test('the Following rail (/events/list rows) reads them too', () {
      final e = parseListEvent({
        'id': 4,
        'name': 'Hack Night',
        'event_datetime': '2030-10-24T12:30:00Z',
        'club': {'id': 3, 'name': 'Tinkerhub'},
        'cohosts': [_robotics, {'club_id': 3, 'name': 'Tinkerhub'}],
      })!;
      expect(e.cohosts.single.name, 'Robotics Club');
      expect(e.cohosts.single.slug, 'robotics-club');
    });

    test('none from an older server', () {
      expect(parseEvent(eventCard(7))!.cohosts, isEmpty);
      expect(parseEvent({...eventCard(7), 'cohosts': 'x'})!.cohosts, isEmpty);
      expect(parseListEvent({'id': 4})!.cohosts, isEmpty);
    });
  });

  group("a list's event card (/events/list, /events/for-you)", () {
    Map<String, dynamic> row({List<Object?>? cohosts}) => {
          'id': 42,
          'name': 'Hack the Campus',
          'club': {
            'id': 1,
            'name': 'Design Society',
            'slug': 'design-society',
            'logo': {'thumbnail': 'https://media.example/design.png'},
          },
          if (cohosts != null) 'cohosts': cohosts,
        };

    test('names the host and its co-host: "A and B"', () {
      final card = eventCardFromJson(row(cohosts: [_robotics]));
      expect(card.organizer, 'Design Society');
      expect(card.cohosts, ['Robotics Club']);
      // The host's page and logo, as always.
      expect(card.clubId, 1);
      expect(card.orgImage, 'https://media.example/design.png');
    });

    test('with more, the card keeps them all for "A + 2"', () {
      final card = eventCardFromJson(row(cohosts: [_robotics, _quiz]));
      expect(card.cohosts, ['Robotics Club', 'Quiz Club']);
    });

    test('an older server: the host alone, as before', () {
      expect(eventCardFromJson(row()).cohosts, isEmpty);
      expect(eventCohostNames(row(cohosts: null)), isEmpty);
    });
  });

  group("a co-hosted event on the co-host's own page (/clubs/9/events)", () {
    Map<String, dynamic> onRobotics(Map<String, dynamic> event) =>
        clubEventWithClub(event,
            clubId: 9,
            clubName: 'Robotics Club',
            clubLogo: 'https://media.example/robotics.png');

    test("is the host's event: its name and logo, then this club", () {
      final card = eventCardFromJson(onRobotics({
        'id': 42,
        'name': 'Hack the Campus',
        'club': {
          'id': 1,
          'name': 'Design Society',
          'slug': 'design-society',
          'logo': {'thumbnail': 'https://media.example/design.png'},
        },
        'cohosts': [_robotics],
      }));
      expect(card.clubId, 1);
      expect(card.organizer, 'Design Society');
      expect(card.orgImage, 'https://media.example/design.png');
      expect(card.cohosts, ['Robotics Club']);
    });

    test("a host without a logo never borrows this club's", () {
      final card = eventCardFromJson(onRobotics({
        'id': 42,
        'club': {'id': 1, 'name': 'Design Society', 'logo': null},
        'cohosts': [_robotics],
      }));
      expect(card.organizer, 'Design Society');
      expect(card.orgImage, isEmpty);
    });

    test("this club's own events are filled in as before", () {
      final card = eventCardFromJson(onRobotics({
        'id': 43,
        'club': {'id': 9, 'name': 'Robotics Club', 'logo': null},
      }));
      expect(card.organizer, 'Robotics Club');
      expect(card.orgImage, 'https://media.example/robotics.png');
      expect(card.cohosts, isEmpty);
    });

    test("signed out, the club's public list keeps the co-hosts", () {
      final item = discoverEventAsListItem({
        'id': 42,
        'name': 'Hack the Campus',
        'starts_at': '2030-11-01T10:00:00+05:30',
        'club': {'id': 1, 'name': 'Design Society', 'logo': null},
        'cohosts': [
          {..._robotics, 'logo': 'https://media.example/robotics.png'},
        ],
      });
      final card = eventCardFromJson(onRobotics(item));
      expect(card.organizer, 'Design Society');
      expect(card.cohosts, ['Robotics Club']);
      expect(discoverEventAsListItem({'id': 1}).containsKey('cohosts'),
          isFalse);
    });
  });

  group("a co-host's new_event push opens the event as today", () {
    // The same push the host's followers get, with `club_id` the co-host's
    // (cohosts-contract.md §9).
    const push = {
      'type': 'new_event',
      'event_id': '42',
      'club_id': '9',
      'push_id': 'new_event:42',
    };

    test('tapped', () {
      expect(NotificationService.routeFor(push), '/events/42');
      expect(notificationRoute('new_event', eventId: 42, data: push),
          '/events/42');
    });

    test('its line in the inbox, from the co-host', () {
      final line = NotificationModel.fromJson({
        'id': 'n-9',
        'user_id': 1,
        'title': 'New from Robotics Club: Hack the Campus',
        'description': '',
        'type': 'new_event',
        'status': 'unread',
        'event': {'id': 42, 'name': 'Hack the Campus'},
        'from_club': {'id': 9, 'name': 'Robotics Club'},
        'data': push,
        'created_at': '2026-10-29T08:00:00Z',
      });
      expect(line.route, '/events/42');
      expect(line.route, NotificationService.routeFor(push));
    });
  });
}
