import 'package:dio/dio.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/volunteer/data/ticket_code.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';

/// Work out why a scan was refused.
///
/// [ApiException.errorCode] first (`app/api/events/volunteer/service.py`
/// sets one on every refusal now), then the message, for a server from
/// before the codes.
///
/// [entered] is the code that was scanned or typed. When it names no ticket,
/// the message says what to do -- and, for an admission number, that only
/// the ticket code checks anyone in ([noTicketMessage]).
///
/// This used to live twice in the provider -- once in `validateTicket`, once
/// in `checkinParticipant` -- plus a third partial copy in each method's
/// generic `catch`. The copies disagreed: one of them never checked for an
/// unpaid fee at all.
CheckinResult classifyRefusal(Object error, {String? entered}) {
  final failure = mapErrorToFailure(error);

  // Anything that never reached the endpoint. Must not be reported as a bad
  // ticket: the attendee is standing there with a valid one.
  if (failure is NetworkFailure) {
    return CheckinResult.refused(
      type: CheckinResultType.unreachable,
      message: 'Could not reach the server. Check the connection and scan '
          'again.',
    );
  }
  if (failure is ServerFailure && failure.code != '404') {
    return CheckinResult.refused(
      type: CheckinResultType.unreachable,
      message: 'The server had a problem. Scan again in a moment.',
    );
  }

  final api = _apiException(error);

  // 401 from these endpoints means one thing: not a volunteer here. The
  // generic copy in `message` ("please log in again") is the wrong
  // instruction, so read what the server actually said.
  if (api?.type == ApiExceptionType.unauthorized ||
      api?.type == ApiExceptionType.forbidden) {
    return CheckinResult.refused(
      type: CheckinResultType.notPermitted,
      message: api?.serverMessage ?? 'You are not a volunteer for this event.',
    );
  }

  if (entered != null &&
      entered.trim().isNotEmpty &&
      _namesNoTicket(api, failure)) {
    return CheckinResult.refused(
      type: CheckinResultType.notFound,
      message: noTicketMessage(entered),
    );
  }

  final code = api?.errorCode;
  if (code != null) {
    final byCode = _byErrorCode(code);
    if (byCode != null) {
      return CheckinResult.refused(
        type: byCode,
        message: api?.serverMessage ?? failure.message,
      );
    }
  }

  // Fall back to the prose. `serverMessage` rather than `message` because the
  // two differ for every status the interceptor rewrites.
  return classifyRefusalMessage(api?.serverMessage ?? failure.message);
}

/// Classify a refusal from the server's own wording.
///
/// Exposed separately because a non-200 response body reaches the data source
/// as data rather than as a thrown error.
CheckinResult classifyRefusalMessage(String message) {
  final lower = message.toLowerCase();

  // Checked first, and by prefix: the event's own name is interpolated into
  // this message, so an event called "Paid Members Night" would otherwise be
  // classified by its title rather than by the refusal.
  if (message.startsWith('Incorrect event:') ||
      lower.contains('incorrect event') ||
      lower.contains('belongs to')) {
    return CheckinResult.refused(
      type: CheckinResultType.incorrectEvent,
      message: message,
      actualEventName: _quotedName(message),
    );
  }

  if (lower.contains('already')) {
    return CheckinResult.refused(
      type: CheckinResultType.alreadyScanned,
      message: message,
    );
  }

  if (lower.contains('not paid') ||
      lower.contains('payment') ||
      lower.contains('fee')) {
    return CheckinResult.refused(
      type: CheckinResultType.unpaid,
      message: message,
    );
  }

  if (lower.contains('not a volunteer')) {
    return CheckinResult.refused(
      type: CheckinResultType.notPermitted,
      message: message,
    );
  }

  if (lower.contains('not found') || lower.contains('registration')) {
    return CheckinResult.refused(
      type: CheckinResultType.notFound,
      message: message,
    );
  }

  // Unrecognised wording. `notFound` is the honest answer -- the scan did not
  // produce a ticket -- but the server's own words go through so whoever is
  // on the door can read them, rather than the old fixed "Validation failed".
  return CheckinResult.refused(
    type: CheckinResultType.notFound,
    message: message,
  );
}

CheckinResultType? _byErrorCode(String code) {
  switch (code.toUpperCase()) {
    case 'TICKET_WRONG_EVENT':
    case 'INCORRECT_EVENT':
      return CheckinResultType.incorrectEvent;
    case 'TICKET_ALREADY_USED':
    case 'ALREADY_CHECKED_IN':
      return CheckinResultType.alreadyScanned;
    case 'FEE_UNPAID':
    case 'NOT_PAID':
      return CheckinResultType.unpaid;
    case 'REGISTRATION_NOT_FOUND':
    case 'TICKET_NOT_FOUND':
      return CheckinResultType.notFound;
    case 'NOT_A_VOLUNTEER':
      return CheckinResultType.notPermitted;
  }
  return null;
}

/// The refusal says the code names no registration: REGISTRATION_NOT_FOUND,
/// or, from a server without codes, "Registration not found". Not any 404:
/// EVENT_NOT_FOUND is about the event.
bool _namesNoTicket(ApiException? api, Failure failure) {
  final code = api?.errorCode?.toUpperCase();
  if (code != null) {
    return code == 'REGISTRATION_NOT_FOUND' || code == 'TICKET_NOT_FOUND';
  }
  final said = (api?.serverMessage ?? failure.message).toLowerCase();
  return said.contains('registration not found') ||
      said.contains('ticket not found');
}

/// Pull the event name out of "...belongs to 'Hack Night 04'".
String? _quotedName(String message) {
  final match = RegExp(r"'([^']+)'").firstMatch(message);
  return match?.group(1);
}

/// The [ApiException] behind an error, whichever shape it arrives in.
///
/// `APIService.request` rethrows it bare; a raw `dio.post` throws a
/// [DioException] with it in `.error`.
ApiException? _apiException(Object error) {
  if (error is ApiException) return error;
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException) return inner;
  }
  return null;
}
