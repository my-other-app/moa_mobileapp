import 'package:intl/intl.dart';

import 'package:finnet/core/utils/json_read.dart';

// "Review registrations": a club that turns it on for an event reviews
// every registration, and confirms or declines each one (feature-register
// `approvals-contract.md`; the words people see are
// `review-wording-contract.md`'s). The API still calls each one a request,
// and so does the code; people only ever see "registration". Read without
// trusting any field to be there, as the ticketing models are: a server
// without the feature sends none of it, and every screen does what it did
// before.

/// Where a request stands (`status`).
enum RequestStatus {
  /// Registered; the club hasn't decided. "Under review".
  pending,

  /// Confirmed: registered (a free ticket, or paid), or a ticket held while
  /// it is paid for ([RegistrationRequest.pay]). "Confirmed".
  approved,

  /// The club didn't confirm it. Registering again is refused. "Not
  /// confirmed".
  declined,

  /// The person cancelled it. They may register again. "Cancelled".
  withdrawn,

  /// Confirmed for a paid ticket, and the payment didn't arrive in time.
  /// "Expired".
  lapsed,

  /// Closed without a decision: the event ended, was deleted or cancelled,
  /// or the person got a ticket another way
  /// ([RegistrationRequest.closedReason]). "Closed".
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

  /// The claim link on the website (`claim_url`), when sent. The app opens
  /// its own claim screen by [claimToken].
  final String? claimUrl;

  const RequestPay({
    required this.amount,
    this.payBy,
    required this.claimToken,
    this.claimUrl,
  });

  static RequestPay? fromJson(Object? value) {
    final json = jsonObject(value);
    final token = _text(json?['claim_token']);
    if (json == null || token == null) return null;
    return RequestPay(
      amount: (jsonDouble(json['amount']) ?? 0).clamp(0, double.infinity),
      payBy: jsonDate(json['pay_by']),
      claimToken: token,
      claimUrl: _text(json['claim_url']),
    );
  }
}

/// A registration at an event whose club reviews every registration (the
/// API's "request"): `GET /registration-requests/{token}`, a row of
/// `.../mine`, or -- with only its id, status, time and token -- the
/// `approval` a registration answers with.
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

  /// Why a [RequestStatus.closed] request closed (`closed_reason`): one of
  /// [RequestClosedReasons], or null when not said.
  final String? closedReason;

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
    this.closedReason,
    this.ticketId,
    this.pay,
  });

  bool get isPending => status == RequestStatus.pending;

  /// Confirmed and registered: the ticket is theirs.
  bool get hasTicket => status == RequestStatus.approved && ticketId != null;

  /// Confirmed for a paid ticket, waiting for the payment.
  bool get awaitingPayment =>
      status == RequestStatus.approved && ticketId == null && pay != null;

  /// Still going somewhere: under review, or waiting for the payment. What
  /// My events lists under "Under review".
  bool get isOpen => isPending || awaitingPayment;

  /// The club's name, or "The club" when the server didn't say: for the
  /// start of a sentence.
  String get clubName => event?.clubName ?? 'The club';

  /// The club's name, or "the club": for the middle of a sentence.
  String get clubMidSentence => event?.clubName ?? 'the club';

  /// The event's name, or "the event".
  String get eventName {
    final name = event?.name ?? '';
    return name.isEmpty ? 'the event' : name;
  }

  /// The first word of [fullName], or null without one.
  String? get firstName {
    final first = fullName?.trim().split(RegExp(r'\s+')).first ?? '';
    return first.isEmpty ? null : first;
  }

  /// The person got a ticket another way, so the request closed
  /// (`closed_reason: "registered_directly"`).
  bool get registeredDirectly =>
      status == RequestStatus.closed &&
      closedReason == RequestClosedReasons.registeredDirectly;

  /// Where it stands, in the attendee's words (feature-register
  /// `review-wording-contract.md` §0): "Under review", "Confirmed",
  /// "Confirmed · pay by Sat 1 Nov, 6:00 PM to get your ticket", "Not
  /// confirmed", "Cancelled", "Expired" or "Closed". Null for a status this
  /// build doesn't know.
  String? get statusWord => switch (status) {
        RequestStatus.pending => 'Under review',
        RequestStatus.approved when awaitingPayment => switch (pay?.payBy) {
            final by? => 'Confirmed · pay by ${requestMoment(by)} to get '
                'your ticket',
            null => 'Confirmed · pay to get your ticket',
          },
        RequestStatus.approved => 'Confirmed',
        RequestStatus.declined => 'Not confirmed',
        RequestStatus.withdrawn => 'Cancelled',
        RequestStatus.lapsed => 'Expired',
        RequestStatus.closed => 'Closed',
        RequestStatus.unknown => null,
      };

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
        closedReason: fresh.closedReason,
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
      closedReason: _text(json['closed_reason'])?.toLowerCase(),
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

/// Why a request closed (`closed_reason`, on a [RequestStatus.closed] one).
abstract final class RequestClosedReasons {
  /// The event ended while the registration was still under review.
  static const eventEnded = 'event_ended';

  /// The event was deleted while the registration was still under review.
  static const eventDeleted = 'event_deleted';

  /// The event was cancelled.
  static const eventCancelled = 'event_cancelled';

  /// The person got a ticket another way.
  static const registeredDirectly = 'registered_directly';
}

/// The `error_code`s registering refuses with on an event whose club
/// reviews every registration.
abstract final class ApprovalErrorCodes {
  /// The event reviews every registration and the client didn't say it can
  /// take one under review (`accepts_approval`). An older app lands here.
  static const approvalRequired = 'APPROVAL_REQUIRED';

  /// The club declined this person's registration before; they can't
  /// register again unless the club reopens it.
  static const requestDeclined = 'REQUEST_DECLINED';

  /// Add-ons (`store` picks) sent with a request (422): a request holds
  /// none. Only when the club turned the setting on after the form loaded
  /// its shelf.
  static const addOnsNotAllowed = 'ADD_ONS_NOT_ALLOWED';

  /// Cancelling (withdrawing) a request that has moved on (decided, paid,
  /// closed): 409, with the request as it stands in `errors.request`.
  static const requestNotWithdrawable = 'REQUEST_NOT_WITHDRAWABLE';
}
