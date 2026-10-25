import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/events/domain/entities/saved_ticket.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:flutter_test/flutter_test.dart';

/// The event page's `ticketing`, as docs/TICKETING.md §2 writes it.
Map<String, dynamic> ticketingBody({
  bool requiresChoice = true,
  bool soldOut = false,
  bool waitlistEnabled = true,
  List<Map<String, dynamic>>? types,
  List<Map<String, dynamic>> viewer = const [],
}) =>
    {
      'types': types ??
          [
            {
              'id': 12,
              'name': 'Early bird',
              'description': 'Until Friday',
              'price': 199.0,
              'currency': 'INR',
              'is_free': false,
              'capacity': 100,
              'available': 3,
              'status': 'on_sale',
              'sales_start': null,
              'sales_end': '2026-11-01T23:59:00+05:30',
              'per_person_limit': 1,
              'is_hidden': false,
              'waitlist': false,
            },
            {
              'id': 13,
              'name': 'VIP',
              'price': 999.0,
              'is_free': false,
              'available': 0,
              'status': 'sold_out',
              'waitlist': true,
            },
          ],
      'requires_choice': requiresChoice,
      'available': 40,
      'sold_out': soldOut,
      'waitlist': {'enabled': waitlistEnabled, 'offer_hours': 24},
      'viewer_waitlist': viewer,
    };

ApiException _refusal(int status, String code,
        {Map<String, dynamic>? errors, String message = 'Refused'}) =>
    ApiException.fromResponse(status, {
      'message': message,
      'error_code': code,
      'errors': errors ?? <String, dynamic>{},
    });

