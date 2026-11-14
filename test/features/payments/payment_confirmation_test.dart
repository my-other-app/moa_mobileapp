import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:finnet/features/payments/data/models/payment_order_model.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/payments/payment_confirmation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../events/events_fakes.dart';

/// verify over the app's own data source and repository, against the fake
/// API: the server's answers, mapped as in the app.
class _NoSignalOnce implements PaymentRemoteDataSource {
  _NoSignalOnce(this._next);

  final PaymentRemoteDataSource _next;
  int failuresLeft = 1;

  @override
  Future<void> verifyPayment(
      {required String razorpayOrderId,
      required String razorpayPaymentId}) async {
    if (failuresLeft-- > 0) {
      throw DioException(
        requestOptions: RequestOptions(path: '/payments/verify'),
        type: DioExceptionType.connectionError,
      );
    }
    return _next.verifyPayment(
        razorpayOrderId: razorpayOrderId,
        razorpayPaymentId: razorpayPaymentId);
  }

  @override
  Future<PaymentOrderModel> createRegistrationOrder(
          {required int eventId, required String registrationId}) =>
      throw UnimplementedError();
}

void main() {
  late RouteAdapter api;
  late List<Duration> waited;
  late List<bool?> paidReads;

  setUp(() {
    api = useFakeApi();
    waited = [];
    paidReads = [];
  });

  PaymentConfirmation confirmation({
    PaymentRemoteDataSource? source,
    List<bool?> paidNow = const [],
  }) {
    final reads = [...paidNow];
    return PaymentConfirmation(
      repository: PaymentRepositoryImpl(
          remoteDataSource:
              source ?? PaymentRemoteDataSourceImpl(APIService.instance.dio)),
      isPaidNow: () async {
        final read = reads.isEmpty ? false : reads.removeAt(0);
        paidReads.add(read);
        return read;
      },
      wait: (d) async => waited.add(d),
    );
  }

  Future<CheckoutResult> confirm(PaymentConfirmation c) =>
      c.confirm(razorpayOrderId: 'order_1', paymentId: 'pay_1');

  void verifyAnswers(List<(int, Map<String, dynamic>)> answers) {
    for (final (status, body) in answers) {
      api.on('POST', '/payments/verify', body, status: status);
    }
  }

  const ok = (200, {'payment_status': 'captured', 'payment_amount': 250.0});
  const down = (502, <String, dynamic>{'message': 'Bad gateway'});
  const busy = (503, <String, dynamic>{'message': 'Unavailable'});
  const limited = (
    429,
    <String, dynamic>{
      'message': 'Too many payment checks in a short time.',
      'error_code': 'RATE_LIMITED',
      'errors': {'retry_after': 60},
    }
  );
  const notFound = (
    404,
    <String, dynamic>{
      'message': 'Payment not found',
      'error_code': 'PAYMENT_NOT_FOUND'
    }
  );

  test('verified at once: paid, asked once', () async {
    verifyAnswers([ok]);

    expect(await confirm(confirmation()), CheckoutResult.paid);
    expect(api.sent('POST', '/payments/verify'), hasLength(1));
    expect(waited, isEmpty);
  });

  test('a server down or busy, or over its limit (429 RATE_LIMITED), is asked '
      'again after 1 s, 3 s, 8 s', () async {
    verifyAnswers([down, limited, busy, ok]);

    expect(await confirm(confirmation()), CheckoutResult.paid);
    expect(api.sent('POST', '/payments/verify'), hasLength(4));
    expect(waited, const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 8),
    ]);
  });

  test('no signal is asked again too', () async {
    verifyAnswers([ok]);
    final c = confirmation(
        source: _NoSignalOnce(
            PaymentRemoteDataSourceImpl(APIService.instance.dio)));

    expect(await confirm(c), CheckoutResult.paid);
    expect(waited, const [Duration(seconds: 1)]);
  });

  test('Razorpay not having the payment yet (PAYMENT_NOT_FOUND) is asked '
      'again', () async {
    verifyAnswers([notFound, ok]);

    expect(await confirm(confirmation()), CheckoutResult.paid);
  });

  test('never verified: the registration is read; paid by the webhook '
      'meanwhile is paid', () async {
    verifyAnswers([busy]);

    final result = await confirm(confirmation(paidNow: [false, true]));

    expect(result, CheckoutResult.paid);
    expect(api.sent('POST', '/payments/verify'), hasLength(4));
    expect(paidReads, [false, true]);
  });

  test('never verified and never paid yet: confirming -- not "not completed"',
      () async {
    verifyAnswers([busy]);

    final result = await confirm(confirmation());

    expect(result, CheckoutResult.confirming);
    expect(waited, const [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 8),
      Duration.zero,
      Duration(seconds: 3),
      Duration(seconds: 7),
    ]);
    expect(paidReads, [false, false, false]);
  });

  test('409 REGISTRATION_REMOVED: removed, with the server\'s words, and not '
      'asked again', () async {
    verifyAnswers([
      (
        409,
        {
          'message': 'This registration was cancelled before the payment went '
              'through. The payment is being refunded in full.',
          'error_code': 'REGISTRATION_REMOVED',
          'errors': {'payment_status': 'captured'},
        }
      ),
    ]);
    final c = confirmation();

    expect(await confirm(c), CheckoutResult.removed);
    expect(c.removedMessage, contains('refunded in full'));
    expect(api.sent('POST', '/payments/verify'), hasLength(1));
    expect(paidReads, isEmpty);
  });

  test('a refusal that asking again won\'t change is not asked again; the '
      'registration is read', () async {
    verifyAnswers([
      (400, {'message': 'Signature mismatch', 'error_code': 'BAD_SIGNATURE'}),
    ]);

    final result = await confirm(confirmation());

    expect(api.sent('POST', '/payments/verify'), hasLength(1));
    expect(result, CheckoutResult.confirming);
    expect(paidReads, hasLength(3));
  });

  test('no payment id from Razorpay: nothing to verify, the registration is '
      'read', () async {
    final c = confirmation(paidNow: [true]);

    expect(await c.confirm(razorpayOrderId: 'order_1'), CheckoutResult.paid);
    expect(api.sent('POST', '/payments/verify'), isEmpty);
  });

  test('what is worth asking again', () {
    expect(PaymentConfirmation.worthAskingAgain(
        const NetworkFailure(message: 'x')), isTrue);
    expect(PaymentConfirmation.worthAskingAgain(
        const ServerFailure(message: 'x', code: '502')), isTrue);
    expect(PaymentConfirmation.worthAskingAgain(
        const UnknownFailure(message: 'x', code: 'RATE_LIMITED')), isTrue);
    expect(PaymentConfirmation.worthAskingAgain(
        const ServerFailure(message: 'x', code: '404')), isFalse);
    expect(PaymentConfirmation.worthAskingAgain(
        const ValidationFailure(message: 'x', code: 'BAD_SIGNATURE')), isFalse);
    expect(PaymentConfirmation.worthAskingAgain(
        const UnknownFailure(message: 'x', code: 'REGISTRATION_REMOVED')),
        isFalse);
  });

  group('registrationPaidNow', () {
    test('reads is_paid from the event, as the person', () async {
      api.on('GET', '/events/info/7',
          {'id': 7, 'is_registered': true, 'is_paid': true, 'has_fee': true});
      expect(await registrationPaidNow(7)(), isTrue);
    });

    test('not paid yet, not registered, or no answer', () async {
      api
        ..on('GET', '/events/info/7',
            {'id': 7, 'is_registered': true, 'is_paid': false})
        ..on('GET', '/events/info/7', {'id': 7, 'is_registered': false});
      expect(await registrationPaidNow(7)(), isFalse);
      expect(await registrationPaidNow(7)(), isNull);
      expect(await registrationPaidNow(8)(), isNull, reason: 'a 404');
    });
  });
}
