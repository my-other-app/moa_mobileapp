import 'package:dio/dio.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/utils/registration_refusal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'events_fakes.dart';

/// What `APIService.request` throws for a refusal: the interceptor's
/// ApiException, unwrapped.
Future<Object> _thrownFor(int status, Object? body) async {
  final api = useFakeApi()..on('GET', '/x', body, status: status);
  try {
    await APIService.instance.request('/x', DioMethod.get);
  } catch (e) {
    return e;
  }
  fail('expected ${api.requests.length} request to fail');
}

void main() {
  group('readableError', () {
    test('the 403 the audit saw reads as words, not ApiException.toString',
        () async {
      final error = await _thrownFor(403, {
        'message': "Networking isn't available for this event.",
        'error_code': 'NETWORKING_UNAVAILABLE',
      });
      expect(error, isA<ApiException>());
      expect(error.toString(), startsWith('ApiException:'));

      expect(networkingErrorMessage(error),
          "This event doesn't have People Like You.");
      expect(errorCodeOf(error), 'NETWORKING_UNAVAILABLE');
    });

    test('NETWORKING_UNAVAILABLE gets its own copy whatever the server said',
        () async {
      final error = await _thrownFor(403, {
        'message': 'You do not have permission',
        'error_code': 'NETWORKING_UNAVAILABLE',
      });
      expect(networkingErrorMessage(error),
          "This event doesn't have People Like You.");
    });

    test("a refusal with words is shown in the server's words", () async {
      final error = await _thrownFor(
          400, {'message': 'Registration deadline has passed'});
      expect(readableError(error, fallback: 'x'),
          'Registration deadline has passed');
    });

    test("a 5xx's words are not shown", () async {
      final error = await _thrownFor(
          500, {'message': 'Failed to create order: KeyError'});
      final said = readableError(error, fallback: 'x');
      expect(said, isNot(contains('KeyError')));
      expect(said, isNot(contains('ApiException')));
    });

    test('a DioException carrying an ApiException is read the same way', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/x'),
        response: Response(
          requestOptions: RequestOptions(path: '/x'),
          statusCode: 409,
          data: {'message': 'Already', 'error_code': 'ALREADY_REGISTERED'},
        ),
        error: const ApiException(
          message: 'Already',
          statusCode: 409,
          serverMessage: 'Already',
          errorCode: 'ALREADY_REGISTERED',
        ),
      );
      expect(errorCodeOf(error), 'ALREADY_REGISTERED');
      expect(readableError(error, fallback: 'x'), 'Already');
    });

    test('anything else is the fallback, never its toString', () {
      expect(readableError(StateError('boom'), fallback: 'Try again.'),
          'Try again.');
      expect(
          readableError(const FormatException('bad'), fallback: 'Try again.'),
          'Try again.');
    });

    test('no connection says so', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
        error: const ApiException(
          message: 'No internet connection. Please check your network.',
          type: ApiExceptionType.network,
        ),
      );
      expect(readableError(error, fallback: 'x'), ApiException.networkMessage);
    });

    test('a dropped connection Dio threw directly reads the same', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/x'),
        type: DioExceptionType.connectionError,
      );
      expect(readableError(error, fallback: 'x'), ApiException.networkMessage);
    });
  });

  group('describeRegistrationError', () {
    Future<RegistrationRefusal> refusal(int status, Object? body) async =>
        describeRegistrationError(await _thrownFor(status, body));

    test('ALREADY_REGISTERED offers the ticket', () async {
      final r = await refusal(400, {
        'message': 'Already registered for this event',
        'error_code': 'ALREADY_REGISTERED',
      });
      expect(r.action, RegistrationAction.viewTicket);
      expect(r.actionLabel, 'View ticket');
    });

    test('REGISTRATION_AWAITING_PAYMENT offers the payment', () async {
      final r = await refusal(409, {
        'message':
            'This email already has a registration ... waiting for payment.',
        'error_code': 'REGISTRATION_AWAITING_PAYMENT',
      });
      expect(r.action, RegistrationAction.finishPayment);
      expect(r.actionLabel, 'Finish payment');
    });

    test('REGISTRATIONS_CLOSED has its own sentence', () async {
      final r = await refusal(409, {
        'message': 'whatever',
        'error_code': 'REGISTRATIONS_CLOSED',
      });
      expect(
          r.message, "This event isn't taking more registrations right now.");
      expect(r.action, isNull);
    });

    test('EVENT_FULL, and "Event is full" from a server without the code',
        () async {
      final coded = await refusal(
          400, {'message': 'Event is full', 'error_code': 'EVENT_FULL'});
      final uncoded = await refusal(400, {'message': 'Event is full'});
      expect(coded.title, 'This event is full');
      expect(uncoded.title, 'This event is full');
      expect(uncoded.action, isNull);
    });

    test("SOLD_OUT names what sold out, in the server's words", () async {
      final r = await refusal(422, {
        'message': 'Hack Night tee M is sold out',
        'error_code': 'SOLD_OUT',
      });
      expect(r.title, 'Sold out');
      expect(r.message,
          'Hack Night tee M is sold out. Change your picks and try again.');
    });

    test('CLUB_EMAIL explains the address belongs to a club', () async {
      final r =
          await refusal(400, {'message': 'x', 'error_code': 'CLUB_EMAIL'});
      expect(r.message, contains("club's account"));
    });

    test('anything else keeps what the server said', () async {
      final r = await refusal(400, {'message': 'Email does not match'});
      expect(r.message, 'Email does not match');
      expect(r.action, isNull);
      expect(r.closed, isFalse);
    });

    test('a closed registration is marked closed, coded or not', () async {
      final coded = await refusal(400, {
        'message': 'Registration deadline has passed',
        'error_code': 'REGISTRATIONS_CLOSED',
      });
      final uncoded =
          await refusal(400, {'message': 'Registration deadline has passed'});
      expect(coded.closed, isTrue);
      expect(uncoded.closed, isTrue);
      expect(uncoded.title, 'Registrations are closed');
      expect(uncoded.message, 'Registration deadline has passed.');
    });
  });
}
