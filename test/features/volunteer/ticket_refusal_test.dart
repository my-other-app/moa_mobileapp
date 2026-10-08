import 'package:dio/dio.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/volunteer/data/ticket_refusal.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// A refusal shaped the way the real stack delivers one: the server's
/// `CustomHTTPException(status, message)` body, through `ErrorInterceptor`,
/// boxed in the `DioException` that `dio.post` throws.
DioException _refusal(int status, String serverMessage, {String? errorCode}) {
  final options = RequestOptions(path: '/events/volunteer/validate/7');
  final friendly = switch (status) {
    401 => 'Unauthorized. Please log in again.',
    403 => 'You do not have permission to access this resource.',
    404 => 'Resource not found.',
    >= 500 => 'Server error. Please try again later.',
    _ => serverMessage,
  };
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    error: ApiException(
      message: friendly,
      statusCode: status,
      type: switch (status) {
        400 => ApiExceptionType.badRequest,
        401 => ApiExceptionType.unauthorized,
        403 => ApiExceptionType.forbidden,
        404 => ApiExceptionType.notFound,
        _ => ApiExceptionType.server,
      },
      serverMessage: serverMessage,
      errorCode: errorCode,
    ),
  );
}

void main() {
  group('classifyRefusal, on the messages the server actually sends', () {
    // Every string below is copied from
    // app/api/events/volunteer/service.py.

    test('"Registration not found" is a missing ticket', () {
      final r = classifyRefusal(_refusal(400, 'Registration not found'));

      expect(r.type, CheckinResultType.notFound);
      expect(r.success, isFalse);
    });

    test('"User already checked-in" is a used ticket', () {
      final r = classifyRefusal(_refusal(400, 'User already checked-in'));

      expect(r.type, CheckinResultType.alreadyScanned);
    });

    test('the unpaid-fee refusal is classified as unpaid', () {
      final r = classifyRefusal(_refusal(
        400,
        'User has not paid the fee, Please verify the payment details.',
      ));

      expect(r.type, CheckinResultType.unpaid);
    });

    test('a wrong-event refusal names the event the ticket is really for', () {
      final r = classifyRefusal(_refusal(
        400,
        "Incorrect event: This ticket belongs to 'Hack Night 04'",
      ));

      expect(r.type, CheckinResultType.incorrectEvent);
      expect(r.actualEventName, 'Hack Night 04');
    });

    test('an event whose name contains "paid" is still a wrong-event refusal',
        () {
      // The event name is interpolated into the message, so classifying by
      // loose substring in the wrong order would read this as unpaid and
      // send the volunteer to the payments desk.
      final r = classifyRefusal(_refusal(
        400,
        "Incorrect event: This ticket belongs to 'Paid Members Night'",
      ));

      expect(r.type, CheckinResultType.incorrectEvent);
      expect(r.actualEventName, 'Paid Members Night');
    });

    test('an event whose name contains "already" is too', () {
      final r = classifyRefusal(_refusal(
        400,
        "Incorrect event: This ticket belongs to 'Already Gone Fest'",
      ));

      expect(r.type, CheckinResultType.incorrectEvent);
    });
  });

  group('refusals that are not about the ticket', () {
    test('a 401 says the volunteer lacks permission, not that the ticket is bad',
        () {
      // The endpoint answers 401 "User is not a volunteer for this event".
      // Reported as notFound -- as it was -- this tells a volunteer whose
      // access was revoked that the attendee's ticket is invalid, and the
      // argument happens with the wrong person.
      final r =
          classifyRefusal(_refusal(401, 'User is not a volunteer for this event'));

      expect(r.type, CheckinResultType.notPermitted);
      expect(r.message, 'User is not a volunteer for this event');
      // Not the interceptor's generic copy, which would be the wrong
      // instruction entirely.
      expect(r.message, isNot(contains('log in again')));
    });

    test('no network is unreachable, not a missing ticket', () {
      // Venue wifi drops mid-scan. The attendee holds a perfectly good
      // ticket; the only correct instruction is to scan it again.
      final r = classifyRefusal(DioException(
        requestOptions: RequestOptions(path: '/events/volunteer/validate/7'),
        type: DioExceptionType.connectionError,
        error: const ApiException(
          message: 'No internet connection. Please check your network.',
          type: ApiExceptionType.network,
        ),
      ));

      expect(r.type, CheckinResultType.unreachable);
    });

    test('a timeout is unreachable too', () {
      final r = classifyRefusal(const ApiException(
        message: 'Connection timed out.',
        type: ApiExceptionType.timeout,
      ));

      expect(r.type, CheckinResultType.unreachable);
    });

    test('a 500 is unreachable', () {
      final r = classifyRefusal(_refusal(500, 'Internal Server Error'));

      expect(r.type, CheckinResultType.unreachable);
    });

    test('a 404 is a missing ticket, not a server problem', () {
      // 404 maps to ServerFailure with code '404', which must not be
      // confused with a server that fell over.
      final r = classifyRefusal(_refusal(404, 'Resource not found.'));

      expect(r.type, CheckinResultType.notFound);
    });
  });

  group('error_code is preferred over the prose when the server sets one', () {
    test('a code wins even if the message reads like something else', () {
      final r = classifyRefusal(_refusal(
        400,
        'Registration not found',
        errorCode: 'TICKET_ALREADY_USED',
      ));

      expect(r.type, CheckinResultType.alreadyScanned);
    });

    test('an unrecognised code falls back to the prose', () {
      final r = classifyRefusal(_refusal(
        400,
        'User already checked-in',
        errorCode: 'SOMETHING_NEW',
      ));

      expect(r.type, CheckinResultType.alreadyScanned);
    });
  });

  group('classifyRefusalMessage', () {
    test('unrecognised wording passes the server words through', () {
      // Rather than the old fixed "Validation failed", which told whoever
      // was on the door nothing at all.
      final r = classifyRefusalMessage('Tickets are not valid before 18:00');

      expect(r.type, CheckinResultType.notFound);
      expect(r.message, 'Tickets are not valid before 18:00');
    });
  });
}
