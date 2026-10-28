import 'package:intl/intl.dart';

import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/registration_request.dart';

// Ticket types, discount codes, waiting lists and cancelled events, as the
// server describes them (moa_backend `docs/TICKETING.md`, and the club tools'
// cancel: `app/api/club_ops/cancel.py`). Read without trusting any field to
// be there: a server older than these features sends none of it, and then
// every screen does exactly what it did before.

// ---------------------------------------------------------------- money

/// "₹199", "₹1,340", "₹159.20": rupees, Indian grouping, paise only when
/// there are some.
String formatRupees(double amount) {
  final whole = amount == amount.roundToDouble();
  final format = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: whole ? 0 : 2,
  );
  return format.format(amount);
}

/// "Free" for nothing, else [formatRupees].
String priceLabel(double amount) => amount <= 0 ? 'Free' : formatRupees(amount);

// ---------------------------------------------------------------- types

/// Where a ticket type stands (`types[].status`).
enum TicketTypeStatus {
  /// Can be bought now.
  onSale,

  /// None left; its waiting list may be open ([TicketType.waitlist]).
  soldOut,

  /// Its own sales window, or the event's registration, has not opened.
  notStarted,

  /// Its sales window closed.
  ended,

  /// The event's registration is closed, or the event is over.
  closed,
}

/// The status the server wrote; a missing one is on sale (the field has
/// always been sent), a word this build doesn't know is not.
TicketTypeStatus ticketTypeStatusFrom(Object? value) =>
    switch (jsonString(value)) {
      null || 'on_sale' => TicketTypeStatus.onSale,
      'sold_out' => TicketTypeStatus.soldOut,
      'not_started' => TicketTypeStatus.notStarted,
      'ended' => TicketTypeStatus.ended,
      _ => TicketTypeStatus.closed,
    };

/// Few enough left to say so.
const fewTicketsLeft = 10;

/// One kind of ticket an event sells ("General", "Student", "VIP").
class TicketType {
  final int id;
  final String name;
  final String? description;

  /// Rupees; 0 is free.
  final double price;
  final String currency;
  final int? capacity;

  /// Places someone new can take now; null for no limit.
  final int? available;
  final TicketTypeStatus status;
  final DateTime? salesStart;
  final DateTime? salesEnd;
  final int? perPersonLimit;
  final bool isHidden;

  /// Sold out, and its waiting list can be joined.
  final bool waitlist;

  const TicketType({
    required this.id,
    required this.name,
    this.description,
    this.price = 0,
    this.currency = 'INR',
    this.capacity,
    this.available,
    this.status = TicketTypeStatus.onSale,
    this.salesStart,
    this.salesEnd,
    this.perPersonLimit,
    this.isHidden = false,
    this.waitlist = false,
  });

  bool get isFree => price <= 0;
  bool get onSale => status == TicketTypeStatus.onSale;

  /// A line about where it stands, or null when on sale with plenty left:
  /// "Only 3 left", "Sold out", "On sale from 1 Nov, 9:00 AM", "Sales
  /// ended", "Not on sale".
  String? get statusLine {
    switch (status) {
      case TicketTypeStatus.onSale:
        final left = available;
        if (left != null && left > 0 && left <= fewTicketsLeft) {
          return 'Only $left left';
        }
        return null;
      case TicketTypeStatus.soldOut:
        return waitlist ? 'Sold out · waiting list open' : 'Sold out';
      case TicketTypeStatus.notStarted:
        final start = salesStart;
        return start == null
            ? 'Not on sale yet'
            : 'On sale from ${DateFormat("d MMM, h:mm a").format(start.toLocal())}';
      case TicketTypeStatus.ended:
        return 'Sales ended';
      case TicketTypeStatus.closed:
        return 'Not on sale';
    }
  }

  static TicketType? fromJson(Map<String, dynamic> json) {
    final id = jsonInt(json['id']);
    final name = jsonString(json['name'])?.trim();
    if (id == null || name == null || name.isEmpty) return null;
    final description = jsonString(json['description'])?.trim();
    return TicketType(
      id: id,
      name: name,
      description:
          description == null || description.isEmpty ? null : description,
      price: (jsonDouble(json['price']) ?? 0).clamp(0, double.infinity),
      currency: jsonString(json['currency']) ?? 'INR',
      capacity: jsonInt(json['capacity']),
      available: jsonInt(json['available']),
      status: ticketTypeStatusFrom(json['status']),
      salesStart: jsonDate(json['sales_start']),
      salesEnd: jsonDate(json['sales_end']),
      perPersonLimit: jsonInt(json['per_person_limit']),
      isHidden: jsonBool(json['is_hidden']) ?? false,
      waitlist: jsonBool(json['waitlist']) ?? false,
    );
  }

