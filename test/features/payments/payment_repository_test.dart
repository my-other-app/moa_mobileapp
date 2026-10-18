import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/interceptors/error_interceptor.dart';
import 'package:finnet/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:finnet/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:finnet/features/payments/domain/entities/payment_order.dart';
import 'package:finnet/features/payments/domain/payment_failures.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  Object? body = const <String, dynamic>{};
  int status = 200;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}

  RequestOptions get only => requests.single;
}

void main() {
  late _RecordingAdapter adapter;
  late PaymentRemoteDataSourceImpl dataSource;
  late PaymentRepositoryImpl repository;

  setUp(() {
    adapter = _RecordingAdapter();
    // The app's own error interceptor, so failures arrive shaped as they do
    // in production: a DioException carrying an ApiException.
    final dio = Dio(BaseOptions(baseUrl: 'https://example.test/api/v1'))
      ..httpClientAdapter = adapter
      ..interceptors.add(ErrorInterceptor());
    dataSource = PaymentRemoteDataSourceImpl(dio);
    repository = PaymentRepositoryImpl(remoteDataSource: dataSource);
  });

  group('making the order', () {
    test('POST /payments/orders?checkout=2 with the body it always had', () async {
      adapter.body = {
        'id': 'o-1',
        'razorpay_order_id': 'order_1',
        'amount': 250.0,
        'currency': 'INR',
        'status': 'created',
        'key_id': 'rzp_test_club_not_real',
        'gateway': 'club',
      };

      final result = await repository.createRegistrationOrder(eventId: 62, registrationId: 'reg-1');

      final req = adapter.only;
      expect(req.method, 'POST');
      expect(req.path, '/payments/orders');
      expect(req.queryParameters, {'checkout': 2});
      expect(req.uri.toString(), 'https://example.test/api/v1/payments/orders?checkout=2');
      expect(req.data, {
        'source': 'event_registration',
        'payload': {'event_id': 62, 'event_registration_id': 'reg-1'},
      });

      expect(result.isRight, isTrue);
      expect(result.right.keyId, 'rzp_test_club_not_real');
      expect(result.right.gateway, PaymentGateway.club);
      expect(result.right.razorpayOrderId, 'order_1');
    });

    test('409 UPDATE_APP_TO_PAY is a friendly failure with the website link', () async {
      adapter
        ..status = 409
        ..body = {
          'message': 'Update the MyOtherApp app to pay for this event, or pay on the website.',
          'error_code': 'UPDATE_APP_TO_PAY',
          'errors': {'web_url': 'https://myotherapp.in/events/quiet-evening'},
        };

      final result = await repository.createRegistrationOrder(eventId: 62, registrationId: 'reg-1');

      expect(result.isLeft, isTrue);
      final failure = result.left;
      expect(failure, isA<UpdateAppToPayFailure>());
      expect(failure.code, 'UPDATE_APP_TO_PAY');
      expect(failure.message, 'Update the MyOtherApp app to pay for this event, or pay on the website.');
      expect((failure as UpdateAppToPayFailure).webUrl, 'https://myotherapp.in/events/quiet-evening');
    });

    test('UPDATE_APP_TO_PAY without a link still says what to do', () async {
      adapter
        ..status = 409
        ..body = {'error_code': 'UPDATE_APP_TO_PAY', 'errors': {'web_url': null}};

      final failure = (await repository.createRegistrationOrder(eventId: 62, registrationId: 'reg-1')).left;

      expect(failure, isA<UpdateAppToPayFailure>());
      expect(failure.message, const UpdateAppToPayFailure().message);
      expect((failure as UpdateAppToPayFailure).webUrl, isNull);
    });

    test("any other refusal keeps its kind and the server's words", () async {
      adapter
        ..status = 503
        ..body = {
          'message': "This payment went to the club's own Razorpay account, and its keys can't be read right now.",
          'error_code': 'GATEWAY_UNAVAILABLE',
        };

      final failure = (await repository.createRegistrationOrder(eventId: 62, registrationId: 'reg-1')).left;

      expect(failure, isA<ServerFailure>());
      expect(failure, isNot(isA<UpdateAppToPayFailure>()));
      expect(failure.message, contains("club's own Razorpay account"));
    });

    test('409 ALREADY_PAID is an AlreadyPaidFailure, to be treated as paid', () async {
      adapter
        ..status = 409
        ..body = {'message': 'This registration is already paid for.', 'error_code': 'ALREADY_PAID'};

      final failure = (await repository.createRegistrationOrder(eventId: 62, registrationId: 'reg-1')).left;

      expect(failure, isA<AlreadyPaidFailure>());
      expect(failure.code, 'ALREADY_PAID');
    });

    test('422 NOTHING_TO_PAY is a NothingToPayFailure with the server words', () async {
      adapter
        ..status = 422
        ..body = {'message': 'There is nothing to pay for this registration.', 'error_code': 'NOTHING_TO_PAY'};

      final failure = (await repository.createRegistrationOrder(eventId: 62, registrationId: 'reg-1')).left;

      expect(failure, isA<NothingToPayFailure>());
      expect(failure.message, 'There is nothing to pay for this registration.');
    });

    test('an order with no razorpay_order_id is a ServerFailure, not a crash', () async {
      adapter.body = {'id': 'o-1', 'amount': 250.0};
      final failure = (await repository.createRegistrationOrder(eventId: 62, registrationId: 'reg-1')).left;
      expect(failure, isA<ServerFailure>());
    });
  });

  group('verifying', () {
    test('POST /payments/verify without the user token, as before', () async {
      adapter.body = {'payment_status': 'captured', 'payment_amount': 250.0};

      final result = await repository.verifyPayment(razorpayOrderId: 'order_1', razorpayPaymentId: 'pay_1');

      expect(result.isRight, isTrue);
      final req = adapter.only;
      expect(req.method, 'POST');
      expect(req.path, '/payments/verify');
      expect(req.queryParameters, isEmpty);
      expect(req.extra['skipAuth'], isTrue);
      expect(req.data, {'razorpay_order_id': 'order_1', 'razorpay_payment_id': 'pay_1'});
    });

    test('a refused verification is a Left', () async {
      adapter
        ..status = 400
        ..body = {'message': 'Payment verification failed'};
      final result = await repository.verifyPayment(razorpayOrderId: 'order_1', razorpayPaymentId: 'pay_1');
      expect(result.isLeft, isTrue);
      expect(result.left.message, 'Payment verification failed');
    });
  });
}
