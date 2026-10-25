import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/events/data/ticketing_api.dart';
import 'package:finnet/features/events/presentation/providers/event_cancellation_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';
import 'ticketing_model_test.dart' show ticketingBody;

/// The calls the attendee's side makes, against a fake API: the paths,
/// the bodies, and what comes back read into the models.
void main() {
  late RouteAdapter api;
  final ticketing = TicketingApi();

  setUp(() => api = useFakeApi());

  test('the ticket types, with a hidden type a link named', () async {
    api.on('GET', '/events/hack-night/ticket-types', ticketingBody());

    final t = await ticketing.ticketTypes('hack-night', linked: 14);

    expect(t!.types, hasLength(2));
    final sent = api.sent('GET', '/events/hack-night/ticket-types').single;
    expect(sent.queryParameters, {'ticket_type': 14});
  });

  test('a server without ticket types: a 404, thrown for the caller', () async {
    await expectLater(ticketing.ticketTypes(7), throwsA(isA<ApiException>()));
  });

  test('checking a code sends the code, the type and who asks', () async {
    api.on('POST', '/events/7/discount-codes/check', {
      'code': 'EARLY20',
      'ticket_type_id': 12,
      'price': 199.0,
      'discount': 39.8,
      'amount': 159.2,
      'free': false,
    });

    final q = await ticketing.checkCode(7,
        code: ' early20 ',
        ticketTypeId: 12,
        email: 'asha@example.com',
        phone: '');

    expect(q.amount, 159.2);
    expect(api.sent('POST', '/events/7/discount-codes/check').single.data, {
      'code': 'early20',
      'ticket_type_id': 12,
      'email': 'asha@example.com',
    });
  });

  test('a refused code throws with its code', () async {
    api.on('POST', '/events/7/discount-codes/check',
        {'message': 'Invalid', 'error_code': 'DISCOUNT_CODE_INVALID'},
        status: 422);
    await expectLater(
      ticketing.checkCode(7, code: 'NOPE'),
      throwsA(isA<ApiException>()
          .having((e) => e.errorCode, 'code', 'DISCOUNT_CODE_INVALID')),
    );
  });

  test('joining, seeing and leaving the waiting list', () async {
    api
      ..on('POST', '/events/7/waitlist', {
        'id': 'w-1',
        'ticket_type_id': 13,
        'ticket_type_name': 'VIP',
        'status': 'waiting',
        'position': 3,
        'created': true,
      })
      ..on('GET', '/events/7/waitlist/me', [
        {'id': 'w-1', 'ticket_type_id': 13, 'status': 'waiting', 'position': 3},
      ])
      ..on('DELETE', '/events/7/waitlist/me', {'left': 1});

    final entry = await ticketing.joinWaitlist(7,
        ticketTypeId: 13,
        fullName: ' Asha K ',
        email: 'asha@example.com',
        phone: '9876543210',
        whatsappOptIn: true);
    expect(entry.position, 3);
    expect(entry.created, isTrue);
    expect(api.sent('POST', '/events/7/waitlist').single.data, {
      'ticket_type_id': 13,
      'full_name': 'Asha K',
      'email': 'asha@example.com',
      'phone': '9876543210',
      'whatsapp_opt_in': true,
    });

    expect((await ticketing.myWaitlist(7)).single.id, 'w-1');
    expect(await ticketing.leaveWaitlist(7), 1);
  });

  test('an offer is read, claimed and declined by its token, no session',
      () async {
    api
      ..on('GET', '/waitlist/offers/tok_1', {
        'id': 'u-1',
        'status': 'offered',
        'event': {'id': 7, 'slug': 'hack-night', 'name': 'Hack Night'},
        'ticket_type': {'id': 12, 'name': 'Early bird', 'price': 0},
        'full_name': 'Asha K',
        'needs_email': true,
      })
      ..on('POST', '/waitlist/offers/tok_1/claim', {
        'event_id': 7,
        'event_registration_id': 'reg-1',
        'ticket_id': 'T-9',
        'pay_amount': 0,
        'ticket_type': {'id': 12, 'name': 'Early bird'},
      })
      ..on('POST', '/waitlist/offers/tok_1/decline', {'declined': true});

    final offer = await ticketing.offer('tok_1');
    expect(offer.needsEmail, isTrue);
    expect(api.sent('GET', '/waitlist/offers/tok_1').single.extra['skipAuth'],
        isTrue);

    final claimed = await ticketing.claim('tok_1', email: 'asha@example.com');
    expect(claimed.ticketId, 'T-9');
    expect(claimed.needsPayment, isFalse);
    expect(api.sent('POST', '/waitlist/offers/tok_1/claim').single.data,
        {'email': 'asha@example.com'});

    await ticketing.decline('tok_1');
    expect(api.sent('POST', '/waitlist/offers/tok_1/decline'), hasLength(1));
  });

  test('whether an event was called off, from its public page', () async {
    api.on('GET', '/discover/events/hack-night', {
      'event': {
        'id': 7,
        'status': 'cancelled',
        'registration_open': false,
        'cancellation': {'reason': 'The venue flooded.'},
      },
    });

    final c = await ticketing.cancellationOf('hack-night');

    expect(c?.reason, 'The venue flooded.');
    expect(
        api.sent('GET', '/discover/events/hack-night').single.extra['skipAuth'],
        isTrue,
        reason: 'public, and the same for everyone');
    // Not public, or no answer: not known, never an error.
    expect(await ticketing.cancellationOf('draft-event'), isNull);
    expect(api.sent('GET', '/events/info/7'), isEmpty,
        reason: '/events/info counts a page view');
  });

  test('a lookup a card makes is asked once in a while, not every draw',
      () async {
    api.on('GET', '/discover/events/7', {
      'event': {'id': 7, 'status': 'cancelled'},
    });
    final lookups = EventCancellationLookups.instance..clear();

    final first = await lookups.of('7');
    final again = await lookups.of('7');

    expect(first, isNotNull);
    expect(again, isNotNull);
    expect(api.sent('GET', '/discover/events/7'), hasLength(1));
    expect(await lookups.of(''), isNull);
    expect(await lookups.of('0'), isNull);
  });
}
