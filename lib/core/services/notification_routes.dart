/// Where a tapped push, or its line in the inbox, opens: one table for both,
/// so the two always agree. Pure Dart, so the inbox's model and the tests
/// read it without Firebase.
///
/// The server's types and what each carries (`moa_backend`
/// `app/core/notifications/triggers.py`, `app/api/live/notify.py`,
/// `app/api/threads/service.py`, `app/api/checkins/after.py`):
///
/// | type                                 | opens                        |
/// | ------------------------------------ | ---------------------------- |
/// | `club_thread` (`thread_id`)          | the post                     |
/// | the live room's ([liveRoomTypes])    | the room, or the quiz        |
/// | `event_checkin` with `open: people`  | People Like You              |
/// | `new_event` (a followed club's)      | the event                    |
/// | `interest_match` (push) /            | the event                    |
/// | `nearby_event` (its inbox line)      |                              |
/// | `club_announcement` (to registrants) | the event                    |
/// | `event_reminder`, `event_started`,   | the event                    |
/// | `event_checkin`, `event_registered`, |                              |
/// | `event_invited`                      |                              |
/// | `volunteer_assigned` (push) /        | the event's door scanner     |
/// | `volunteer_added` (its inbox line)   |                              |
/// | `certificate_generated`              | My Certificates              |
/// | `waitlist_offer` (`token`, `url`)    | the claim screen             |
/// | `request_approved` (`token`)         | the ticket (`ticket_id`), or |
/// |                                      | the request's screen         |
/// | `request_approved_pay` (`token`)     | the claim screen, to pay     |
/// | `request_declined` (`token`)         | the request's screen         |
///
/// A push carries its event as the string `event_id`; an inbox line as its
/// `event` (and the push's data beside it).
library;

import 'package:finnet/features/events/domain/registration_request.dart';
import 'package:finnet/features/events/domain/ticketing.dart';
import 'package:finnet/features/live/live_locations.dart';

/// The pushes (and inbox lines) that open an event's live room.
const liveRoomTypes = {
  'event_live_join',
  'event_live_started',
  'event_live_qa',
  'event_live_update',
};

/// The pushes (and inbox lines) that open their event's page.
const eventPageTypes = {
  'event_reminder',
  'event_started',
  'event_checkin',
  'event_registered',
  'event_invited',
  // A followed club's new event.
  'new_event',
  // A new event in the person's topics: the push says `interest_match`,
  // its line in the inbox `nearby_event`.
  'interest_match',
  'nearby_event',
  // The organiser's message to an event's registrants.
  'club_announcement',
};

/// "You're now a volunteer": the push says `volunteer_assigned`, its line in
/// the inbox `volunteer_added`. Both open the event's door scanner.
const volunteerTypes = {'volunteer_assigned', 'volunteer_added'};

/// "Your certificate is ready": `certificate_generated` (the server's type;
/// `certificate_ready` is the name its WhatsApp message goes by).
const certificateTypes = {'certificate_generated', 'certificate_ready'};

/// "A place opened up for you": a waiting list's offer
/// (`app/api/ticketing/waitlist.py`), with `token` and `url`.
const waitlistOfferType = 'waitlist_offer';

/// "Confirm each registration": the club confirmed a request (a free
/// ticket, registered), confirmed one for a paid ticket (pay to get it), or
/// declined one. Each carries the request's `token` and its `event_id`.
const requestApprovedType = 'request_approved';
const requestApprovedPayType = 'request_approved_pay';
const requestDeclinedType = 'request_declined';
const requestTypes = {
  requestApprovedType,
  requestApprovedPayType,
  requestDeclinedType,
};

/// Where a request push (or its inbox line) opens; [requestTypes] only.
///
/// - confirmed: the ticket when the push names it (`ticket_id`), else the
///   request's screen, which goes on to the ticket once it is there;
/// - confirmed, to pay: the claim screen, by the claim link's token
///   (`claim_token`, or the one in its `claim_url`) when the push has it;
///   else the request's screen told to go on to paying (`?next=pay`);
/// - declined: the request's screen, which says so (and the club's note).
///
/// The request's token is the push's `token`, or the one in its `url`
/// (`https://myotherapp.in/requests/...`). Without one: the event.
String? requestRouteFor(String type, int? eventId, Map<String, dynamic> data) {
  String? text(Object? value) {
    final s = value?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  final url = text(data['url']);
  final token = requestTokenFrom(text(data['token'])) ??
      (url != null && url.contains('/requests/')
          ? requestTokenFrom(url)
          : null);
  final eventPage = eventId == null ? null : '/events/$eventId';
  switch (type) {
    case requestApprovedType:
      final ticketId = text(data['ticket_id']);
      if (ticketId != null) return '/tickets/${Uri.encodeComponent(ticketId)}';
      return token == null ? eventPage : requestRoute(token);
    case requestApprovedPayType:
      final claimUrl = text(data['claim_url']) ?? url;
      final claim = claimTokenFrom(text(data['claim_token'])) ??
          (claimUrl != null && claimUrl.contains('/claim/')
              ? claimTokenFrom(claimUrl)
              : null);
      if (claim != null) return claimRoute(claim);
      return token == null ? eventPage : '${requestRoute(token)}?next=pay';
    default:
      return token == null ? eventPage : requestRoute(token);
  }
}

/// The live room in the app for a live push or its inbox line: the quiz for
/// [what] `quiz`, to join with the code on the screen; the room for anything
/// else (`room`, `qa`, `poll`, or none).
String liveJoinRoute(int eventId, Object? what) =>
    what == 'quiz' ? liveQuizLocation(eventId) : liveRoomLocation(eventId);

/// The event a push's [data] names (`event_id`, a string), or null.
int? eventIdIn(Map<String, dynamic> data) =>
    int.tryParse(data['event_id']?.toString().trim() ?? '');

/// Where a notification of [type] opens, about [eventId], with the push's
/// [data]; null when it opens nothing in the app.
///
/// `new_event` without an event opens its club (`club_id`), rather than
/// nothing.
String? notificationRoute(
  String? type, {
  int? eventId,
  Map<String, dynamic> data = const {},
}) {
  if (type == 'club_thread') {
    final threadId = data['thread_id']?.toString().trim();
    if (threadId == null || threadId.isEmpty) return null;
    return '/threads/${Uri.encodeComponent(threadId)}';
  }
  if (certificateTypes.contains(type)) return '/profile/certificates';
  if (type == waitlistOfferType) {
    // A place held from the waiting list: its claim screen, by the push's
    // `token`, or the one in its `url` (`https://myotherapp.in/claim/...`).
    final token = claimTokenFrom(data['token']?.toString()) ??
        claimTokenFrom(data['url']?.toString());
    if (token != null) return claimRoute(token);
    return eventId == null ? null : '/events/$eventId';
  }
  if (type != null && requestTypes.contains(type)) {
    return requestRouteFor(type, eventId, data);
  }
  if (eventId == null) {
    final clubId = int.tryParse(data['club_id']?.toString().trim() ?? '');
    return type == 'new_event' && clubId != null ? '/clubs/$clubId' : null;
  }
  if (liveRoomTypes.contains(type)) return liveJoinRoute(eventId, data['what']);
  if (type == 'event_checkin' && data['open']?.toString() == 'people') {
    return '/events/$eventId/people';
  }
  if (volunteerTypes.contains(type)) return '/volunteer/scanner/$eventId';
  if (eventPageTypes.contains(type)) return '/events/$eventId';
  return null;
}
