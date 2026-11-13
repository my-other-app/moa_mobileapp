import 'dart:convert';

import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/app/router/web_links.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/home_widget/domain/next_up.dart';
import 'package:flutter_test/flutter_test.dart';

/// 13 Nov 2026, 10:00 in India (04:30 UTC).
final _now = DateTime.utc(2026, 11, 13, 4, 30);

/// [hours] after [_now].
DateTime _in(double hours) =>
    _now.add(Duration(minutes: (hours * 60).round()));

SavedTicket _ticket(
  int eventId, {
  DateTime? startsAt,
  double? hours = 3,
  String name = 'Hack Night',
  String? venue = 'Maker Space, Kochi',
  bool online = false,
  bool revoked = false,
  EventCancellation? cancellation,
  String code = 'MOA-7K3QF-X9PWM',
}) =>
    SavedTicket(
      code: code,
      eventId: eventId,
      eventName: name,
      // The phone keeps them in its own time zone; the widget must not care.
      startsAt: startsAt?.toLocal(),
      durationHours: hours,
      venue: venue,
      isOnline: online,
      ticketUrl: 'https://myotherapp.in/tickets/$code',
      clubName: 'Kochi Coders',
      revoked: revoked,
      cancellation: cancellation,
    );

RegistrationRequest _request(
  int eventId, {
  DateTime? startsAt,
  RequestStatus status = RequestStatus.pending,
  RequestPay? pay,
  String slug = '',
}) =>
    RegistrationRequest(
      id: 'req-$eventId',
      status: status,
      token: 'secret-request-token-$eventId',
      event: RequestEvent(
        id: eventId,
        slug: slug,
        name: 'Design Jam',
        eventDateTime: startsAt?.toLocal(),
        clubName: 'Pixel Club',
      ),
      pay: pay,
    );

NextUpSnapshot _nextUp({
  bool signedIn = true,
  List<SavedTicket> tickets = const [],
  List<RegistrationRequest> requests = const [],
  DateTime? now,
}) =>
    nextUpFrom(
      signedIn: signedIn,
      tickets: tickets,
      requests: requests,
      now: now ?? _now,
    );