  /// This type with no waiting list to offer: an event whose club confirms
  /// each place has none.
  TicketType withoutWaitlist() => !waitlist
      ? this
      : TicketType(
          id: id,
          name: name,
          description: description,
          price: price,
          currency: currency,
          capacity: capacity,
          available: available,
          status: status,
          salesStart: salesStart,
          salesEnd: salesEnd,
          perPersonLimit: perPersonLimit,
          isHidden: isHidden,
        );
}

// ---------------------------------------------------------------- waiting list

/// A place on a waiting list (`viewer_waitlist[]`, or the answer to joining).
class WaitlistEntry {
  final String id;
  final int? ticketTypeId;
  final String? ticketTypeName;

  /// waiting, offered, claimed, expired, removed, left.
  final String status;

  /// The place in line (1 is next), while waiting.
  final int? position;

  /// While an offer stands: until when the place is held.
  final DateTime? offerExpiresAt;
  final DateTime? joinedAt;

  /// False when they were in line already (joining again is the same place).
  final bool created;

  const WaitlistEntry({
    required this.id,
    this.ticketTypeId,
    this.ticketTypeName,
    this.status = 'waiting',
    this.position,
    this.offerExpiresAt,
    this.joinedAt,
    this.created = true,
  });

  bool get isWaiting => status == 'waiting';
  bool get isOffered => status == 'offered';

  /// Still in line, or holding an offer.
  bool get isOpen => isWaiting || isOffered;

  /// "You're #3 in line for Early bird", or "A place is held for you until
  /// Sat 1 Nov, 6:00 PM" for an offer.
  String get summary {
    final what = ticketTypeName == null ? '' : ' for $ticketTypeName';
    if (isOffered) {
      final until = offerExpiresAt;
      return until == null
          ? 'A place$what is held for you. Open the link we sent you to claim it.'
          : 'A place$what is held for you until '
              '${DateFormat("EEE d MMM, h:mm a").format(until.toLocal())}. '
              'Open the link we sent you to claim it.';
    }
    final at = position;
    return at == null
        ? "You're on the waiting list$what."
        : "You're #$at in line$what.";
  }

  static WaitlistEntry? fromJson(Map<String, dynamic> json) {
    final id = jsonString(json['id'])?.trim();
    if (id == null || id.isEmpty) return null;
    final name = jsonString(json['ticket_type_name'])?.trim();
    return WaitlistEntry(
      id: id,
      ticketTypeId: jsonInt(json['ticket_type_id']),
      ticketTypeName: name == null || name.isEmpty ? null : name,
      status: jsonString(json['status']) ?? 'waiting',
      position: jsonInt(json['position']),
      offerExpiresAt: jsonDate(json['offer_expires_at']),
      joinedAt: jsonDate(json['joined_at']),
      created: jsonBool(json['created']) ?? true,
    );
  }
}

// ---------------------------------------------------------------- an event's tickets

/// The event page's `ticketing` (also `GET /events/{id}/ticket-types`).
class EventTicketing {
  /// The visible types, in the club's order (a hidden one a link named, too).
  final List<TicketType> types;

  /// A registration must name `ticket_type_id`: more than one visible type.
  final bool requiresChoice;

  /// The event's places left across its types; null for no total.
  final int? available;

  /// Every listed type is sold out.
  final bool soldOut;
  final bool waitlistEnabled;
  final int offerHours;

  /// The signed-in viewer's own places in line.
  final List<WaitlistEntry> viewerWaitlist;

  /// The club reviews every registration (`requires_approval`): the form
  /// sends one for review (the API's request), and the club confirms or
  /// declines it. False when the server doesn't say.
  final bool requiresApproval;

  /// The signed-in viewer's open registration under review for this event
  /// (`viewer_request`: `{id, status, token, status_url}`, pending or
  /// confirmed and unpaid); null when they have none.
  final RegistrationRequest? viewerRequest;

  /// The server says whether the viewer has a request (`viewer_request` is
  /// there, even null): nothing else need be asked.
  final bool saysViewerRequest;

