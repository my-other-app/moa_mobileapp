import 'dart:math' as math;

import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/discover/domain/discover_days.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_club.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/threads/data/models/thread_models.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/topics/data/models/topic_model.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

// Reading the discover API's answers (`app/api/discover/schemas.py`) without
// trusting any field: a field left out becomes an empty value instead of a
// crash, and a row without an id is dropped rather than losing the list.
// The website reads them the same way (`src/api/parse.js`).

String? _str(Object? value) {
  final s = jsonString(value)?.trim();
  return s == null || s.isEmpty ? null : s;
}

int _count(Object? value) => math.max(0, jsonInt(value) ?? 0);

double? _finite(Object? value) {
  final d = jsonDouble(value);
  return d != null && d.isFinite ? d : null;
}

/// A positive amount or nothing: a fee or capacity of 0 means "not set".
double? _positive(Object? value) {
  final d = _finite(value);
  return d != null && d > 0 ? d : null;
}

/// An image value worth keeping: the S3 dict or a non-empty URL.
Object? _image(Object? value) {
  if (value is String) return value.trim().isEmpty ? null : value.trim();
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

DateTime? _instant(Object? value) {
  final s = _str(value);
  return s == null ? null : DateTime.tryParse(s);
}

const _statuses = {
  'upcoming': DiscoverEventStatus.upcoming,
  'closing_soon': DiscoverEventStatus.closingSoon,
  'full': DiscoverEventStatus.full,
  'live': DiscoverEventStatus.live,
  'ended': DiscoverEventStatus.ended,
};

List<Topic> _topics(Object? value) =>
    value is List ? TopicModel.listFromJson(value) : const [];

/// `where`: the place the server put the caller in.
DiscoverWhere parseWhere(Object? value) {
  final o = jsonObject(value) ?? const <String, dynamic>{};
  final lat = _finite(o['lat']);
  final lng = _finite(o['lng']);
  final source = switch (o['source']) {
    'browser' => WhereSource.browser,
    'ip' => WhereSource.ip,
    'none' => WhereSource.none,
    _ => lat != null && lng != null ? WhereSource.ip : WhereSource.none,
  };
  return DiscoverWhere(
    city: _str(o['city']),
    region: _str(o['region']),
    lat: lat,
    lng: lng,
    source: source,
  );
}

DiscoverClubRef? parseClubRef(Object? value) {
  final o = jsonObject(value);
  if (o == null) return null;
  final id = jsonInt(o['id']);
  final name = _str(o['name']);
  if (id == null && name == null) return null;
  return DiscoverClubRef(
    id: id ?? 0,
    name: name ?? 'A club',
    slug: _str(o['slug']),
    logo: _image(o['logo']),
  );
}

DiscoverCategoryRef? _category(Object? value) {
  final o = jsonObject(value);
  final id = jsonInt(o?['id']);
  if (o == null || id == null) return null;
  return DiscoverCategoryRef(id: id, name: _str(o['name']) ?? '');
}

/// An event card from `/discover/*`; null without an id.
DiscoverEvent? parseEvent(Object? value) {
  final o = jsonObject(value);
  final id = jsonInt(o?['id']);
  if (o == null || id == null) return null;
  return DiscoverEvent(
    id: id,
    name: _str(o['name']) ?? 'Untitled event',
    slug: _str(o['slug']),
    poster: _image(o['poster']),
    startsAt: _instant(o['starts_at']),
    endsAt: _instant(o['ends_at']),
    locationName: _str(o['location_name']),
    isOnline: jsonBool(o['is_online']) ?? false,
    distanceKm: _finite(o['distance_km']),
    hasFee: jsonBool(o['has_fee']) ?? false,
    fee: _positive(o['fee']),
    category: _category(o['category']),
    club: parseClubRef(o['club']),
    going: _count(o['going']),
    capacity: _positive(o['capacity'])?.round(),
    status: _statuses[o['status']] ?? DiscoverEventStatus.upcoming,
    summary: _str(o['summary']),
    topics: _topics(o['topics']),
  );
}

/// An event from `/events/list` (the FOLLOWING tab's shape: `event_datetime`
/// and `duration` rather than `starts_at` and `ends_at`), as a card.
DiscoverEvent? parseListEvent(Object? value) {
  final o = jsonObject(value);
  final id = jsonInt(o?['id']);
  if (o == null || id == null) return null;
  final start = _instant(o['event_datetime']);
  final hours = _finite(o['duration']);
  return DiscoverEvent(
    id: id,
    name: _str(o['name']) ?? 'Untitled event',
    slug: _str(o['slug']),
    poster: _image(o['poster']),
    startsAt: start,
    endsAt: start != null && hours != null && hours > 0
        ? start.add(Duration(minutes: (hours * 60).round()))
        : null,
    locationName: _str(o['location_name']),
    isOnline: jsonBool(o['is_online']) ?? false,
    hasFee: jsonBool(o['has_fee']) ?? false,
    category: _category(o['category']),
    club: parseClubRef(o['club']),
  );
}

/// A club card; null with neither an id nor a slug.
DiscoverClub? parseClub(Object? value) {
  final o = jsonObject(value);
  if (o == null) return null;
  final id = jsonInt(o['id']);
  final slug = _str(o['slug']);
  if (id == null && slug == null) return null;
  final interests = o['interests'];
  return DiscoverClub(
    id: id ?? 0,
    name: _str(o['name']) ?? 'A club',
    slug: slug,
    logo: _image(o['logo']),
    cover: _image(o['cover']),
    tagline: _str(o['tagline']),
    locationName: _str(o['location_name']),
    followers: _count(o['followers']),
    upcomingEvents: _count(o['upcoming_events']),
    interests: interests is List
        ? [
            for (final i in interests)
              if ((i is String ? _str(i) : _str(jsonObject(i)?['name']))
                  case final name?)
                name,
          ]
        : const [],
    topics: _topics(o['topics']),
    distanceKm: _finite(o['distance_km']),
  );
}

/// A post from the clubs, as the threads feature reads one; null without an
/// id (it could not be opened).
Thread? parseThread(Object? value) {
  final o = jsonObject(value);
  if (o == null) return null;
  final model = ThreadModel.fromJson(o);
  return model.id.isEmpty ? null : model.toEntity();
}

List<T> _list<T>(Object? value, T? Function(Object?) read) => [
      if (value is List)
        for (final item in value)
          if (read(item) case final T row) row,
    ];

CategoryCount? _categoryCount(Object? value) {
  final o = jsonObject(value);
  final id = jsonInt(o?['id']);
  if (o == null || id == null) return null;
  final upcoming = o['upcoming'];
  return CategoryCount(
    id: id,
    name: _str(o['name']) ?? '',
    upcoming: upcoming == null ? null : _count(upcoming),
  );
}

TopicFacet? _topicFacet(Object? value) {
  final o = jsonObject(value);
  final id = jsonInt(o?['id']);
  final slug = _str(o?['slug']);
  final name = _str(o?['name']);
  if (o == null || id == null || slug == null || name == null) return null;
  return TopicFacet(
    id: id,
    slug: slug,
    name: name,
    color: _str(o['color']),
    upcoming: _count(o['upcoming']),
  );
}

InterestCount? _interestCount(Object? value) {
  final o = jsonObject(value);
  final id = jsonInt(o?['id']);
  if (o == null || id == null) return null;
  final clubs = o['clubs'];
  return InterestCount(
    id: id,
    name: _str(o['name']) ?? '',
    clubs: clubs == null ? null : _count(clubs),
  );
}

/// The envelope every list shares. `cursored` when the server sent
/// `next_cursor` at all (even null: then this is the last page).
DiscoverPage<T> parsePage<T>(Object? body, T? Function(Object?) read) {
  final o = jsonObject(body) ?? const <String, dynamic>{};
  final items = _list(o['items'], read);
  final cursor = _str(o['next_cursor']);
  return DiscoverPage<T>(
    items: items,
    total: math.max(items.length, jsonInt(o['total']) ?? items.length),
    capped: jsonBool(o['total_capped']) ?? false,
    offset: _count(o['offset']),
    limit: jsonInt(o['limit']) ?? discoverPageSize,
    cursored: o.containsKey('next_cursor'),
    cursor: cursor,
  );
}

EventResults parseEventResults(Object? body) {
  final o = jsonObject(body) ?? const <String, dynamic>{};
  return EventResults(
    page: parsePage(o, parseEvent),
    where: parseWhere(o['where']),
    categories: _list(o['categories'], _categoryCount),
    topics: _list(o['topics'], _topicFacet),
  );
}

ClubResults parseClubResults(Object? body) {
  final o = jsonObject(body) ?? const <String, dynamic>{};
  return ClubResults(
    page: parsePage(o, parseClub),
    where: parseWhere(o['where']),
    interests: _list(o['interests'], _interestCount),
  );
}

DiscoverPage<Thread> parseThreadsPage(Object? body) =>
    parsePage(body, parseThread);

DiscoverHome parseHome(Object? body) {
  final o = jsonObject(body) ?? const <String, dynamic>{};
  final stats = jsonObject(o['stats']) ?? const <String, dynamic>{};
  return DiscoverHome(
    where: parseWhere(o['where']),
    near: _list(o['near'], parseEvent),
    thisWeek: _list(o['this_week'], parseEvent),
    online: _list(o['online'], parseEvent),
    popular: _list(o['popular'], parseEvent),
    categories: _list(o['categories'], _categoryCount),
    clubs: _list(o['clubs'], parseClub),
    threads: _list(o['threads'], parseThread),
    stats: DiscoverStats(
      upcomingEvents: _count(stats['upcoming_events']),
      clubs: _count(stats['clubs']),
      cities: _count(stats['cities']),
    ),
  );
}

/// `{month, days: {"YYYY-MM-DD": n}}`: days with none, and anything that is
/// not a day of a real calendar, are left out.
CalendarMonth parseCalendar(Object? body, {required String month}) {
  final o = jsonObject(body) ?? const <String, dynamic>{};
  final days = <String, int>{};
  final raw = jsonObject(o['days']) ?? const <String, dynamic>{};
  raw.forEach((day, count) {
    final n = jsonInt(count) ?? 0;
    if (isDay(day) && n > 0) days[day] = n;
  });
  final sent = jsonString(o['month']);
  return CalendarMonth(month: isMonth(sent) ? sent! : month, days: days);
}

/// One topic (`/interests/topics/{slug}`); null when the body is not one.
Topic? parseTopic(Object? body) {
  final o = jsonObject(body);
  if (o == null || jsonInt(o['id']) == null) return null;
  final topic = TopicModel.fromJson(o).toEntity();
  return topic.name.trim().isEmpty ? null : topic;
}
