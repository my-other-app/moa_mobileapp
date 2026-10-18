import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/events/presentation/finish_payment.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:flutter_test/flutter_test.dart';

AdditionalDetail _question({bool required = true}) => AdditionalDetail(
      key: 'college',
      label: 'College',
      fieldType: 'text',
      requiredField: required,
      options: const [],
    );

class _Calls {
  final List<(int, Map<String, dynamic>)> registered = [];
  final List<String> paidFor = [];
}

FinishPayment _flow(
  _Calls calls, {
  Map<String, dynamic>? registration,
  Object? refusal,
  Result<bool>? paid,
}) {
  return FinishPayment(
    register: (eventId, body) async {
      calls.registered.add((eventId, body));
      if (refusal != null) throw refusal;
      return registration ??
          {
            'event_registration_id': 'reg-1',
            'pay_amount': 250.0,
            'full_name': 'Asha Menon',
            'email': 'asha@example.com',
            'phone': '9876543210',
          };
    },
    pay: ({
      required int eventId,
      required String registrationId,
      required String name,
      required String email,
      required String phone,
    }) async {
      calls.paidFor.add(registrationId);
      return paid ?? Either.right(true);
    },
  );
}

Future<FinishPaymentOutcome> _run(FinishPayment flow,
        {List<AdditionalDetail> questions = const []}) =>
    flow.run(
      eventId: 7,
      questions: questions,
      name: 'Asha Menon',
      email: 'asha@example.com',
      phone: '9876543210',
    );

void main() {
  test('registers again with the same details, then pays that registration',
      () async {
    final calls = _Calls();
    final outcome = await _run(_flow(calls));

    expect(outcome.result, FinishPaymentResult.paid);
    expect(calls.registered.single.$1, 7);
    expect(calls.registered.single.$2, {
      'full_name': 'Asha Menon',
      'email': 'asha@example.com',
      'phone': '9876543210',
      'additional_details': <String, String>{},
    });
    // No `store`: the shelf picks already on the registration are kept.
    expect(calls.registered.single.$2.containsKey('store'), isFalse);
    expect(calls.paidFor, ['reg-1']);
  });

  test('a closed checkout is not completed', () async {
    final calls = _Calls();
    final outcome = await _run(_flow(calls, paid: Either.right(false)));
    expect(outcome.result, FinishPaymentResult.notCompleted);
  });

  test('409 ALREADY_PAID on the order is a payment that went through',
      () async {
    final calls = _Calls();
    final outcome =
        await _run(_flow(calls, paid: Either.left(const AlreadyPaidFailure())));
    expect(outcome.result, FinishPaymentResult.paid);
  });

  test('NOTHING_TO_PAY and UPDATE_APP_TO_PAY are failures with their words',
      () async {
    final nothing = await _run(
        _flow(_Calls(), paid: Either.left(const NothingToPayFailure())));
    expect(nothing.result, FinishPaymentResult.failed);
    expect(nothing.failure, isA<NothingToPayFailure>());

    final update = await _run(_flow(_Calls(),
        paid: Either.left(const UpdateAppToPayFailure(webUrl: 'https://x'))));
    expect(update.failure, isA<UpdateAppToPayFailure>());
  });

  test('nothing owed after all: paid, without opening checkout', () async {
    final calls = _Calls();
    final outcome = await _run(_flow(calls, registration: {
      'event_registration_id': 'reg-1',
      'pay_amount': 0,
    }));
    expect(outcome.result, FinishPaymentResult.paid);
    expect(calls.paidFor, isEmpty);
  });

  test('ALREADY_REGISTERED from registering again means it is paid', () async {
    final calls = _Calls();
    final outcome = await _run(_flow(calls,
        refusal: const ApiException(
          message: 'Already registered for this event',
          statusCode: 400,
          serverMessage: 'Already registered for this event',
          errorCode: 'ALREADY_REGISTERED',
        )));
    expect(outcome.result, FinishPaymentResult.paid);
    expect(calls.paidFor, isEmpty);
  });

  test('a full event is a refusal with its own copy', () async {
    final outcome = await _run(_flow(_Calls(),
        refusal: const ApiException(
          message: 'Event is full',
          statusCode: 400,
          serverMessage: 'Event is full',
        )));
    expect(outcome.result, FinishPaymentResult.refused);
    expect(outcome.refusal!.title, 'This event is full');
  });

  test('an event with required questions goes back through the form', () async {
    final calls = _Calls();
    final outcome = await _run(_flow(calls), questions: [_question()]);
    expect(outcome.result, FinishPaymentResult.needsForm);
    expect(calls.registered, isEmpty);

    // Optional questions alone don't need the form.
    final optional =
        await _run(_flow(_Calls()), questions: [_question(required: false)]);
    expect(optional.result, FinishPaymentResult.paid);
  });

  test('a profile without a name goes through the form', () async {
    final calls = _Calls();
    final outcome = await _flow(calls).run(
      eventId: 7,
      questions: const [],
      name: '',
      email: 'asha@example.com',
    );
    expect(outcome.result, FinishPaymentResult.needsForm);
    expect(calls.registered, isEmpty);
  });

  test('a registration without its id is a failure, not a crash', () async {
    final outcome =
        await _run(_flow(_Calls(), registration: {'pay_amount': 250}));
    expect(outcome.result, FinishPaymentResult.failed);
    expect(outcome.failure, isA<ServerFailure>());
  });
}
