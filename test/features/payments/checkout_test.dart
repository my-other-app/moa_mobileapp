import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/payments/checkout.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';

void main() {
  Future<Result<bool>> pay(FakePaymentRepository repository) =>
      RegistrationCheckout.pay(
        repository: repository,
        eventId: 7,
        registrationId: 'reg-1',
        name: 'Asha Menon',
        email: 'asha@example.com',
        phone: '9876543210',
      );

  test('ALREADY_PAID is a payment that went through, with nothing to open',
      () async {
    // Razorpay is never reached: constructing it here would need the plugin.
    final repository = FakePaymentRepository()
      ..order = Either.left(const AlreadyPaidFailure());

    final result = await pay(repository);

    expect(result.isRight, isTrue);
    expect(result.right, isTrue);
    expect(repository.orders, [(7, 'reg-1')]);
  });

  test('NOTHING_TO_PAY is a Left with its words', () async {
    final repository = FakePaymentRepository()
      ..order = Either.left(const NothingToPayFailure());

    final result = await pay(repository);

    expect(result.isLeft, isTrue);
    expect(result.left, isA<NothingToPayFailure>());
  });
}
