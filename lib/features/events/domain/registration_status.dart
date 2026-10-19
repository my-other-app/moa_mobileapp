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
