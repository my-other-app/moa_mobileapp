import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2030, 11, 1, 12);
  final later = DateTime(2030, 12, 1, 10);

  group('registerStateFor', () {
    test('open, with the seats said when few are left', () {
      final open = registerStateFor(
          now: now, phase: EventPhase.upcoming, registrationOpen: true);
      expect(open.kind, RegisterKind.open);
      expect(open.label, 'REGISTER NOW');
      expect(open.canRegister, isTrue);
      expect(open.note, isNull);

      final few = registerStateFor(
          now: now,
          phase: EventPhase.upcoming,
          registrationOpen: true,
          capacity: 50,
          seatsLeft: 3);
      expect(few.note, 'Only 3 seats left');
      expect(few.urgent, isTrue);
    });

    test('full: no waitlist on the server, so the button is off', () {
      final full = registerStateFor(
          now: now,
          phase: EventPhase.full,
          registrationOpen: false,
          capacity: 120,
          seatsLeft: 0);
      expect(full.kind, RegisterKind.full);
      expect(full.label, 'EVENT FULL');
      expect(full.note, 'All 120 seats are taken.');
      expect(full.canRegister, isFalse);

      // Open by the dates, but no seat left.
      final none = registerStateFor(
          now: now, registrationOpen: true, capacity: 10, seatsLeft: 0);
      expect(none.kind, RegisterKind.full);
    });

    test('not yet open says when it opens', () {
      final soon = registerStateFor(
        now: now,
        regOpensAt: DateTime(2030, 11, 18, 9),
        startsAt: later,
      );
      expect(soon.kind, RegisterKind.soon);
      expect(soon.label, 'REGISTRATION OPENS 18 NOV');
      expect(soon.canRegister, isFalse);
    });

    test('closed, ended, and live', () {
      expect(
        registerStateFor(
                now: now,
                regClosesAt: DateTime(2030, 10, 1),
                startsAt: later)
            .kind,
        RegisterKind.closed,
      );
      expect(
        registerStateFor(
                now: now,
                startsAt: DateTime(2030, 10, 1),
                endsAt: DateTime(2030, 10, 2))
            .label,
        'EVENT ENDED',
      );
      final live = registerStateFor(
          now: now, phase: EventPhase.live, registrationOpen: false);
      expect(live.label, 'OPEN THE LIVE ROOM');
      expect(live.canRegister, isFalse);
      final liveOpen = registerStateFor(
          now: now, phase: EventPhase.live, registrationOpen: true);
      expect(liveOpen.label, 'REGISTER NOW');
      expect(liveOpen.canRegister, isTrue);
    });

    test('without the website API, the dates decide', () {
      // No deadline, opened long ago, still to come: open.
      final open = registerStateFor(
          now: now, regOpensAt: DateTime(2020), startsAt: later);
      expect(open.kind, RegisterKind.open);
    });
  });

  test('seatsLine and seatsTaken', () {
    expect(seatsLine(going: 82, seatsLeft: 38), '82 going · 38 seats left');
    expect(seatsLine(going: 0, seatsLeft: 1), '1 seat left');
    expect(seatsLine(going: 0, seatsLeft: 0), 'Be the first to register');
    expect(seatsLine(going: 0), isNull);
    expect(seatsTaken(capacity: 100, seatsLeft: 25), 0.75);
    expect(seatsTaken(seatsLeft: 3), isNull);
  });

  group('addresses', () {
    test('the canonical address is the slug, else the API url, else the id',
        () {
      expect(eventCanonicalUrl(id: 7, slug: 'hack-night'),
          'https://myotherapp.in/events/hack-night');
      expect(
          eventCanonicalUrl(
              id: 7, apiUrl: 'https://myotherapp.in/events/7-hack'),
          'https://myotherapp.in/events/7-hack');
      expect(eventCanonicalUrl(id: 7), 'https://myotherapp.in/events/7');
    });

    test('the live room is under the event', () {
      expect(eventLiveRoomUri(id: 7, slug: 'hack-night').toString(),
          'https://myotherapp.in/events/hack-night/live');
      expect(eventLiveRoomUri(id: 7).toString(),
          'https://myotherapp.in/events/7/live');
    });

    test('a ref is an id only when it is all digits', () {
      expect(eventIdOf('42'), 42);
      expect(eventIdOf('hack-night'), isNull);
      expect(eventIdOf('2026-hack'), isNull);
    });
  });

  group('directionsUri', () {
    test('an iPhone gets Apple Maps', () {
      expect(
        directionsUri(ios: true, lat: 9.93, lng: 76.26, name: 'CET').toString(),
        'https://maps.apple.com/?daddr=9.93%2C76.26&q=CET',
      );
      expect(directionsUri(ios: true, name: 'CET Trivandrum').toString(),
          'https://maps.apple.com/?daddr=CET+Trivandrum');
    });

    test('Android gets Google Maps: the point, the map link, or the name', () {
      expect(
        directionsUri(ios: false, lat: 9.93, lng: 76.26).toString(),
        'https://www.google.com/maps/dir/?api=1&destination=9.93%2C76.26',
      );
      expect(
        directionsUri(
                ios: false, name: 'CET', link: 'https://maps.app.goo.gl/abc')
            .toString(),
        'https://maps.app.goo.gl/abc',
      );
      expect(directionsUri(ios: false, name: 'CET').toString(),
          'https://www.google.com/maps/search/?api=1&query=CET');
      expect(directionsUri(ios: false), isNull);
    });
  });

  group('calendar', () {
    test('an entry has an end, a place and the address', () {
      final entry = calendarEntryFor(
        name: 'Hack Night',
        startsAt: DateTime.utc(2030, 12, 1, 10),
        durationHours: 2.5,
        locationName: 'CET',
        about: 'Build   things.\n\nTogether.',
        url: 'https://myotherapp.in/events/hack-night',
      )!;
      expect(entry.end, DateTime.utc(2030, 12, 1, 12, 30));
      expect(entry.location, 'CET');
      expect(entry.description,
          'Build things. Together.\n\nhttps://myotherapp.in/events/hack-night');
    });

    test('online is "Online"; no length is two hours; no start, no entry',
        () {
      final entry = calendarEntryFor(
        name: '',
        startsAt: DateTime.utc(2030, 12, 1, 10),
        endsAt: DateTime.utc(2030, 12, 1, 9),
        isOnline: true,
        locationName: 'Zoom',
      )!;
      expect(entry.title, 'Event');
      expect(entry.end, DateTime.utc(2030, 12, 1, 12));
      expect(entry.location, 'Online');
      expect(calendarEntryFor(name: 'x'), isNull);
    });

    test('Google Calendar takes the times in UTC', () {
      final uri = googleCalendarUri(CalendarEntry(
        title: 'Hack Night',
        start: DateTime.utc(2030, 12, 1, 10),
        end: DateTime.utc(2030, 12, 1, 12, 30),
        location: 'CET',
      ));
      expect(uri.host, 'calendar.google.com');
      expect(uri.queryParameters['dates'], '20301201T100000Z/20301201T123000Z');
      expect(uri.queryParameters['text'], 'Hack Night');
      expect(uri.queryParameters['location'], 'CET');
    });

    test('summarise cuts at a word', () {
      expect(summarise('one two three four five', 16), 'one two three…');
      expect(summarise('short', 12), 'short');
    });
  });
}