  const EventTicketing({
    this.types = const [],
    this.requiresChoice = false,
    this.available,
    this.soldOut = false,
    this.waitlistEnabled = false,
    this.offerHours = 24,
    this.viewerWaitlist = const [],
    this.requiresApproval = false,
    this.viewerRequest,
    this.saysViewerRequest = false,
  });

  /// The object, or null when [value] isn't one -- a server older than
  /// ticket types sends `ticketing: null`, or nothing.
  ///
  /// An event whose club reviews every registration has no waiting list
  /// (people register, and the club reviews each one): it reads as off, and
  /// no type offers one, whatever an older server still says.
  static EventTicketing? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null || json['types'] is! List) return null;
    final waitlist = jsonObject(json['waitlist']);
    final read = EventTicketing(
      types: [
        for (final item in jsonObjects(json['types']))
          if (TicketType.fromJson(item) case final type?) type,
      ],
      requiresChoice: jsonBool(json['requires_choice']) ?? false,
      available: jsonInt(json['available']),
      soldOut: jsonBool(json['sold_out']) ?? false,
      waitlistEnabled: jsonBool(waitlist?['enabled']) ?? false,
      offerHours: jsonInt(waitlist?['offer_hours']) ?? 24,
      viewerWaitlist: [
        for (final item in jsonObjects(json['viewer_waitlist']))
          if (WaitlistEntry.fromJson(item) case final entry?) entry,
      ],
      requiresApproval: jsonBool(json['requires_approval']) ?? false,
      viewerRequest: RegistrationRequest.fromJson(json['viewer_request']),
      saysViewerRequest: json.containsKey('viewer_request'),
    );
    return read.requiresApproval ? read.withoutWaitlist() : read;
  }

  /// These tickets for an event whose club reviews every registration: no
  /// waiting list (off, and no type offering one). The viewer's places already in
  /// line are kept, to be seen and left.
  EventTicketing withoutWaitlist() => EventTicketing(
        types: [for (final type in types) type.withoutWaitlist()],
        requiresChoice: requiresChoice,
        available: available,
        soldOut: soldOut,
        waitlistEnabled: false,
        offerHours: offerHours,
        viewerWaitlist: viewerWaitlist,
        requiresApproval: true,
        viewerRequest: viewerRequest,
        saysViewerRequest: saysViewerRequest,
      );

  TicketType? typeById(int? id) {
    if (id == null) return null;
    for (final type in types) {
      if (type.id == id) return type;
    }
    return null;
  }

  /// The types whose waiting list can be joined now; none when the club
  /// reviews every registration.
  List<TicketType> get waitlistTypes => requiresApproval
      ? const []
      : [for (final type in types) if (type.waitlist) type];

  bool get canJoinWaitlist => waitlistTypes.isNotEmpty;

  /// The viewer's places still in line or held.
  List<WaitlistEntry> get openPlaces =>
      [for (final entry in viewerWaitlist) if (entry.isOpen) entry];

  /// The types that can be bought now.
  List<TicketType> get onSale =>
      [for (final type in types) if (type.onSale) type];

  bool get anyPaid => types.any((type) => !type.isFree);

  /// The prices, cheapest first.
  List<double> get _prices => [for (final type in types) type.price]..sort();

  /// "₹199", or "₹199 – ₹999" across several prices; null with no types.
  String? get priceRange {
    final prices = _prices;
    if (prices.isEmpty) return null;
    final low = prices.first, high = prices.last;
    if (low == high) return priceLabel(low);
    return '${priceLabel(low)} – ${formatRupees(high)}';
  }

  /// The type a registration starts on: the one a link named, when it is
  /// on sale; the only one on sale, when several are listed; else none (the
  /// person picks).
  int? initialChoice({int? linked}) {
    final named = typeById(linked);
    if (named != null && named.onSale) return named.id;
    if (!requiresChoice) return null;
    final buyable = onSale;
    return buyable.length == 1 ? buyable.single.id : null;
  }
}

// ---------------------------------------------------------------- codes

/// What a discount code does to the price (`POST
/// /events/{id}/discount-codes/check`).
class DiscountQuote {
  /// The code as the club wrote it ("EARLY20").
  final String code;
  final int? ticketTypeId;
  final double price;
  final double discount;

  /// What is left to pay for the ticket.
  final double amount;

  /// Nothing left to pay: no payment step.
  final bool free;

