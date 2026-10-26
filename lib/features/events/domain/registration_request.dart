import 'package:intl/intl.dart';

import 'package:finnet/core/utils/json_read.dart';

// "Confirm each registration": a club that turns it on for an event takes
// requests instead of registrations, and confirms or declines each one
// (feature-register `approvals-contract.md`). Read without trusting any
// field to be there, as the ticketing models are: a server without the
// feature sends none of it, and every screen does what it did before.

/// Where a request stands (`status`).
enum RequestStatus {
  /// Sent; the club hasn't decided.
  pending,

  /// Confirmed: registered (a free ticket, or paid), or a place held while
  /// it is paid for ([RegistrationRequest.pay]).
  approved,

  /// The club couldn't offer a place. Asking again is refused.
  declined,

  /// The person took the request back. They may ask again.
  withdrawn,

  /// Confirmed for a paid ticket, and the payment didn't arrive in time.
  lapsed,

  /// The event was cancelled, or is over.
  closed,

  /// A word this build doesn't know.
  unknown,
}

RequestStatus requestStatusFrom(Object? value) =>
    switch (jsonString(value)?.trim().toLowerCase()) {
      'pending' => RequestStatus.pending,
      'approved' => RequestStatus.approved,
      'declined' => RequestStatus.declined,
      'withdrawn' => RequestStatus.withdrawn,
      'lapsed' => RequestStatus.lapsed,
      'closed' => RequestStatus.closed,
      _ => RequestStatus.unknown,
    };

