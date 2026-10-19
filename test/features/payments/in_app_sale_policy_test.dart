import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/payments/checkout.dart';
import 'package:finnet/features/payments/domain/in_app_sale_policy.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';

void main() {
  group('canSellInApp', () {
    test('an iPhone does not sell a paid online event', () {
      expect(
          canSellInApp(
              hasFee: true, isOnline: true, platform: TargetPlatform.iOS),
          isFalse);
    });

    test('an iPhone sells in-person and free events as before', () {
      expect(
          canSellInApp(
              hasFee: true, isOnline: false, platform: TargetPlatform.iOS),
          isTrue);
      expect(
          canSellInApp(
              hasFee: false, isOnline: true, platform: TargetPlatform.iOS),
          isTrue);
    });

    test('Android sells everything', () {
      for (final (hasFee, isOnline) in [
        (true, true),
        (true, false),
        (false, true),
      ]) {
        expect(
            canSellInApp(
                hasFee: hasFee,
                isOnline: isOnline,
                platform: TargetPlatform.android),
            isTrue);
      }
    });

    test('reads the running platform by default', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(canSellInApp(hasFee: true, isOnline: true), isFalse);
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(canSellInApp(hasFee: true, isOnline: true), isTrue);
    });
  });

  test('a checkout for an event not sold here makes no order', () async {
    final payments = FakePaymentRepository();
    final result = await RegistrationCheckout.pay(
      repository: payments,
      eventId: 7,
      registrationId: 'reg-1',
      name: 'Asha',
      email: 'asha@example.com',
      phone: '9876543210',
      sellable: false,
    );

    expect(result.isLeft, isTrue);
    expect(result.left, isA<InAppSaleBlockedFailure>());
    expect(result.left.message, iosOnlineSaleBlockedMessage);
    expect(payments.orders, isEmpty);
  });

  group('paymentFailureMessage', () {
    String said(String code, [String message = 'x']) =>
        paymentFailureMessage(ServerFailure(message: message, code: code));

    test('says the server refusals in plain words', () {
      expect(said('EVENT_FULL'), contains('full'));
      expect(said('EVENT_ENDED'), contains('over'));
      expect(said('GATEWAY_UNAVAILABLE', 'Unavailable'), contains('paused'));
      expect(said('REGISTRATION_NOT_FOUND'), contains('Register again'));
      expect(said('SOLD_OUT', 'Hack Night tee M is sold out'),
          'Hack Night tee M is sold out. Change your picks and try again.');
      expect(said('SOLD_OUT', 'Oops'), startsWith('Something you picked'));
      expect(paymentFailureMessage(const AlreadyPaidFailure()),
          const AlreadyPaidFailure().message);
    });

    test('anything else as it came', () {
      expect(
          paymentFailureMessage(
              const NetworkFailure(message: 'No connection.')),
          'No connection.');
    });
  });
}
