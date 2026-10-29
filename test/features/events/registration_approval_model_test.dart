import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ticketing_model_test.dart' show ticketingBody;

/// `GET /registration-requests/{token}` as the contract has it
/// (feature-register `approvals-contract.md`).
Map<String, dynamic> requestBody({
  String status = 'pending',
  String? token = 'tok_1',
  String? ticketId,
  Map<String, dynamic>? pay,
  String? declineNote,
  String? closedReason,
  String id = 'req-1',
  int eventId = 7,
}) =>
    {
      'id': id,
      'status': status,
      if (token != null) 'token': token,
      'event': {
        'id': eventId,
        'slug': 'hack-night',
        'name': 'Hack Night',
        'event_datetime': '2030-12-01T10:00:00Z',
        'poster': null,
        'club': {'name': 'Tinkerhub', 'slug': 'tinkerhub'},
      },
      'ticket_type': {'id': 3, 'name': 'Student'},
      'full_name': 'Asha Menon',
      'submitted_at': '2026-10-26T09:00:00Z',
      'decided_at': status == 'pending' ? null : '2026-10-26T12:00:00Z',
      'decline_note': declineNote,
      if (closedReason != null) 'closed_reason': closedReason,
      'ticket_id': ticketId,
      'pay': pay,
    };

/// A confirmed paid request's `pay`.
Map<String, dynamic> payBody({double amount = 199}) => {
      'amount': amount,
      'pay_by': '2030-11-02T12:30:00Z',
      'claim_token': 'clm_1',
      'claim_url': 'https://myotherapp.in/claim/clm_1',
    };

ApiException _refused(String code) => ApiException(
      message: 'Refused',
      statusCode: 409,
      type: ApiExceptionType.badRequest,
      errorCode: code,
      serverMessage: 'This event reviews every registration. Update the '
          'app, or register on myotherapp.in.',
    );

