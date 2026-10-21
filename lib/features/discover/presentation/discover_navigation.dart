import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/shared/widgets/poster_hero.dart';

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

/// The event's page. With [posterHero], the tapped card's poster (tagged
/// so, and drawn from [hint]) flies into the page's.
void openDiscoverEvent(
  BuildContext context,
  int eventId, {
  String? posterHero,
  PosterHint? hint,
}) {
  if (eventId <= 0) return;
  context.push(
    '/events/$eventId',
    extra: posterHero == null
        ? null
        : {'posterHero': posterHero, if (hint != null) 'posterHint': hint},
  );
}

/// The club's page, by id, or by slug for a club the server sent without
/// one (the page finds it). With neither, nothing happens.
void openDiscoverClub(
  BuildContext context, {
  required int id,
  String? slug,
  required String name,
}) {
  final s = slug?.trim() ?? '';
  if (id <= 0 && s.isEmpty) return;
  final ref = id > 0 ? '$id' : Uri.encodeComponent(s);
  context.push('/clubs/$ref', extra: {'clubSlug': s, 'clubName': name});
}

/// A post, with its comments.
void openDiscoverThread(BuildContext context, String threadId) =>
    context.push('/threads/${Uri.encodeComponent(threadId)}');