  const DiscountQuote({
    required this.code,
    this.ticketTypeId,
    this.price = 0,
    this.discount = 0,
    this.amount = 0,
    this.free = false,
  });

  /// "EARLY20 takes ₹39.80 off: you pay ₹159.20", or "... your ticket is free".
  String get summary => free
      ? '$code applied: your ticket is free.'
      : '$code applied: ${formatRupees(discount)} off, you pay ${formatRupees(amount)}.';

  static DiscountQuote? fromJson(Object? value) {
    final json = jsonObject(value);
    final code = jsonString(json?['code'])?.trim();
    if (json == null || code == null || code.isEmpty) return null;
    final amount = jsonDouble(json['amount']) ?? 0;
    return DiscountQuote(
      code: code,
      ticketTypeId: jsonInt(json['ticket_type_id']),
      price: jsonDouble(json['price']) ?? 0,
      discount: jsonDouble(json['discount']) ?? 0,
      amount: amount,
      free: jsonBool(json['free']) ?? amount <= 0,
    );
  }
}

// ---------------------------------------------------------------- cancelled

/// The club called the event off: `status: "cancelled"` and `cancellation:
/// {reason, cancelled_at}` on `/events/info` and `/discover/events`.
class EventCancellation {
  final String? reason;
  final DateTime? cancelledAt;

  const EventCancellation({this.reason, this.cancelledAt});

  /// What the person is told about their money: on a paid ticket, the
  /// refund that cancelling started.
  static const refundNote = 'Your payment is being refunded';

  /// The longer word: where it goes, and when.
  static const refundDetail = 'Your payment is being refunded in full, the '
      'way you paid. It usually reaches your account in 5–7 working days.';

  /// The event's cancellation from a body that has a `status` and maybe a
  /// `cancellation` (the event, a list row, a page's `event`); null when it
  /// isn't cancelled -- or the server doesn't say.
  static EventCancellation? of(Map<String, dynamic>? json) {
    if (json == null) return null;
    final detail = jsonObject(json['cancellation']);
    if (jsonString(json['status']) != 'cancelled' && detail == null) {
      return null;
    }
    final reason = jsonString(detail?['reason'])?.trim();
    return EventCancellation(
      reason: reason == null || reason.isEmpty ? null : reason,
      cancelledAt: jsonDate(detail?['cancelled_at']),
    );
  }
}

// ---------------------------------------------------------------- tickets

/// The ticket type a registration or ticket names, wherever the server put
/// it: the registration's `ticket_type: {id, name}`, a list row's
/// `ticket_type_name`, or the attendee's `ticket_label`. Null when it says
/// none (a single-type event's ticket, or a server without ticket types).
String? ticketTypeNameOf(Map<String, dynamic>? json) {
  if (json == null) return null;
  final type = json['ticket_type'];
  final candidates = [
    if (jsonObject(type) case final object?) object['name'] else type,
    json['ticket_type_name'],
    json['ticket_label'],
  ];
  for (final candidate in candidates) {
    final name = candidate is String ? candidate.trim() : null;
    if (name != null && name.isNotEmpty) return name;
  }
  return null;
}

/// The answer to registering (and to claiming an offer, which is the same).
class RegistrationResult {
  final int? eventId;
  final String? eventName;
  final String? eventDateTime;
  final String? registrationId;
  final String? ticketId;
  final String? fullName;
  final String? email;
  final String? phone;

  /// What is left to pay; 0 means no payment step, even on a paid event.
  final double payAmount;
  final String? ticketTypeName;

  /// The type's price before any code.
  final double? price;
  final String? discountCode;
  final double? discountAmount;
  final bool isPaid;

  /// A session for the guest the server made (signed out, or signed in as
  /// someone else): the registration isn't this account's.
  final bool forGuest;

  /// The club reviews every registration: this one is under review
  /// (`approval`, the API's request). No ticket, and nothing to pay, until
  /// the club confirms it. Null for a registration that is in.
  final RegistrationRequest? approval;

  const RegistrationResult({
    this.eventId,
    this.eventName,
    this.eventDateTime,
    this.registrationId,
    this.ticketId,
    this.fullName,
    this.email,
    this.phone,
    this.payAmount = 0,
    this.ticketTypeName,
    this.price,
    this.discountCode,
    this.discountAmount,
    this.isPaid = false,
    this.forGuest = false,
    this.approval,
  });