void main() {
  group('a request', () {
    test('pending: every field the status screen shows', () {
      final r = RegistrationRequest.fromJson(requestBody())!;
      expect(r.id, 'req-1');
      expect(r.status, RequestStatus.pending);
      expect(r.token, 'tok_1');
      expect(r.route, '/requests/tok_1');
      expect(r.event!.id, 7);
      expect(r.event!.slug, 'hack-night');
      expect(r.event!.route, '/events/hack-night');
      expect(r.event!.clubName, 'Tinkerhub');
      expect(r.clubName, 'Tinkerhub');
      expect(r.eventName, 'Hack Night');
      expect(r.event!.eventDateTime!.toUtc(), DateTime.utc(2030, 12, 1, 10));
      expect(r.ticketTypeId, 3);
      expect(r.ticketTypeName, 'Student');
      expect(r.fullName, 'Asha Menon');
      expect(r.submittedAt!.toUtc(), DateTime.utc(2026, 10, 26, 9));
      expect(r.decidedAt, isNull);
      expect(r.isPending, isTrue);
      expect(r.isOpen, isTrue);
      expect(r.hasTicket, isFalse);
      expect(r.awaitingPayment, isFalse);
      expect(r.pay, isNull);
    });

    test('confirmed, free: registered, with its ticket; not open', () {
      final r = RegistrationRequest.fromJson(
          requestBody(status: 'approved', ticketId: 'T-9'))!;
      expect(r.status, RequestStatus.approved);
      expect(r.ticketId, 'T-9');
      expect(r.hasTicket, isTrue);
      expect(r.awaitingPayment, isFalse);
      expect(r.isOpen, isFalse);
      expect(r.decidedAt, isNotNull);
    });

    test('confirmed, to pay: what, by when, and the claim link', () {
      final r = RegistrationRequest.fromJson(
          requestBody(status: 'approved', pay: payBody(amount: 199.5)))!;
      expect(r.awaitingPayment, isTrue);
      expect(r.isOpen, isTrue);
      expect(r.hasTicket, isFalse);
      expect(r.pay!.amount, 199.5);
      expect(r.pay!.payBy!.toUtc(), DateTime.utc(2030, 11, 2, 12, 30));
      expect(r.pay!.claimToken, 'clm_1');
      expect(r.pay!.claimUrl, 'https://myotherapp.in/claim/clm_1');
      expect(claimRoute(r.pay!.claimToken), '/claim/clm_1');
    });

    test('a pay without its claim token is no pay', () {
      final r = RegistrationRequest.fromJson(requestBody(
          status: 'approved', pay: {'amount': 199, 'pay_by': null}))!;
      expect(r.pay, isNull);
      expect(r.awaitingPayment, isFalse);
      expect(r.isOpen, isFalse);
    });

    test('declined, with the club\'s note', () {
      final r = RegistrationRequest.fromJson(
          requestBody(status: 'declined', declineNote: '  Full up, sorry.  '))!;
      expect(r.status, RequestStatus.declined);
      expect(r.declineNote, 'Full up, sorry.');
      expect(r.isOpen, isFalse);
    });

    test('withdrawn, lapsed and closed are known; anything else is unknown',
        () {
      for (final (word, status) in [
        ('withdrawn', RequestStatus.withdrawn),
        ('lapsed', RequestStatus.lapsed),
        ('closed', RequestStatus.closed),
        ('CLOSED', RequestStatus.closed),
        ('archived', RequestStatus.unknown),
        (null, RequestStatus.unknown),
      ]) {
        final body = requestBody()..['status'] = word;
        final r = RegistrationRequest.fromJson(body)!;
        expect(r.status, status, reason: '$word');
        expect(r.isOpen, isFalse, reason: '$word');
      }
    });

    test('closed: its reason, read when the server says it', () {
      for (final reason in [
        'event_ended',
        'event_deleted',
        'event_cancelled',
        'registered_directly',
      ]) {
        final r = RegistrationRequest.fromJson(
            requestBody(status: 'closed', closedReason: reason))!;
        expect(r.closedReason, reason);
        expect(r.registeredDirectly, reason == 'registered_directly');
      }
      final upper = RegistrationRequest.fromJson(
          requestBody(status: 'closed', closedReason: 'REGISTERED_DIRECTLY'))!;
      expect(upper.closedReason, RequestClosedReasons.registeredDirectly);
      expect(
          RegistrationRequest.fromJson(requestBody(status: 'closed'))!
              .closedReason,
          isNull);
      // Read again: the fresh reason.
      final merged = RegistrationRequest.fromJson(requestBody())!.mergedWith(
          RegistrationRequest.fromJson(
              requestBody(status: 'closed', closedReason: 'event_cancelled'))!);
      expect(merged.closedReason, RequestClosedReasons.eventCancelled);
    });

    test('where it stands, in the attendee\'s words', () {
      String? word(Map<String, dynamic> body) =>
          RegistrationRequest.fromJson(body)!.statusWord;
      expect(word(requestBody()), 'Under review');
      expect(
          word(requestBody(status: 'approved', ticketId: 'T-9')), 'Confirmed');
      expect(word(requestBody(status: 'approved')), 'Confirmed');
      final pay = RegistrationRequest.fromJson(
          requestBody(status: 'approved', pay: payBody()))!;
      expect(
          pay.statusWord,
          'Confirmed · pay by ${requestMoment(pay.pay!.payBy!)} to get your '
          'ticket');
      expect(
          word(requestBody(
              status: 'approved', pay: {...payBody(), 'pay_by': null})),
          'Confirmed · pay to get your ticket');
      expect(word(requestBody(status: 'declined')), 'Not confirmed');
      expect(word(requestBody(status: 'withdrawn')), 'Cancelled');
      expect(word(requestBody(status: 'lapsed')), 'Expired');
      expect(word(requestBody(status: 'closed')), 'Closed');
      expect(word(requestBody(status: 'archived')), isNull);
    });

    test('the first name, and "the club" mid-sentence', () {
      final r = RegistrationRequest.fromJson(requestBody())!;
      expect(r.firstName, 'Asha');
      expect(r.clubMidSentence, 'Tinkerhub');
      final bare = RegistrationRequest.fromJson(
          {'id': 'r', 'status': 'pending', 'full_name': '  '})!;
      expect(bare.firstName, isNull);
      expect(bare.clubName, 'The club');
      expect(bare.clubMidSentence, 'the club');
    });

    test('the token: its own, else the status link\'s, else the one asked by',
        () {
      expect(
          RegistrationRequest.fromJson(requestBody(token: null)
                ..['status_url'] = 'https://myotherapp.in/requests/from_url')!
              .token,
          'from_url');
      expect(
          RegistrationRequest.fromJson(requestBody(token: null),
                  token: 'asked')!
              .token,
          'asked');
      final none = RegistrationRequest.fromJson(requestBody(token: null))!;
      expect(none.token, isNull);
      expect(none.route, isNull);
    });

    test('nothing to know it by, or not an object: null', () {
      expect(RegistrationRequest.fromJson({'status': 'pending'}), isNull);
      expect(RegistrationRequest.fromJson(null), isNull);
      expect(RegistrationRequest.fromJson('pending'), isNull);
      expect(RegistrationRequest.fromJson(const [1, 2]), isNull);
    });

    test('odd fields are read where they can be, never thrown on', () {
      final r = RegistrationRequest.fromJson({
        'id': 42,
        'status': 'pending',
        'token': 'tok',
        'event': {'id': '7', 'name': 7, 'club': 'not an object'},
        'ticket_type': 'Student',
        'submitted_at': 12,
        'pay': 'no',
      })!;
      expect(r.id, '42');
      expect(r.event!.id, 7);
      expect(r.event!.name, '7');
      expect(r.event!.clubName, isNull);
      expect(r.clubName, 'The club');
      expect(r.ticketTypeName, isNull);
      expect(r.submittedAt, isNull);
      expect(r.pay, isNull);
    });

    test('read again: the fresh word, keeping what it leaves out', () {
      final known = RegistrationRequest.fromJson(requestBody())!;
      final fresh = RegistrationRequest.fromJson({
        'id': 'req-1',
        'status': 'approved',
        'ticket_id': 'T-9',
      })!;
      final merged = known.mergedWith(fresh);
      expect(merged.status, RequestStatus.approved);
      expect(merged.ticketId, 'T-9');
      expect(merged.token, 'tok_1');
      expect(merged.event!.name, 'Hack Night');
      expect(merged.ticketTypeName, 'Student');
    });

    test('mine: the items, skipping rows that can\'t be read', () {
      final list = RegistrationRequest.listFromJson({
        'items': [
          requestBody(id: 'a'),
          'junk',
          {'status': 'pending'},
          requestBody(id: 'b', status: 'approved', pay: payBody()),
        ],
      });
      expect(list.map((r) => r.id), ['a', 'b']);
      expect(RegistrationRequest.listFromJson([requestBody(id: 'c')]).single.id,
          'c');
      expect(RegistrationRequest.listFromJson({'items': null}), isEmpty);
      expect(RegistrationRequest.listFromJson(null), isEmpty);
    });
  });

  group('the request link', () {
    test('its token from the website\'s address, or the bare token', () {
      expect(requestTokenFrom('https://myotherapp.in/requests/Xy3_a-b'),
          'Xy3_a-b');
      expect(
          requestTokenFrom('https://myotherapp.in/requests/Xy3?utm=1'), 'Xy3');
      expect(requestTokenFrom('Xy3'), 'Xy3');
      expect(requestTokenFrom('  '), isNull);
      expect(requestTokenFrom(null), isNull);
      expect(requestTokenFrom('https://myotherapp.in/claim/Xy3'), isNull);
    });

    test('the app\'s route encodes the token', () {
      expect(requestRoute('a b'), '/requests/a%20b');
    });
  });

  group('registering', () {
    test('an approval answer is a request: no ticket, nothing to pay', () {
      final result = RegistrationResult.fromJson({
        'approval': {
          'id': 'req-1',
          'status': 'pending',
          'submitted_at': '2026-10-26T09:00:00Z',
          'token': 'tok_1',
          'status_url': 'https://myotherapp.in/requests/tok_1',
        },
        'event_registration_id': null,
        // A server mistake must not start a payment.
        'pay_amount': 199,
      });
      expect(result.awaitingApproval, isTrue);
      expect(result.approval!.token, 'tok_1');
      expect(result.approval!.status, RequestStatus.pending);
      expect(
          result.approval!.statusUrl, 'https://myotherapp.in/requests/tok_1');
      expect(result.registrationId, isNull);
      expect(result.needsPayment, isFalse);
    });

    test('a registration has no approval, and pays as before', () {
      final result = RegistrationResult.fromJson({
        'event_registration_id': 'reg-1',
        'pay_amount': 199,
        'ticket_id': 'T-1',
      });
      expect(result.approval, isNull);
      expect(result.awaitingApproval, isFalse);
      expect(result.needsPayment, isTrue);
    });

    test('ADD_ONS_NOT_ALLOWED is said plainly', () {
      final refusal = describeRegistrationError(ApiException(
        message: 'Refused',
        statusCode: 422,
        type: ApiExceptionType.badRequest,
        errorCode: 'ADD_ONS_NOT_ALLOWED',
        serverMessage: 'A request holds no add-ons.',
      ));
      expect(refusal.title, 'This event reviews registrations now');
      expect(
          refusal.message,
          "Add-ons can't be picked when registrations are reviewed, so "
          "they've been removed. Check your details and register again.");
      expect(refusal.action, isNull);
    });

    test('REQUEST_DECLINED and APPROVAL_REQUIRED are said plainly', () {
      final declined = describeRegistrationError(_refused('REQUEST_DECLINED'));
      expect(declined.title, "You can't register again");
      expect(
          declined.message,
          "The club couldn't confirm your registration for this event, so "
          "you can't register again with this email.");
      expect(declined.closed, isTrue);
      expect(declined.action, isNull);
      expect(
          describeRegistrationError(_refused('REQUEST_DECLINED'),
                  clubName: 'Tinkerhub')
              .message,
          "Tinkerhub couldn't confirm your registration for this event, so "
          "you can't register again with this email.");

      final required = describeRegistrationError(_refused('APPROVAL_REQUIRED'));
      expect(required.title, 'This event reviews registrations now');
      expect(required.message, 'Register again from the event page.');
      expect(required.message, isNot(contains('Update the app')),
          reason: "this app is the updated one");
    });

    test('full, on an event that reviews registrations: no "place"', () {
      final full = describeRegistrationError(
          ApiException(
            message: 'Refused',
            statusCode: 409,
            type: ApiExceptionType.badRequest,
            errorCode: 'EVENT_FULL',
            errors: const {'waitlist': true},
          ),
          approval: true);
      expect(full.title, 'This event is full');
      expect(full.message, 'Every seat at this event has been taken.');
      expect(full.action, isNull);
    });
  });

  group('the event says it confirms each place', () {
    test('ticketing: requires_approval, false when missing', () {
      expect(
          EventTicketing.fromJson(
                  {...ticketingBody(), 'requires_approval': true})!
              .requiresApproval,
          isTrue);
      expect(
          EventTicketing.fromJson(ticketingBody())!.requiresApproval, isFalse);
    });

    test('ticketing: the viewer\'s open request, or null, or not said', () {
      final waiting = EventTicketing.fromJson({
        ...ticketingBody(),
        'requires_approval': true,
        'viewer_request': {
          'id': 'req-1',
          'status': 'pending',
          'token': 'tok_1',
          'status_url': 'https://myotherapp.in/requests/tok_1',
        },
      })!;
      expect(waiting.saysViewerRequest, isTrue);
      expect(waiting.viewerRequest!.token, 'tok_1');
      expect(waiting.viewerRequest!.route, '/requests/tok_1');
      expect(waiting.viewerRequest!.status, RequestStatus.pending);

      final none = EventTicketing.fromJson(
          {...ticketingBody(), 'viewer_request': null})!;
      expect(none.saysViewerRequest, isTrue);
      expect(none.viewerRequest, isNull);

      final older = EventTicketing.fromJson(ticketingBody())!;
      expect(older.saysViewerRequest, isFalse);
      expect(older.viewerRequest, isNull);
    });

    test('the website\'s page: on the event or its ticketing', () {
      Map<String, dynamic> page(Map<String, dynamic> extra) => {
            'event': {'id': 7, 'slug': 'hack-night', 'name': 'Hack', ...extra},
          };
      expect(
          EventPageDetails.fromJson(page({'requires_approval': true}))!
              .requiresApproval,
          isTrue);
      expect(
          EventPageDetails.fromJson(page({
            'ticketing': {'requires_approval': true}
          }))!
              .requiresApproval,
          isTrue);
      expect(EventPageDetails.fromJson(page({}))!.requiresApproval, isFalse);
    });
  });

  group('the claim view', () {
    Map<String, dynamic> offer({String? reason, bool club = true}) => {
          'id': 'o-1',
          'status': 'offered',
          'event': {
            'id': 7,
            'slug': 'hack-night',
            'name': 'Hack Night',
            if (club) 'club': {'name': 'Tinkerhub'},
          },
          'ticket_type': {'id': 3, 'name': 'Student', 'price': 199},
          if (reason != null) 'reason': reason,
        };

    test('reason "approved": the club confirmed the place', () {
      final o = WaitlistOffer.fromJson(offer(reason: 'approved'))!;
      expect(o.fromApproval, isTrue);
      expect(o.clubName, 'Tinkerhub');
      expect(o.clubOrDefault, 'Tinkerhub');
    });

    test('no reason: a waiting list\'s turn, as before', () {
      final o = WaitlistOffer.fromJson(offer(club: false))!;
      expect(o.fromApproval, isFalse);
      expect(o.reason, isNull);
      expect(o.clubOrDefault, 'The club');
      expect(o.payable, 199);
    });

    test('the confirmed amount: what a confirmed place costs', () {
      final o = WaitlistOffer.fromJson(
          {...offer(reason: 'approved'), 'amount': 159.2})!;
      expect(o.amount, 159.2);
      expect(o.payable, 159.2);
      final none = WaitlistOffer.fromJson(offer(reason: 'approved'))!;
      expect(none.amount, isNull);
      expect(none.payable, 199);
    });

    test('reason "waitlist" is a waiting list\'s turn: no amount applies', () {
      final o =
          WaitlistOffer.fromJson({...offer(reason: 'waitlist'), 'amount': 99})!;
      expect(o.fromApproval, isFalse);
      expect(o.payable, 199);
    });
  });
}
