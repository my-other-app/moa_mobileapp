import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/utils/error_utils.dart';

/// Where the signed-in person stands with an event.
enum RegistrationStatus {
  /// Not registered: the page offers to register.
  none,

  /// Registered for a paid event and not paid yet: no ticket until they pay.
  awaitingPayment,

  /// Registered, with a ticket.
  registered,

  /// Checked in at the event.
  attended,
}

/// The `status` a list hands the event page to open it straight into paying
/// for an unpaid registration -- what "Finish payment" on a ticket list
/// sends. The page then also knows the registration is unpaid when the
/// server is too old to say so itself.
const finishPaymentStatus = 'finishPayment';

/// Whether [event] -- an `/events/info/{id}` body, or an item of
/// `/events/list?is_registered=true` -- is a registration still waiting for
/// its payment.
///
/// `is_paid` is null when the viewer isn't registered, true for a free or
/// paid registration and false for an unpaid one on a paid event. The list
/// sends `is_paid: false` for a free registration too, so a free event never
/// counts as unpaid. A server that sends no `is_paid` leaves things as they
/// were: registered means a ticket.
bool isAwaitingPayment(Map<dynamic, dynamic> event) =>
    event['is_paid'] == false && event['has_fee'] == true;

/// Whether the organiser revoked [event]'s ticket -- the door refuses it.
///
/// `ticket_revoked` is true or false on an item of `/events/list` for a
/// registration, null when not registered. A revoked ticket stays in the
/// list. Missing or null (an older server) is not revoked.
bool isTicketRevoked(Map<dynamic, dynamic> event) =>
    event['ticket_revoked'] == true;

/// The `error_code` every path that hands out a ticket refuses a revoked one
/// with -- the door's own code, so one name means it everywhere.
const ticketRevokedCode = 'TICKET_REVOKED';

/// Whether [error] is the server refusing a ticket's document -- its picture,
/// its PDF or its Wallet pass -- because the organiser revoked it.
///
/// The server answers 410 Gone with `error_code: TICKET_REVOKED`, and only
/// after it has checked who is asking, so this is never a guess about
/// somebody else's ticket. Either mark alone is enough.
///
/// A 403 (not this person's ticket) and a 404 (no such ticket, or a server
/// that cannot render it) are different answers and are *not* revocations:
/// they leave the screen doing what it has always done, which is to fall
/// back to the card the app draws itself.
///
/// Documents are fetched as bytes ([DocumentCache]), so the error envelope
/// is never parsed into a map on the way through; the body is read here when
/// the status alone has not already settled it.
bool isRevokedTicketRefusal(Object? error) {
  if (statusCodeOf(error) == 410) return true;
  if (errorCodeOf(error) == ticketRevokedCode) return true;
  return _errorCodeInBody(error) == ticketRevokedCode;
}

/// The `error_code` of a refusal whose body arrived as bytes or as text.
String? _errorCodeInBody(Object? error) {
  final body = _responseOf(error)?.data;
  final text = switch (body) {
    String text => text,
    List<int> bytes => _utf8(bytes),
    _ => null,
  };
  if (text == null || text.isEmpty) return null;
  try {
    final decoded = jsonDecode(text);
    final code = decoded is Map ? decoded['error_code'] : null;
    return code is String && code.isNotEmpty ? code : null;
  } catch (_) {
    // Not JSON: a gateway's HTML page, say. It says nothing about a ticket.
    return null;
  }
}

String? _utf8(List<int> bytes) {
  try {
    return utf8.decode(bytes, allowMalformed: true);
  } catch (_) {
    return null;
  }
}

Response<dynamic>? _responseOf(Object? error) {
  if (error is DioException) return error.response;
  if (error is ApiException) {
    final inner = error.originalError;
    if (inner is DioException) return inner.response;
  }
  return null;
}

/// The status `/events/info/{id}` describes.
///
/// [carried] is the status the screen was opened with (from a card that
/// already knew it); the server's answer only ever adds to it, so a slow or
/// partial response doesn't take a ticket away.
RegistrationStatus registrationStatusFrom(
  Map<String, dynamic> info, {
  RegistrationStatus carried = RegistrationStatus.none,
}) {
  if (info['is_attended'] == true || carried == RegistrationStatus.attended) {
    return RegistrationStatus.attended;
  }
  final registered = info['is_registered'] == true ||
      carried == RegistrationStatus.registered ||
      carried == RegistrationStatus.awaitingPayment;
  if (!registered) return RegistrationStatus.none;
  // The server's word on payment wins over what the card carried: the card
  // can be from before the payment went through.
  if (info.containsKey('is_paid') && info['is_paid'] != null) {
    return isAwaitingPayment(info)
        ? RegistrationStatus.awaitingPayment
        : RegistrationStatus.registered;
  }
  return carried == RegistrationStatus.awaitingPayment
      ? RegistrationStatus.awaitingPayment
      : RegistrationStatus.registered;
}