  /// Something to pay now. Never for a request: it is paid, if at all,
  /// once the club confirms it.
  bool get needsPayment => approval == null && payAmount > 0;

  /// A request the club will confirm or decline, not a registration.
  bool get awaitingApproval => approval != null;

  static RegistrationResult fromJson(Object? value) {
    final json = jsonObject(value) ?? const <String, dynamic>{};
    final discount = jsonObject(json['discount']);
    String? text(Object? v) {
      final s = jsonString(v)?.trim();
      return s == null || s.isEmpty ? null : s;
    }

    return RegistrationResult(
      eventId: jsonInt(json['event_id']),
      eventName: text(json['event_name']),
      eventDateTime: text(json['event_datetime']),
      registrationId: text(json['event_registration_id']),
      ticketId: text(json['ticket_id']),
      fullName: text(json['full_name']),
      email: text(json['email']),
      phone: text(json['phone']),
      payAmount: jsonDouble(json['pay_amount']) ?? 0,
      ticketTypeName: ticketTypeNameOf(json),
      price: jsonDouble(json['price']),
      discountCode: text(discount?['code']),
      discountAmount: jsonDouble(discount?['amount']),
      isPaid: jsonBool(json['is_paid']) ?? false,
      forGuest: jsonObject(json['auth_token']) != null ||
          text(json['auth_token']) != null,
      approval: RegistrationRequest.fromJson(json['approval']),
    );
  }
}

// ---------------------------------------------------------------- offers

/// Where a waiting-list offer stands.
enum OfferStatus { offered, expired, claimed, left, removed, unknown }

OfferStatus offerStatusFrom(Object? value) => switch (jsonString(value)) {
      'offered' => OfferStatus.offered,
      'expired' => OfferStatus.expired,
      'claimed' => OfferStatus.claimed,
      'left' => OfferStatus.left,
      'removed' => OfferStatus.removed,
      _ => OfferStatus.unknown,
    };

/// A place offered from the waiting list: what the claim link opens
/// (`GET /waitlist/offers/{token}`).
class WaitlistOffer {
  final String id;
  final OfferStatus status;
  final int eventId;
  final String eventSlug;
  final String eventName;
  final DateTime? eventDateTime;
  final String? locationName;
  final Map<String, dynamic>? poster;
  final int? ticketTypeId;
  final String ticketTypeName;
  final double price;
  final String fullName;

  /// Masked by the server ("as•••@gmail.com", "•••••3210").
  final String? email;
  final String? phone;
  final DateTime? expiresAt;

  /// Joined with a phone number only: claiming must send an email.
  final bool needsEmail;
  final bool needsPayment;

  /// A claim was started and is waiting for its payment.
  final String? registrationId;

  /// Why the place is offered: `approved` when the club confirmed the
  /// person's request for it ("Confirm each registration"); `waitlist` (or
  /// nothing, from an older server) for a waiting list's turn.
  final String? reason;

  /// What a confirmed request's place costs (`amount`): its ticket's price
  /// with the request's code already taken off. Null when not said.
  final double? amount;

  /// The event's club, when the offer says (`event.club.name`).
  final String? clubName;

  const WaitlistOffer({
    required this.id,
    required this.status,
    required this.eventId,
    this.eventSlug = '',
    required this.eventName,
    this.eventDateTime,
    this.locationName,
    this.poster,
    this.ticketTypeId,
    required this.ticketTypeName,
    this.price = 0,
    this.fullName = '',
    this.email,
    this.phone,
    this.expiresAt,
    this.needsEmail = false,
    this.needsPayment = false,
    this.registrationId,
    this.reason,
    this.clubName,
    this.amount,
  });

  /// The club confirmed the person's request: a place of their own, not a
  /// turn from a waiting list.
  bool get fromApproval => reason == 'approved';

  /// The club's name, or "The club" when the offer doesn't say.
  String get clubOrDefault => clubName ?? 'The club';

  /// What claiming it costs: for a confirmed request, the price the club
  /// confirmed ([amount], its code taken off); else the ticket's price.
  double get payable => fromApproval && amount != null ? amount! : price;

  /// The app's route to the event.
  String get eventRoute =>
      '/events/${eventSlug.isNotEmpty ? Uri.encodeComponent(eventSlug) : eventId}';

