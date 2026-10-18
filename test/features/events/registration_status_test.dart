import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isAwaitingPayment', () {
    test('an unpaid registration on a paid event', () {
      expect(isAwaitingPayment({'is_paid': false, 'has_fee': true}), isTrue);
    });

    test('paid, free, not registered, or an older server: not awaiting', () {
      expect(isAwaitingPayment({'is_paid': true, 'has_fee': true}), isFalse);
      // The list sends is_paid: false for a free registration.
      expect(isAwaitingPayment({'is_paid': false, 'has_fee': false}), isFalse);
      expect(isAwaitingPayment({'is_paid': null, 'has_fee': true}), isFalse);
      expect(isAwaitingPayment({'has_fee': true}), isFalse);
    });
  });

  group('registrationStatusFrom', () {
    test('is_paid false on a registration: no ticket yet', () {
      expect(
        registrationStatusFrom(
            {'is_registered': true, 'is_paid': false, 'has_fee': true}),
        RegistrationStatus.awaitingPayment,
      );
    });

    test('is_paid true: the ticket', () {
      expect(
        registrationStatusFrom(
            {'is_registered': true, 'is_paid': true, 'has_fee': true}),
        RegistrationStatus.registered,
      );
    });

    test('no is_paid (an older server): registered is a ticket, as before', () {
      expect(
        registrationStatusFrom({'is_registered': true, 'has_fee': true}),
        RegistrationStatus.registered,
      );
    });

    test('not registered', () {
      expect(
        registrationStatusFrom(
            {'is_registered': false, 'is_paid': null, 'has_fee': true}),
        RegistrationStatus.none,
      );
    });

    test('attended wins', () {
      expect(
        registrationStatusFrom({
          'is_registered': true,
          'is_attended': true,
          'is_paid': false,
          'has_fee': true,
        }),
        RegistrationStatus.attended,
      );
    });

    test("the card's status is kept when the server says nothing new", () {
      expect(
        registrationStatusFrom({'is_registered': false},
            carried: RegistrationStatus.registered),
        RegistrationStatus.registered,
      );
      expect(
        registrationStatusFrom({'is_registered': true, 'has_fee': true},
            carried: RegistrationStatus.awaitingPayment),
        RegistrationStatus.awaitingPayment,
      );
    });

    test("the server's word on payment beats the card's", () {
      expect(
        registrationStatusFrom(
            {'is_registered': true, 'is_paid': true, 'has_fee': true},
            carried: RegistrationStatus.awaitingPayment),
        RegistrationStatus.registered,
      );
    });
  });
}