String? _text(Object? value) {
  final s = jsonString(value)?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// The event a request is for (`event`).
class RequestEvent {
  final int id;
  final String slug;
  final String name;
  final DateTime? eventDateTime;
  final String? clubName;
  final String? clubSlug;

  const RequestEvent({
    required this.id,
    this.slug = '',
    this.name = '',
    this.eventDateTime,
    this.clubName,
    this.clubSlug,
  });

  /// The app's route to the event.
  String get route =>
      '/events/${slug.isNotEmpty ? Uri.encodeComponent(slug) : id}';

  static RequestEvent? fromJson(Object? value) {
    final json = jsonObject(value);
    final id = jsonInt(json?['id']);
    if (json == null || id == null) return null;
    final club = jsonObject(json['club']);
    return RequestEvent(
      id: id,
      slug: _text(json['slug']) ?? '',
      name: _text(json['name']) ?? '',
      eventDateTime: jsonDate(json['event_datetime']),
      clubName: _text(club?['name']) ?? _text(json['club_name']),
      clubSlug: _text(club?['slug']),
    );
  }
}

/// A confirmed request for a paid ticket, still inside its hold (`pay`):
/// what to pay, by when, and the claim link's token that pays it.
class RequestPay {
  final double amount;
  final DateTime? payBy;
  final String claimToken;

  const RequestPay({
    required this.amount,
    this.payBy,
    required this.claimToken,
  });

  static RequestPay? fromJson(Object? value) {
    final json = jsonObject(value);
    final token = _text(json?['claim_token']);
    if (json == null || token == null) return null;
    return RequestPay(
      amount: (jsonDouble(json['amount']) ?? 0).clamp(0, double.infinity),
      payBy: jsonDate(json['pay_by']),
      claimToken: token,
    );
  }
}

/// A request for a place at an event that confirms each registration:
/// `GET /registration-requests/{token}`, a row of `.../mine`, or -- with
/// only its id, status, time and token -- the `approval` a registration
/// answers with.
class RegistrationRequest {
  final String id;
  final RequestStatus status;

  /// The status link's secret: what `/requests/{token}` opens. From the
  /// body's `token`, else its `status_url`; null when the server sent
  /// neither (the screen that read it by token knows it already).
  final String? token;
  final String? statusUrl;
  final RequestEvent? event;
  final int? ticketTypeId;
  final String? ticketTypeName;
  final String? fullName;
  final DateTime? submittedAt;
  final DateTime? decidedAt;

  /// The club's short note when it declined, if it wrote one.
  final String? declineNote;

  /// Set once registered: the free ticket at confirmation, or the paid one
  /// once paid.
  final String? ticketId;

  /// Confirmed for a paid ticket and not paid yet, inside the hold.
  final RequestPay? pay;

  const RegistrationRequest({
    required this.id,
    required this.status,
    this.token,
    this.statusUrl,
    this.event,
    this.ticketTypeId,
    this.ticketTypeName,
    this.fullName,
    this.submittedAt,
    this.decidedAt,
    this.declineNote,
    this.ticketId,
    this.pay,
  });

  bool get isPending => status == RequestStatus.pending;

  /// Confirmed and registered: the ticket is theirs.
  bool get hasTicket => status == RequestStatus.approved && ticketId != null;

  /// Confirmed for a paid ticket, waiting for the payment.
  bool get awaitingPayment =>
      status == RequestStatus.approved && ticketId == null && pay != null;

  /// Still going somewhere: waiting for the club, or for the payment. What
  /// My events lists under "Waiting for confirmation".
  bool get isOpen => isPending || awaitingPayment;

  /// The club's name, or "The club" when the server didn't say.
  String get clubName => event?.clubName ?? 'The club';

  /// The event's name, or "the event".
  String get eventName {
    final name = event?.name ?? '';
    return name.isEmpty ? 'the event' : name;
  }

  /// The status screen, when the token is known.
  String? get route {
    final known = token;
    return known == null ? null : requestRoute(known);
  }

  /// This request read again with what [fresh] says, keeping the token and
  /// event this copy knew when [fresh] leaves them out.
  RegistrationRequest mergedWith(RegistrationRequest fresh) =>
      RegistrationRequest(
        id: fresh.id.isNotEmpty ? fresh.id : id,
        status: fresh.status,
        token: fresh.token ?? token,
        statusUrl: fresh.statusUrl ?? statusUrl,
        event: fresh.event ?? event,
        ticketTypeId: fresh.ticketTypeId ?? ticketTypeId,
        ticketTypeName: fresh.ticketTypeName ?? ticketTypeName,
        fullName: fresh.fullName ?? fullName,
        submittedAt: fresh.submittedAt ?? submittedAt,
        decidedAt: fresh.decidedAt,
        declineNote: fresh.declineNote,
        ticketId: fresh.ticketId,
        pay: fresh.pay,
      );

  /// The request, or null when [value] is not one: no object, or neither
  /// an id nor a token to know it by.
  static RegistrationRequest? fromJson(Object? value, {String? token}) {
    final json = jsonObject(value);
    if (json == null) return null;
    final id = _text(json['id']);
    final statusUrl = _text(json['status_url']);
    final known = _text(json['token']) ?? requestTokenFrom(statusUrl) ?? token;
    if (id == null && known == null) return null;
    final type = jsonObject(json['ticket_type']);
    return RegistrationRequest(
      id: id ?? '',
      status: requestStatusFrom(json['status']),
      token: known,
      statusUrl: statusUrl,
      event: RequestEvent.fromJson(json['event']),
      ticketTypeId: jsonInt(type?['id']),
      ticketTypeName: _text(type?['name']) ?? _text(json['ticket_type_name']),
      fullName: _text(json['full_name']),
      submittedAt: jsonDate(json['submitted_at']),
      decidedAt: jsonDate(json['decided_at']),
      declineNote: _text(json['decline_note']),
      ticketId: _text(json['ticket_id']),
      pay: RequestPay.fromJson(json['pay']),
    );
  }

  /// The rows of `GET /registration-requests/mine` (`{items: [...]}`, or a
  /// bare list), skipping any that can't be read.
  static List<RegistrationRequest> listFromJson(Object? value) {
    final items = jsonObject(value)?['items'] ?? value;
    return [
      for (final item in jsonObjects(items))
        if (fromJson(item) case final request?) request,
    ];
  }
}

/// The request link's token from the website's address
/// (`https://myotherapp.in/requests/{token}`), or the text itself when it
/// has no `/requests/` in it. Null for nothing.
String? requestTokenFrom(String? link) {
  final text = link?.trim() ?? '';
  if (text.isEmpty) return null;
  final marker = text.lastIndexOf('/requests/');
  if (marker < 0 && text.contains('/')) return null;
  var token = marker < 0 ? text : text.substring(marker + '/requests/'.length);
  token = token.split(RegExp('[?#/]')).first.trim();
  if (token.isEmpty) return null;
  try {
    return Uri.decodeComponent(token);
  } on ArgumentError {
    return token;
  }
}

/// The app's route to a request's status screen.
String requestRoute(String token) => '/requests/${Uri.encodeComponent(token)}';

/// "Sat 1 Nov, 6:00 PM".
String requestMoment(DateTime at) =>
    DateFormat('EEE d MMM, h:mm a').format(at.toLocal());

/// The `error_code`s registering refuses with on an event that confirms
/// each registration.
abstract final class ApprovalErrorCodes {
  /// The event confirms each place and the client didn't say it can take a
  /// request (`accepts_approval`). An older app lands here.
  static const approvalRequired = 'APPROVAL_REQUIRED';

  /// The club declined this person's request before; they can't ask again
  /// unless the club reopens it.
  static const requestDeclined = 'REQUEST_DECLINED';

  /// Withdrawing a request that has moved on (decided, paid, closed): 409,
  /// with the request as it stands in `errors.request`.
  static const requestNotWithdrawable = 'REQUEST_NOT_WITHDRAWABLE';
}