  static WaitlistOffer? fromJson(Object? value) {
    final json = jsonObject(value);
    final event = jsonObject(json?['event']);
    final eventId = jsonInt(event?['id']);
    if (json == null || event == null || eventId == null) return null;
    final type = jsonObject(json['ticket_type']) ?? const <String, dynamic>{};
    String? text(Object? v) {
      final s = jsonString(v)?.trim();
      return s == null || s.isEmpty ? null : s;
    }

    return WaitlistOffer(
      id: text(json['id']) ?? '',
      status: offerStatusFrom(json['status']),
      eventId: eventId,
      eventSlug: text(event['slug']) ?? '',
      eventName: text(event['name']) ?? 'The event',
      eventDateTime: jsonDate(event['event_datetime']),
      locationName: text(event['location_name']),
      poster: jsonObject(event['poster']),
      ticketTypeId: jsonInt(type['id']),
      ticketTypeName: text(type['name']) ?? 'Ticket',
      price: jsonDouble(type['price']) ?? 0,
      fullName: text(json['full_name']) ?? '',
      email: text(json['email']),
      phone: text(json['phone']),
      expiresAt: jsonDate(json['expires_at']),
      needsEmail: jsonBool(json['needs_email']) ?? false,
      needsPayment: jsonBool(json['needs_payment']) ??
          (jsonDouble(type['price']) ?? 0) > 0,
      registrationId: text(json['registration_id']),
      reason: text(json['reason'])?.toLowerCase(),
      amount: jsonDouble(json['amount']),
      clubName: text(jsonObject(event['club'])?['name']) ??
          text(event['club_name']),
    );
  }
}

/// The claim link's token from the website's address
/// (`https://myotherapp.in/claim/{token}`), or the text itself when it has
/// no `/claim/` in it. Null for nothing.
String? claimTokenFrom(String? link) {
  final text = link?.trim() ?? '';
  if (text.isEmpty) return null;
  final marker = text.lastIndexOf('/claim/');
  var token = marker < 0 ? text : text.substring(marker + '/claim/'.length);
  token = token.split(RegExp('[?#/]')).first.trim();
  if (token.isEmpty) return null;
  return Uri.decodeComponent(token);
}

/// The app's route to a claim link's screen.
String claimRoute(String token) => '/claim/${Uri.encodeComponent(token)}';

// ---------------------------------------------------------------- refusals

/// The `error_code`s ticket types, codes, waiting lists and offers refuse
/// with (docs/TICKETING.md §6), and a cancelled event's.
abstract final class TicketingErrorCodes {
  static const ticketTypeRequired = 'TICKET_TYPE_REQUIRED';
  static const ticketTypeNotFound = 'TICKET_TYPE_NOT_FOUND';
  static const ticketTypeNotOnSale = 'TICKET_TYPE_NOT_ON_SALE';
  static const ticketTypeSoldOut = 'TICKET_TYPE_SOLD_OUT';
  static const ticketTypeLimit = 'TICKET_TYPE_LIMIT';
  static const eventFull = 'EVENT_FULL';

  static const discountInvalid = 'DISCOUNT_CODE_INVALID';
  static const discountNotStarted = 'DISCOUNT_CODE_NOT_STARTED';
  static const discountExpired = 'DISCOUNT_CODE_EXPIRED';
  static const discountNotForType = 'DISCOUNT_CODE_NOT_FOR_TYPE';
  static const discountUsedUp = 'DISCOUNT_CODE_USED_UP';
  static const discountLimit = 'DISCOUNT_CODE_LIMIT';

  static const waitlistClosed = 'WAITLIST_CLOSED';
  static const waitlistNotNeeded = 'WAITLIST_NOT_NEEDED';
  static const waitlistContactRequired = 'WAITLIST_CONTACT_REQUIRED';

  /// Joining the waiting list of an event whose club reviews every
  /// registration (409): it has none.
  static const waitlistOffOnApprovalEvents = 'WAITLIST_OFF_ON_APPROVAL_EVENTS';
  static const alreadyRegistered = 'ALREADY_REGISTERED';
  static const whatsappNumber = 'WHATSAPP_NUMBER';

  static const offerNotFound = 'OFFER_NOT_FOUND';
  static const offerExpired = 'OFFER_EXPIRED';
  static const offerClaimed = 'OFFER_CLAIMED';
  static const emailRequired = 'EMAIL_REQUIRED';
  static const clubEmail = 'CLUB_EMAIL';

  static const registrationsClosed = 'REGISTRATIONS_CLOSED';

