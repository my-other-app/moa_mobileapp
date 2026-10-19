import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';

// Where the discover screens live, and how a card opens the existing event,
// club and post pages. The addresses carry the same parameters as the
// website's (`/events?when=this_week` is `/discover/events?when=this_week`
// here), so a link from the site can be mapped onto them.

const findEventsPath = '/discover/events';
const clubsDirectoryPath = '/discover/clubs';
const threadsFeedPath = '/discover/threads';
const topicsPath = '/topics';

/// Find events with [filters]; the calendar for [month] with [calendar].
String findEventsLocation(
  EventFilters filters, {
  bool calendar = false,
  String? month,
}) =>
    locationWith(findEventsPath, {
      ...filters.toParams(),
      if (calendar) 'view': 'calendar',
      if (calendar && month != null) 'month': month,
    });

String clubsDirectoryLocation([ClubFilters filters = ClubFilters.none]) =>
    locationWith(clubsDirectoryPath, filters.toParams());

/// A topic's page, narrowed to one of its interests with [interest].
String topicLocation(String slug, {int? interest}) => locationWith(
      '$topicsPath/${Uri.encodeComponent(slug)}',
      {if (interest != null) 'interest': '$interest'},
    );

/// The event's page.
void openDiscoverEvent(BuildContext context, int eventId) {
  if (eventId <= 0) return;
  context.push('/events/$eventId');
}

/// The club's page. A club without an id cannot be opened by the app's
/// club page, so nothing happens.
void openDiscoverClub(
  BuildContext context, {
  required int id,
  String? slug,
  required String name,
}) {
  if (id <= 0) return;
  context.push('/clubs/$id', extra: {'clubSlug': slug ?? '', 'clubName': name});
}

/// A post, with its comments.
void openDiscoverThread(BuildContext context, String threadId) =>
    context.push('/threads/${Uri.encodeComponent(threadId)}');
