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
///
/// A push carries its event as the string `event_id`; an inbox line as its
/// `event` (and the push's data beside it).
library;

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
