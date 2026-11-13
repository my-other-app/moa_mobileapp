import 'package:finnet/features/events/domain/event_page_rules.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/providers/registration_requests_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'registration_approval_model_test.dart' show requestBody;
import 'ticketing_model_test.dart' show ticketingBody;

/// The event's `viewer_last_request`, as the backend sends it: no event,
/// no name, only where it stands and its link.
Map<String, dynamic> lastRequestBody({
  String status = 'declined',
  String? token = 'tok_9',
  String? declineNote,
  String? closedReason,
  bool? canRegisterAgain,
}) =>
    {
      'id': 'req-9',
      'status': status,
      'token': token,
      'status_url': token == null ? null : 'https://myotherapp.in/requests/$token',
      'submitted_at': '2026-10-26T09:00:00Z',
      'decided_at': '2026-10-27T12:00:00Z',
      'decline_note': declineNote,
      'closed_reason': closedReason,
      'can_register_again': canRegisterAgain ?? status != 'declined',
    };

RegistrationRequest _parse(Map<String, dynamic> json) =>
    RegistrationRequest.fromJson(json)!;

void main() {
  group('viewer_last_request', () {
    test('read with its decision, note and whether to register again', () {
      final t = EventTicketing.fromJson({
        ...ticketingBody(),
        'requires_approval': true,
        'viewer_request': null,
        'viewer_last_request':
            lastRequestBody(declineNote: 'We ran out of room.'),
      })!;

      expect(t.saysViewerRequest, isTrue);
      expect(t.saysViewerLastRequest, isTrue);
      expect(t.saysViewerRequests, isTrue);
      final last = t.viewerLastRequest!;
      expect(last.status, RequestStatus.declined);
      expect(last.token, 'tok_9');
      expect(last.route, '/requests/tok_9');
      expect(last.decidedAt!.toUtc(), DateTime.utc(2026, 10, 27, 12));
      expect(last.declineNote, 'We ran out of room.');
      expect(last.canRegisterAgain, isFalse);
      expect(last.mayRegisterAgain, isFalse);
      expect(last.statusWord, 'Not confirmed');
    });

    test('kept when the club reviews every registration (no waiting list)',
        () {
      final t = EventTicketing.fromJson({
        ...ticketingBody(),
        'requires_approval': true,
        'viewer_last_request': lastRequestBody(status: 'withdrawn'),
      })!;
      expect(t.viewerLastRequest!.status, RequestStatus.withdrawn);
      expect(t.saysViewerLastRequest, isTrue);
    });

    test('an older server sends no key: My events\' list is asked', () {
      final t = EventTicketing.fromJson({
        ...ticketingBody(),
        'requires_approval': true,
        'viewer_request': null,
      })!;
      expect(t.viewerLastRequest, isNull);
      expect(t.saysViewerLastRequest, isFalse);
      expect(t.saysViewerRequests, isFalse);

      final older = EventTicketing.fromJson(ticketingBody())!;
      expect(older.saysViewerRequest, isFalse);
      expect(older.saysViewerRequests, isFalse);
    });

    test('an open one is enough: the last one is never sent with it', () {
      final t = EventTicketing.fromJson({
        ...ticketingBody(),
        'viewer_request': {'id': 'r', 'status': 'pending', 'token': 't'},
      })!;
      expect(t.saysViewerRequests, isTrue);
    });

    test('null is said too', () {
      final t = EventTicketing.fromJson({
        ...ticketingBody(),
        'viewer_request': null,
        'viewer_last_request': null,
      })!;
      expect(t.viewerLastRequest, isNull);
      expect(t.saysViewerRequests, isTrue);
    });
  });

  group('a request, decided', () {
    test('may register again: as the server says, else all but declined', () {
      expect(_parse(requestBody(status: 'declined')).mayRegisterAgain, isFalse);
      expect(
          _parse(requestBody(status: 'withdrawn')).mayRegisterAgain, isTrue);
      expect(_parse(requestBody(status: 'lapsed')).mayRegisterAgain, isTrue);
      expect(
          _parse(lastRequestBody(status: 'withdrawn', canRegisterAgain: false))
              .mayRegisterAgain,
          isFalse,
          reason: 'declined for this event before');
    });

    test('when the club decided, in words', () {
      final declined = _parse(requestBody(status: 'declined'));
      expect(declined.decidedLine,
          'Not confirmed ${requestMoment(declined.decidedAt!)}');
      final confirmed =
          _parse(requestBody(status: 'approved', ticketId: 'T-1'));
      expect(confirmed.decidedLine,
          'Confirmed ${requestMoment(confirmed.decidedAt!)}');
      expect(_parse(requestBody()).decidedLine, isNull);
      expect(_parse(requestBody(status: 'withdrawn')).decidedLine, isNull);
    });

    test('read again by its link: what the event said is kept', () {
      final fromEvent = _parse(lastRequestBody(
          status: 'withdrawn', canRegisterAgain: false));
      final fresh = _parse(requestBody(status: 'withdrawn', token: 'tok_9'));
      expect(fromEvent.mergedWith(fresh).canRegisterAgain, isFalse);
      final moved = _parse(requestBody(status: 'pending', token: 'tok_9'));
      expect(fromEvent.mergedWith(moved).canRegisterAgain, isNull);
    });
  });

  group('the event page\'s word on the last registration', () {
    test('declined: not confirmed, the club\'s note, and no Register', () {
      final said = lastRegistrationNotice(
          _parse(lastRequestBody(declineNote: 'We ran out of room.')),
          clubName: 'Tinkerhub')!;
      expect(said.title, "Your registration wasn't confirmed");
      expect(
          said.note,
          "Tinkerhub couldn't confirm your registration this time, so you "
          "can't register for this event again.");
      expect(said.quote, 'Tinkerhub said: “We ran out of room.”');
      expect(said.canRegister, isFalse);
      expect(said.label, 'SEE DETAILS');
    });

    test('declined without a link, nor a club name', () {
      final said = lastRegistrationNotice(_parse(lastRequestBody()),
          hasLink: false)!;
      expect(said.note, startsWith("The club couldn't confirm"));
      expect(said.quote, isNull);
      expect(said.label, 'NOT CONFIRMED');
    });

    test('cancelled: said, and Register as before', () {
      final said = lastRegistrationNotice(
          _parse(lastRequestBody(status: 'withdrawn')),
          clubName: 'Tinkerhub')!;
      expect(said.title, 'You cancelled your registration');
      expect(said.note, reviewsEveryRegistrationNote('Tinkerhub'));
      expect(said.canRegister, isTrue);
      expect(said.label, isNull);
    });

    test('cancelled after a decline: no Register', () {
      final said = lastRegistrationNotice(_parse(
          lastRequestBody(status: 'withdrawn', canRegisterAgain: false)))!;
      expect(said.canRegister, isFalse);
      expect(said.note, cantRegisterAgainLine);
      expect(said.label, 'SEE DETAILS');
    });

    test('expired: not paid in time, and Register', () {
      final said =
          lastRegistrationNotice(_parse(lastRequestBody(status: 'lapsed')))!;
      expect(said.title, "Your registration expired: it wasn't paid in time");
      expect(said.canRegister, isTrue);
    });

    test('closed: why, and no Register once the event is over or off', () {
      for (final (reason, words) in [
        (RequestClosedReasons.eventEnded, 'The event ended before Tinkerhub'),
        (RequestClosedReasons.eventCancelled, 'The event was cancelled'),
        (RequestClosedReasons.eventDeleted, 'The event was taken down'),
      ]) {
        final said = lastRegistrationNotice(
            _parse(lastRequestBody(status: 'closed', closedReason: reason)),
            clubName: 'Tinkerhub')!;
        expect(said.title, 'Your registration was closed', reason: reason);
        expect(said.note, startsWith(words), reason: reason);
        expect(said.canRegister, isFalse, reason: reason);
        expect(said.label, 'SEE DETAILS', reason: reason);
      }
      final unsaid =
          lastRegistrationNotice(_parse(lastRequestBody(status: 'closed')))!;
      expect(unsaid.canRegister, isTrue);
    });

    test('nothing to say: open, confirmed, or a ticket got another way', () {
      expect(lastRegistrationNotice(_parse(requestBody())), isNull);
      expect(
          lastRegistrationNotice(
              _parse(requestBody(status: 'approved', ticketId: 'T-1'))),
          isNull);
      expect(
          lastRegistrationNotice(_parse(lastRequestBody(
              status: 'closed',
              closedReason: RequestClosedReasons.registeredDirectly))),
          isNull);
      expect(lastRegistrationNotice(_parse(lastRequestBody(status: 'odd'))),
          isNull);
    });
  });

  group('My events\' list, for a server without viewer_last_request', () {
    RegistrationRequest req(String id, String status,
            {int event = 7, String submitted = '2026-10-26T09:00:00Z'}) =>
        _parse(requestBody(id: id, token: 'tok_$id', status: status,
            eventId: event)
          ..['submitted_at'] = submitted);

    test('the last one: a decline first, else the newest settled', () {
      final list = MyRegistrationRequests(loaded: true, items: [
        req('w', 'withdrawn', submitted: '2026-10-28T09:00:00Z'),
        req('d', 'declined', submitted: '2026-10-20T09:00:00Z'),
        req('x', 'declined', event: 9),
      ]);
      expect(list.lastFor(7)!.id, 'd',
          reason: 'registering again is refused after a decline');
      expect(list.lastFor(9)!.id, 'x');
      expect(list.lastFor(8), isNull);
      expect(list.lastFor(null), isNull);

      final settled = MyRegistrationRequests(loaded: true, items: [
        req('old', 'lapsed', submitted: '2026-10-20T09:00:00Z'),
        req('new', 'withdrawn', submitted: '2026-10-28T09:00:00Z'),
        req('in', 'approved', submitted: '2026-10-29T09:00:00Z'),
      ]);
      expect(settled.lastFor(7)!.id, 'new');
    });

    test('none while one is open, nor from a server without the list', () {
      final open = MyRegistrationRequests(loaded: true, items: [
        req('p', 'pending'),
        req('d', 'declined'),
      ]);
      expect(open.lastFor(7), isNull);
      expect(open.openFor(7)!.id, 'p');

      final unsupported = MyRegistrationRequests(
          loaded: true, supported: false, items: [req('d', 'declined')]);
      expect(unsupported.lastFor(7), isNull);
      expect(unsupported.notConfirmed(), isEmpty);
    });

    test('"Not confirmed": the declined ones for events still to come', () {
      final past = _parse(requestBody(id: 'past', status: 'declined')
        ..['event'] = {
          'id': 5,
          'name': 'Old Jam',
          'event_datetime': '2020-01-01T10:00:00Z',
        });
      final list = MyRegistrationRequests(loaded: true, items: [
        req('d', 'declined'),
        past,
        req('w', 'withdrawn'),
        req('p', 'pending'),
      ]);
      expect(list.notConfirmed(now: DateTime.utc(2026, 11, 13)).map((r) => r.id),
          ['d']);
    });
  });
}