void main() {
  group('India time', () {
    test('a time of day is read on India\'s clock, whatever the phone\'s', () {
      // 04:00 UTC is 9:30 am in India.
      expect(indiaTimeOfDay(DateTime.utc(2026, 11, 14, 4)), '9:30 am');
      expect(indiaTimeOfDay(DateTime.utc(2026, 11, 14, 4).toLocal()),
          '9:30 am');
      expect(indiaTimeOfDay(DateTime.utc(2026, 11, 14, 12, 45)), '6:15 pm');
      expect(indiaTimeOfDay(DateTime.utc(2026, 11, 13, 18, 30)), '12:00 am');
    });

    test('days are India\'s calendar days, not 24-hour spans', () {
      final lateEvening = DateTime.utc(2026, 11, 13, 18); // 11:30 pm
      final justAfterMidnight = DateTime.utc(2026, 11, 13, 19); // 12:30 am
      expect(indiaDaysBetween(lateEvening, justAfterMidnight), 1);
      // 23 hours apart, the same day in India.
      expect(
          indiaDaysBetween(
              DateTime.utc(2026, 11, 12, 18, 31), DateTime.utc(2026, 11, 13, 17)),
          0);
      expect(indiaDaysBetween(_now, _now.add(const Duration(days: 3))), 3);
    });
  });

  group('the line under the name (nextUpWhen)', () {
    test('later today, tomorrow, in a few days', () {
      final today = DateTime.utc(2026, 11, 13, 12, 30); // 6:00 pm
      final tomorrow = DateTime.utc(2026, 11, 14, 4); // 9:30 am
      final later = DateTime.utc(2026, 11, 16, 4);
      expect(nextUpWhen(today, null, _now), 'Today · 6:00 pm');
      expect(nextUpWhen(tomorrow, null, _now), 'Tomorrow · 9:30 am');
      expect(nextUpWhen(later, null, _now), 'In 3 days');
    });

    test('just before midnight in India, an event after it is tomorrow', () {
      final now = DateTime.utc(2026, 11, 13, 18); // 11:30 pm
      final start = DateTime.utc(2026, 11, 13, 19); // 12:30 am
      expect(nextUpWhen(start, null, now), 'Tomorrow · 12:30 am');
    });

    test('started and not over: happening now', () {
      expect(nextUpWhen(_in(-1), _in(2), _now), 'Happening now');
      expect(nextUpWhen(_now, _in(2), _now), 'Happening now');
    });

    test('no date yet', () {
      expect(nextUpWhen(null, null, _now), 'Date to be announced');
    });
  });

  group('what is next (nextUpFrom)', () {
    test('signed out: sign in, then My events', () {
      final next =
          _nextUp(signedIn: false, tickets: [_ticket(1, startsAt: _in(5))]);
      expect(next.state, NextUpState.signedOut);
      expect(next.items, isEmpty);
      final json = next.toJson(_now);
      expect(json['state'], 'signed_out');
      expect(json['items'], isEmpty);
      // The website's /me/tickets: My events, which asks for sign-in first.
      final location = appLocationForLink(Uri.parse(json['link'] as String));
      expect(location, '/events');
      expect(needsAccount(location!), isTrue);
    });

    test('nothing coming up: Find events', () {
      final next = _nextUp();
      expect(next.state, NextUpState.nothing);
      expect(next.toJson(_now)['state'], 'nothing');
      expect(appLocationForLink(Uri.parse(next.link)), '/discover/events');
    });

    test('the soonest ticket first; one with no date last', () {
      final next = _nextUp(tickets: [
        _ticket(3, name: 'Later', startsAt: _in(72)),
        _ticket(4, name: 'Undated', startsAt: null),
        _ticket(2, name: 'Sooner', startsAt: _in(24)),
      ]);
      expect(next.state, NextUpState.upcoming);
      expect(next.items.map((i) => i.name), ['Sooner', 'Later', 'Undated']);
      expect(next.nextAt(_now)!.eventId, 2);
    });

    test('an event on now comes before one later', () {
      final next = _nextUp(tickets: [
        _ticket(2, startsAt: _in(5)),
        _ticket(1, startsAt: _in(-1), hours: 4),
      ]);
      expect(next.items.first.eventId, 1);
      expect(next.toJson(_now)['items'], [
        containsPair('when', 'Happening now'),
        containsPair('when', 'Today · 3:00 pm'),
      ]);
    });

    test('over, revoked or called off: never next', () {
      final next = _nextUp(tickets: [
        _ticket(1, startsAt: _in(-5), hours: 2),
        _ticket(2, startsAt: _in(5), revoked: true),
        _ticket(3,
            startsAt: _in(6),
            cancellation: const EventCancellation(reason: 'Rain')),
        _ticket(4, startsAt: _in(30)),
      ]);
      expect(next.items.map((i) => i.eventId), [4]);
    });

    test('with no ticket, a registration under review is next', () {
      final next = _nextUp(requests: [
        _request(9, startsAt: _in(48), slug: 'design-jam-a1b2c3'),
      ]);
      final item = next.items.single;
      expect(item.underReview, isTrue);
      expect(item.badge, 'Under review');
      expect(item.club, 'Pixel Club');
      expect(item.place, isNull);
      // No ticket to show: the event's page, which says where it stands.
      expect(appLocationForLink(Uri.parse(item.link)),
          '/events/design-jam-a1b2c3');
    });

    test('a ticket comes before a registration under review', () {
      final next = _nextUp(
        tickets: [_ticket(1, startsAt: _in(72))],
        requests: [_request(9, startsAt: _in(24))],
      );
      expect(next.items.map((i) => i.eventId), [1, 9]);
      expect(next.nextAt(_now)!.underReview, isFalse);
    });

    test('a confirmed paid place waiting for its payment says so', () {
      final next = _nextUp(requests: [
        _request(9,
            startsAt: _in(24),
            status: RequestStatus.approved,
            pay: const RequestPay(amount: 199, claimToken: 'claim-secret')),
      ]);
      expect(next.items.single.badge, 'Payment due');
    });

    test('declined, withdrawn, past, or already a ticket: left out', () {
      final next = _nextUp(
        tickets: [_ticket(1, startsAt: _in(5))],
        requests: [
          _request(2, startsAt: _in(5), status: RequestStatus.declined),
          _request(3, startsAt: _in(5), status: RequestStatus.withdrawn),
          _request(4, startsAt: _in(-30)),
          _request(1, startsAt: _in(5)),
        ],
      );
      expect(next.items.map((i) => i.eventId), [1]);
    });

    test('at most four events', () {
      final next = _nextUp(tickets: [
        for (var i = 1; i <= 6; i++) _ticket(i, startsAt: _in(i * 24.0)),
      ]);
      expect(next.items.map((i) => i.eventId), [1, 2, 3, 4]);
    });

    test('the widget moves on to the next once one is over', () {
      final next = _nextUp(tickets: [
        _ticket(1, startsAt: _in(1), hours: 2),
        _ticket(2, startsAt: _in(24)),
      ]);
      expect(next.nextAt(_now)!.eventId, 1);
      expect(next.nextAt(_in(3))!.eventId, 2);
      expect(next.nextAt(_in(48)), isNull);
    });
  });

  group('the JSON the widgets read', () {
    test('the date, time and place, on India\'s clock', () {
      // Sat 14 Nov, 9:30 am in India.
      final next = _nextUp(
          tickets: [_ticket(12, startsAt: DateTime.utc(2026, 11, 14, 4))]);
      final json = next.toJson(_now);
      expect(json['v'], 1);
      final item = (json['items'] as List).single as Map<String, Object?>;
      expect(item, containsPair('event_id', 12));
      expect(item, containsPair('name', 'Hack Night'));
      expect(item, containsPair('weekday', 'SAT'));
      expect(item, containsPair('day', '14'));
      expect(item, containsPair('month', 'NOV'));
      expect(item, containsPair('time', '9:30 am'));
      expect(item, containsPair('date', 'Sat, 14 Nov'));
      expect(item, containsPair('place', 'Maker Space, Kochi'));
      expect(item, containsPair('when', 'Tomorrow · 9:30 am'));
      expect(item, containsPair('review', false));
      expect(item['starts_at'],
          DateTime.utc(2026, 11, 14, 4).millisecondsSinceEpoch);
      expect(item['ends_at'],
          DateTime.utc(2026, 11, 14, 7).millisecondsSinceEpoch);
    });

    test('an online event says Online', () {
      final next =
          _nextUp(tickets: [_ticket(1, startsAt: _in(5), online: true)]);
      expect(next.items.single.place, 'Online');
    });

    test('a tap opens the ticket by its event, in the app', () {
      final next = _nextUp(tickets: [_ticket(12, startsAt: _in(5))]);
      final link = Uri.parse(next.items.single.link);
      expect(link.toString(), 'https://myotherapp.in/events/12/ticket');
      final location = appLocationForLink(link);
      expect(location, '/events/12/ticket');
      // Signed out, it asks for sign-in and comes back to it.
      expect(needsAccount(location!), isTrue);
    });

    test('never the ticket code, its link or a request\'s token', () {
      final next = _nextUp(
        tickets: [_ticket(12, startsAt: _in(5), code: 'MOA-SECRET-QRCODE')],
        requests: [
          _request(9,
              startsAt: _in(24),
              status: RequestStatus.approved,
              pay: const RequestPay(amount: 99, claimToken: 'claim-secret')),
          _request(10, startsAt: _in(30)),
        ],
      );
      final json = jsonEncode(next.toJson(_now));
      expect(json, isNot(contains('MOA-SECRET-QRCODE')));
      expect(json, isNot(contains('/tickets/')));
      expect(json, isNot(contains('secret-request-token')));
      expect(json, isNot(contains('claim-secret')));
      expect(json, isNot(contains('ticket_url')));
    });

    test('an event with no date has no date fields', () {
      final next = _nextUp(tickets: [_ticket(1, startsAt: null)]);
      final item =
          (next.toJson(_now)['items'] as List).single as Map<String, Object?>;
      expect(item.containsKey('starts_at'), isFalse);
      expect(item.containsKey('day'), isFalse);
      expect(item['when'], 'Date to be announced');
    });
  });
}
