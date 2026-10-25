import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/registration_status.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/shared/utils/image_url.dart';

/// The ticket code in a ticket's address -- `/api/v1/events/tickets/{code}`
/// from an older server, `https://myotherapp.in/tickets/{code}` now -- or
/// the text itself when it has no `/tickets/` in it. Null for nothing.
String? ticketCodeFromUrl(String? url) {
  final text = url?.trim() ?? '';
  if (text.isEmpty) return null;
  final marker = text.lastIndexOf('/tickets/');
  var code = marker < 0 ? text : text.substring(marker + '/tickets/'.length);
  // A query or fragment is not part of the code; nor is a trailing slash.
  code = code.split(RegExp('[?#]')).first;
  if (code.endsWith('/')) code = code.substring(0, code.length - 1);
  code = Uri.decodeComponent(code).trim();
  return code.isEmpty || code.contains('/') ? null : code;
}

/// One of the signed-in person's tickets, kept on the phone so it opens
/// with no network: at the door, where there is often no signal.
///
/// Built from their upcoming registrations (`/events/list?is_registered=
/// true&is_ended=false`). The QR is drawn on the phone from [code] -- the
/// plain ticket code (`MOA-7K3QF-X9PWM`), what the door scanner reads.
class SavedTicket {
  const SavedTicket({
    required this.code,
    required this.eventId,
    required this.eventName,
    this.startsAt,
    this.durationHours,
    this.venue,
    this.isOnline = false,
    this.ticketUrl,
    this.posterUrl,
    this.clubName,
    this.status = RegistrationStatus.registered,
    this.revoked = false,
    this.ticketType,
    this.paid = false,
    this.cancellation,
  });

  /// The ticket code, which the QR encodes.
  final String code;
  final int eventId;
  final String eventName;
  final DateTime? startsAt;
  final double? durationHours;
  final String? venue;
  final bool isOnline;
  final String? ticketUrl;
  final String? posterUrl;
  final String? clubName;

  /// [RegistrationStatus.registered] or, once checked in,
  /// [RegistrationStatus.attended].
  final RegistrationStatus status;

  /// The organiser revoked it: the door refuses it. Kept on the phone so
  /// the ticket screen can say so offline, never shown as a usable ticket.
  /// From the list's `ticket_revoked`; a server without the field (or a
  /// null) means not revoked.
  final bool revoked;

  /// The ticket type it was bought as ("Early bird"); null for an event
  /// that sells one kind, or when the server didn't say. The list of
  /// registrations doesn't say it today: it is kept from the registration's
  /// answer ([withTicketType]).
  final String? ticketType;

  /// Paid for, on a paid event: a cancelled event's refund applies.
  final bool paid;

  /// The club called the event off, when the list says so.
  final EventCancellation? cancellation;

  /// This ticket, of type [name] (kept when [name] is null).
  SavedTicket withTicketType(String? name) => name == null || name == ticketType
      ? this
      : SavedTicket(
          code: code,
          eventId: eventId,
          eventName: eventName,
          startsAt: startsAt,
          durationHours: durationHours,
          venue: venue,
          isOnline: isOnline,
          ticketUrl: ticketUrl,
          posterUrl: posterUrl,
          clubName: clubName,
          status: status,
          revoked: revoked,
          ticketType: name,
          paid: paid,
          cancellation: cancellation,
        );

  /// When the event is over, as far as the phone can tell: its start plus
  /// its length (a day when the length is unknown).
  DateTime? get endsAt {
    final start = startsAt;
    if (start == null) return null;
    final hours = durationHours;
    final length = hours == null || hours <= 0
        ? const Duration(hours: 24)
        : Duration(minutes: (hours * 60).round());
    return start.add(length);
  }

  /// Still worth keeping: not over yet. A ticket without a date is kept.
  bool isCurrentOrUpcoming(DateTime now) {
    final end = endsAt;
    return end == null || end.isAfter(now);
  }

  /// A ticket from one registration in the list, or null when it is not
  /// one: no ticket code, no event, or a paid event's registration still
  /// waiting for its payment (the door refuses those, FEE_UNPAID).
  static SavedTicket? fromRegistration(Map<String, dynamic> item) {
    final code = jsonString(item['ticket_id'])?.trim() ??
        ticketCodeFromUrl(jsonString(item['ticket_url']));
    final eventId = jsonInt(item['id']);
    if (code == null || code.isEmpty || eventId == null) return null;
    if (isAwaitingPayment(item)) return null;
    final club = jsonObject(item['club']);
    return SavedTicket(
      code: code,
      eventId: eventId,
      eventName: jsonText(item['name'], 'Event'),
      startsAt: jsonDate(item['event_datetime'])?.toLocal(),
      durationHours: jsonDouble(item['duration']),
      venue: jsonString(item['location_name'])?.trim(),
      isOnline: jsonBool(item['is_online']) ?? false,
      ticketUrl: jsonString(item['ticket_url']),
      posterUrl: imageUrlFrom(item['poster'],
          prefer: const ['medium', 'large', 'thumbnail', 'original']),
      clubName: jsonString(club?['name']),
      status: jsonBool(item['is_attended']) == true
          ? RegistrationStatus.attended
          : RegistrationStatus.registered,
      revoked: isTicketRevoked(item),
      ticketType: ticketTypeNameOf(item),
      paid: item['has_fee'] == true && item['is_paid'] == true,
      cancellation: EventCancellation.of(item),
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'event_id': eventId,
        'event_name': eventName,
        if (startsAt != null) 'starts_at': startsAt!.toUtc().toIso8601String(),
        if (durationHours != null) 'duration_hours': durationHours,
        if (venue != null) 'venue': venue,
        'is_online': isOnline,
        if (ticketUrl != null) 'ticket_url': ticketUrl,
        if (posterUrl != null) 'poster_url': posterUrl,
        if (clubName != null) 'club_name': clubName,
        'status': status.name,
        if (revoked) 'revoked': true,
        if (ticketType != null) 'ticket_type': ticketType,
        if (paid) 'paid': true,
        if (cancellation != null) ...{
          'cancelled': true,
          if (cancellation!.reason != null)
            'cancellation_reason': cancellation!.reason,
        },
      };

  /// Null for anything that cannot be a saved ticket.
  static SavedTicket? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null) return null;
    final code = jsonString(json['code']);
    final eventId = jsonInt(json['event_id']);
    if (code == null || code.isEmpty || eventId == null) return null;
    return SavedTicket(
      code: code,
      eventId: eventId,
      eventName: jsonText(json['event_name'], 'Event'),
      startsAt: jsonDate(json['starts_at'])?.toLocal(),
      durationHours: jsonDouble(json['duration_hours']),
      venue: jsonString(json['venue']),
      isOnline: jsonBool(json['is_online']) ?? false,
      ticketUrl: jsonString(json['ticket_url']),
      posterUrl: jsonString(json['poster_url']),
      clubName: jsonString(json['club_name']),
      status: json['status'] == RegistrationStatus.attended.name
          ? RegistrationStatus.attended
          : RegistrationStatus.registered,
      revoked: jsonBool(json['revoked']) == true,
      ticketType: jsonString(json['ticket_type']),
      paid: jsonBool(json['paid']) == true,
      cancellation: jsonBool(json['cancelled']) == true
          ? EventCancellation(reason: jsonString(json['cancellation_reason']))
          : null,
    );
  }
}