  /// Paying for a cancelled event's ticket (409).
  static const eventCancelled = 'EVENT_CANCELLED';
}

Map<String, dynamic>? _errorsOf(Object? error) => apiExceptionOf(error)?.errors;

/// Whether the refusal says the waiting list can be joined instead
/// (`EVENT_FULL` or `TICKET_TYPE_SOLD_OUT` with `errors.waitlist: true`).
/// Never for a registration under review ([approval]: the club reviews
/// every registration), whatever
/// the refusal says: such an event has no waiting list.
bool offersWaitlist(Object? error, {bool approval = false}) {
  if (approval) return false;
  final code = errorCodeOf(error);
  if (code != TicketingErrorCodes.eventFull &&
      code != TicketingErrorCodes.ticketTypeSoldOut) {
    return false;
  }
  return jsonBool(_errorsOf(error)?['waitlist']) == true;
}

/// Whether the refusal is because the club called the event off:
/// registering (400 REGISTRATIONS_CLOSED, `closed_reason: "cancelled"`) or
/// paying (409 EVENT_CANCELLED).
bool isCancelledRefusal(Object? error) {
  final code = errorCodeOf(error);
  if (code == TicketingErrorCodes.eventCancelled) return true;
  return code == TicketingErrorCodes.registrationsClosed &&
      _errorsOf(error)?['closed_reason'] == 'cancelled';
}

const _tooManyTries = 'Too many tries. Wait a minute, then try again.';

/// What is wrong with a discount code, in words, for under its field; null
/// when [error] is not about the code.
String? discountCodeProblem(Object? error) {
  if (statusCodeOf(error) == 429) return _tooManyTries;
  switch (errorCodeOf(error)) {
    case TicketingErrorCodes.discountInvalid:
      return "That code isn't valid for this event.";
    case TicketingErrorCodes.discountNotStarted:
      return "That code can't be used yet.";
    case TicketingErrorCodes.discountExpired:
      return 'That code has expired.';
    case TicketingErrorCodes.discountNotForType:
      return "That code isn't for this ticket. Try another ticket, or remove the code.";
    case TicketingErrorCodes.discountUsedUp:
      return 'That code has been used up.';
    case TicketingErrorCodes.discountLimit:
      return "You've already used that code as many times as it allows.";
  }
  return null;
}

/// Joining refused because the club reviews every registration
/// ([TicketingErrorCodes.waitlistOffOnApprovalEvents]), in words, naming
/// [clubName] ("the club" without one).
String waitlistOffOnApprovalProblemFor(String? clubName) {
  final name = clubName?.trim() ?? '';
  return 'This event has no waiting list: '
      '${name.isEmpty ? 'the club' : name} reviews every registration. '
      "Register instead, and they'll get back to you.";
}

/// [waitlistOffOnApprovalProblemFor] without the club's name.
const waitlistOffOnApprovalProblem = 'This event has no waiting list: the '
    "club reviews every registration. Register instead, and they'll get "
    'back to you.';

/// What went wrong joining a waiting list, in words. [clubName] names the
/// club, for an event whose club reviews every registration.
String waitlistJoinProblem(Object? error, {String? clubName}) {
  if (statusCodeOf(error) == 429) return _tooManyTries;
  switch (errorCodeOf(error)) {
    case TicketingErrorCodes.waitlistClosed:
      return "This event's waiting list isn't open.";
    case TicketingErrorCodes.waitlistOffOnApprovalEvents:
      return waitlistOffOnApprovalProblemFor(clubName);
    case TicketingErrorCodes.waitlistNotNeeded:
      return 'Tickets are available again: you can register instead.';
    case TicketingErrorCodes.waitlistContactRequired:
      return 'Add an email address or a phone number so we can tell you.';
    case TicketingErrorCodes.alreadyRegistered:
      return 'You already have a ticket for this event.';
    case TicketingErrorCodes.whatsappNumber:
      return "WhatsApp can't reach this number. Use a mobile number, or untick WhatsApp.";
    case TicketingErrorCodes.ticketTypeRequired:
      return 'Choose a ticket first.';
  }
  final said = apiExceptionOf(error)?.serverMessage?.trim();
  if (said != null && said.isNotEmpty && (statusCodeOf(error) ?? 500) < 500) {
    return said;
  }
  return "We couldn't add you to the waiting list. Try again in a moment.";
}