void main() {
  group('EventTicketing', () {
    test('a server without ticket types sends none: null, today\'s flow', () {
      expect(EventTicketing.fromJson(null), isNull);
      expect(EventTicketing.fromJson(const {'requires_choice': true}), isNull);
      expect(EventTicketing.fromJson('nonsense'), isNull);
    });

    test('reads the types, the choice, the waiting list and the viewer', () {
      final t = EventTicketing.fromJson(ticketingBody(viewer: [
        {
          'id': 'a-uuid',
          'ticket_type_id': 13,
          'ticket_type_name': 'VIP',
          'status': 'waiting',
          'position': 3,
        },
      ]))!;

      expect(t.requiresChoice, isTrue);
      expect(t.types.map((x) => x.name), ['Early bird', 'VIP']);
      expect(t.types.first.price, 199);
      expect(t.types.first.statusLine, 'Only 3 left');
      expect(t.types.last.status, TicketTypeStatus.soldOut);
      expect(t.types.last.statusLine, 'Sold out · waiting list open');
      expect(t.waitlistEnabled, isTrue);
      expect(t.canJoinWaitlist, isTrue);
      expect(t.waitlistTypes.single.id, 13);
      expect(t.openPlaces.single.summary, "You're #3 in line for VIP.");
      expect(t.anyPaid, isTrue);
      expect(t.priceRange, '₹199 – ₹999');
    });

    test('a type without an id or a name is left out, never a crash', () {
      final t = EventTicketing.fromJson(ticketingBody(types: [
        {'id': 1, 'name': 'General', 'price': '0', 'status': 'on_sale'},
        {'name': 'No id'},
        {'id': 3},
        {'id': 4, 'name': 'New status', 'status': 'paused'},
      ]))!;
      expect(t.types.map((x) => x.id), [1, 4]);
      expect(t.types.first.isFree, isTrue);
      // A status this build doesn't know can't be bought.
      expect(t.types.last.onSale, isFalse);
      expect(t.priceRange, 'Free');
    });

    test('the first choice: a linked type on sale, else the only one on sale',
        () {
      final t = EventTicketing.fromJson(ticketingBody())!;
      // Only Early bird is on sale.
      expect(t.initialChoice(), 12);
      // VIP is sold out: a link to it doesn't choose it.
      expect(t.initialChoice(linked: 13), 12);

      final two = EventTicketing.fromJson(ticketingBody(types: [
        {'id': 1, 'name': 'Student', 'price': 99, 'status': 'on_sale'},
        {'id': 2, 'name': 'General', 'price': 199, 'status': 'on_sale'},
      ]))!;
      expect(two.initialChoice(), isNull, reason: 'the person picks');
      expect(two.initialChoice(linked: 2), 2);

      final single = EventTicketing.fromJson(ticketingBody(
          requiresChoice: false,
          types: [
            {'id': 1, 'name': 'General', 'price': 99, 'status': 'on_sale'},
          ]))!;
      expect(single.initialChoice(), isNull,
          reason: "one type: the server's own choice, nothing sent");
    });

    test('a type not on sale yet says when it opens', () {
      final type = TicketType.fromJson({
        'id': 5,
        'name': 'Late',
        'status': 'not_started',
        'sales_start': '2030-11-01T09:00:00Z',
      })!;
      expect(type.statusLine, startsWith('On sale from 1 Nov'));
      expect(
          TicketType.fromJson({'id': 6, 'name': 'X', 'status': 'ended'})!
              .statusLine,
          'Sales ended');
    });
  });

  group('money', () {
    test('rupees with Indian grouping, paise only when there are some', () {
      expect(formatRupees(199), '₹199');
      expect(formatRupees(1340), '₹1,340');
      expect(formatRupees(150000), '₹1,50,000');
      expect(formatRupees(159.2), '₹159.20');
      expect(priceLabel(0), 'Free');
    });
  });

  group('DiscountQuote', () {
    test('reads the price effect', () {
      final q = DiscountQuote.fromJson({
        'code': 'EARLY20',
        'ticket_type_id': 12,
        'price': 199.0,
        'discount': 39.8,
        'amount': 159.2,
        'free': false,
      })!;
      expect(q.summary, 'EARLY20 applied: ₹39.80 off, you pay ₹159.20.');
      final free = DiscountQuote.fromJson(
          {'code': 'ALL', 'price': 199, 'discount': 199, 'amount': 0})!;
      expect(free.free, isTrue);
      expect(free.summary, 'ALL applied: your ticket is free.');
      expect(DiscountQuote.fromJson({'amount': 3}), isNull);
    });
  });

  group('EventCancellation', () {
    test('cancelled with a reason, from the event or a row', () {
      final c = EventCancellation.of({
        'status': 'cancelled',
        'registration_open': false,
        'cancellation': {
          'reason': 'The venue flooded.',
          'cancelled_at': '2026-10-20T10:00:00+05:30',
        },
      })!;
      expect(c.reason, 'The venue flooded.');
      expect(c.cancelledAt, isNotNull);
      // The status alone is enough.
      expect(EventCancellation.of({'status': 'cancelled'})!.reason, isNull);
    });

    test('anything else is not cancelled', () {
      expect(EventCancellation.of({'status': 'live'}), isNull);
      expect(EventCancellation.of({}), isNull);
      expect(EventCancellation.of(null), isNull);
    });
  });

  group('the ticket type a ticket names', () {
    test('wherever the server put it', () {
      expect(
          ticketTypeNameOf({
            'ticket_type': {'id': 12, 'name': 'Early bird'}
          }),
          'Early bird');
      expect(ticketTypeNameOf({'ticket_type_name': 'VIP'}), 'VIP');
      expect(ticketTypeNameOf({'ticket_label': 'Student'}), 'Student');
      expect(ticketTypeNameOf({'ticket_type': null}), isNull);
      expect(ticketTypeNameOf({'ticket_label': '  '}), isNull);
    });

    test('a saved ticket keeps it, and its payment and cancellation', () {
      final ticket = SavedTicket.fromRegistration({
        'id': 7,
        'name': 'Hack Night',
        'ticket_id': 'T-1',
        'has_fee': true,
        'is_paid': true,
        'ticket_type_name': 'VIP',
        'status': 'cancelled',
        'cancellation': {'reason': 'Rain'},
      })!;
      expect(ticket.ticketType, 'VIP');
      expect(ticket.paid, isTrue);
      expect(ticket.cancellation?.reason, 'Rain');

      final back = SavedTicket.fromJson(ticket.toJson())!;
      expect(back.ticketType, 'VIP');
      expect(back.paid, isTrue);
      expect(back.cancellation?.reason, 'Rain');

      // Today's rows say none of it.
      final plain = SavedTicket.fromRegistration(
          {'id': 7, 'name': 'Hack Night', 'ticket_id': 'T-1'})!;
      expect(plain.ticketType, isNull);
      expect(plain.paid, isFalse);
      expect(plain.cancellation, isNull);
      expect(plain.withTicketType('General').ticketType, 'General');
    });
  });

  group('RegistrationResult', () {
    test('a code that covered the ticket: nothing to pay, on a paid event',
        () {
      final r = RegistrationResult.fromJson({
        'event_id': 7,
        'event_registration_id': 'reg-1',
        'ticket_id': 'T-1',
        'pay_amount': 0,
        'ticket_type': {'id': 12, 'name': 'Early bird'},
        'price': 199.0,
        'discount': {'code': 'FREE100', 'amount': 199.0},
        'is_paid': true,
      });
      expect(r.needsPayment, isFalse);
      expect(r.isPaid, isTrue);
      expect(r.ticketTypeName, 'Early bird');
      expect(r.discountCode, 'FREE100');
      expect(r.forGuest, isFalse);
    });

    test("a guest's claim carries a session: not this account's", () {
      final r = RegistrationResult.fromJson({
        'pay_amount': 159.2,
        'auth_token': {'access_token': 'x', 'token_type': 'bearer'},
      });
      expect(r.needsPayment, isTrue);
      expect(r.forGuest, isTrue);
    });
  });

  group('WaitlistOffer', () {
    test('reads what the claim page shows', () {
      final o = WaitlistOffer.fromJson({
        'id': 'u-1',
        'status': 'offered',
        'event': {
          'id': 7,
          'slug': 'hack-night',
          'name': 'Hack Night',
          'event_datetime': '2030-12-01T10:00:00Z',
          'location_name': 'CET',
          'poster': {},
        },
        'ticket_type': {
          'id': 12,
          'name': 'Early bird',
          'price': 199.0,
          'currency': 'INR'
        },
        'full_name': 'Asha K',
        'email': 'as•••@gmail.com',
        'phone': '•••••3210',
        'expires_at': '2030-11-02T18:00:00+05:30',
        'needs_email': false,
        'needs_payment': true,
        'registration_id': null,
      })!;
      expect(o.status, OfferStatus.offered);
      expect(o.eventRoute, '/events/hack-night');
      expect(o.ticketTypeName, 'Early bird');
      expect(o.price, 199);
      expect(o.needsPayment, isTrue);
      expect(o.registrationId, isNull);
      expect(WaitlistOffer.fromJson({'status': 'offered'}), isNull);
      expect(offerStatusFrom('whatever'), OfferStatus.unknown);
    });

    test('the claim link\'s token, from the link or as it is', () {
      expect(claimTokenFrom('https://myotherapp.in/claim/Xy3_abc-9'),
          'Xy3_abc-9');
      expect(claimTokenFrom('https://myotherapp.in/claim/Xy3?utm=1'), 'Xy3');
      expect(claimTokenFrom('Xy3'), 'Xy3');
      expect(claimTokenFrom('https://myotherapp.in/claim/'), isNull);
      expect(claimTokenFrom(null), isNull);
      expect(claimRoute('a/b'), '/claim/a%2Fb');
    });
  });

  group('refusals', () {
    test('a full event or sold-out type with its list open offers it', () {
      expect(
          offersWaitlist(_refusal(400, 'EVENT_FULL', errors: {'waitlist': true})),
          isTrue);
      expect(
          offersWaitlist(_refusal(409, 'TICKET_TYPE_SOLD_OUT',
              errors: {'ticket_type_id': 13, 'waitlist': true})),
          isTrue);
      expect(
          offersWaitlist(
              _refusal(400, 'EVENT_FULL', errors: {'waitlist': false})),
          isFalse);
      expect(offersWaitlist(_refusal(400, 'EVENT_FULL')), isFalse);
    });

    test('a cancelled event: registering and paying', () {
      expect(
          isCancelledRefusal(_refusal(400, 'REGISTRATIONS_CLOSED',
              errors: {'closed_reason': 'cancelled'})),
          isTrue);
      expect(isCancelledRefusal(_refusal(409, 'EVENT_CANCELLED')), isTrue);
      expect(
          isCancelledRefusal(_refusal(400, 'REGISTRATIONS_CLOSED',
              errors: {'closed_reason': 'deadline_passed'})),
          isFalse);
    });

    test('every code refusal in words; a 429 asks for a minute', () {
      for (final code in [
        'DISCOUNT_CODE_INVALID',
        'DISCOUNT_CODE_NOT_STARTED',
        'DISCOUNT_CODE_EXPIRED',
        'DISCOUNT_CODE_NOT_FOR_TYPE',
        'DISCOUNT_CODE_USED_UP',
        'DISCOUNT_CODE_LIMIT',
      ]) {
        final words = discountCodeProblem(_refusal(409, code));
        expect(words, isNotNull, reason: code);
        expect(words, isNot(contains('DISCOUNT')), reason: code);
      }
      expect(discountCodeProblem(ApiException.fromResponse(429, null)),
          contains('Wait a minute'));
      expect(discountCodeProblem(_refusal(400, 'EVENT_FULL')), isNull);
    });

    test('the waiting list\'s refusals in words', () {
      expect(waitlistJoinProblem(_refusal(409, 'WAITLIST_NOT_NEEDED')),
          contains('register instead'));
      expect(waitlistJoinProblem(_refusal(409, 'WAITLIST_CLOSED')),
          contains("isn't open"));
      expect(waitlistJoinProblem(_refusal(422, 'WAITLIST_CONTACT_REQUIRED')),
          contains('email address or a phone number'));
      expect(waitlistJoinProblem(ApiException.fromResponse(429, null)),
          contains('Wait a minute'));
    });

    test('a registration refused for its ticket, said for a person', () {
      expect(describeRegistrationError(_refusal(422, 'TICKET_TYPE_REQUIRED')).title,
          'Choose a ticket');
      final soldOut = describeRegistrationError(_refusal(
          409, 'TICKET_TYPE_SOLD_OUT',
          errors: {'ticket_type_id': 13, 'waitlist': true}));
      expect(soldOut.action, RegistrationAction.joinWaitlist);
      expect(soldOut.actionLabel, 'Join the waiting list');
      final full = describeRegistrationError(
          _refusal(400, 'EVENT_FULL', errors: {'waitlist': true}));
      expect(full.action, RegistrationAction.joinWaitlist);
      expect(
          describeRegistrationError(
                  _refusal(400, 'EVENT_FULL', errors: {'waitlist': false}))
              .action,
          isNull);
      final notYet = describeRegistrationError(_refusal(
          409, 'TICKET_TYPE_NOT_ON_SALE',
          errors: {'closed_reason': 'not_started', 'opens_at': '2030-11-01T09:00:00Z'}));
      expect(notYet.title, "This ticket isn't on sale yet");
      expect(notYet.message, contains('Nov'));
      expect(describeRegistrationError(_refusal(409, 'TICKET_TYPE_LIMIT')).title,
          "You've reached this ticket's limit");
      final cancelled = describeRegistrationError(_refusal(
          400, 'REGISTRATIONS_CLOSED',
          errors: {'closed_reason': 'cancelled'}));
      expect(cancelled.title, 'This event was cancelled');
      expect(cancelled.closed, isTrue);
    });
  });
}
