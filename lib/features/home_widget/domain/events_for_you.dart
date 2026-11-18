import 'package:intl/intl.dart';

import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/home_widget/domain/next_up.dart'
    show inIndia, indiaTimeOfDay, siteLink;

// "For you", the events home-screen widget (docs/HOME_WIDGETS.md): what is
// on this week -- the person's topics first, then near them -- and, when
// that is not enough, the platform's popular events.
//
// Everything in it is public: the events of the discover front page
// (`GET /discover/home`, the same answer for anyone at that place), and, so
// the widget can ask that page again by itself while the app is closed,
// where to ask it -- the public API's address, the city and its point, and
// the ids of the person's topics. No sign-in token, nothing about a ticket
// or a registration. The widgets (ForYouData.kt, ForYouData.swift) pick
// from the page by the same rules as [pickForYou].

/// How many events the widgets are given: the large widget's four, and two
/// to move on to when one ends while the app stays closed.
const forYouLimit = 6;

/// How many the medium and the large widget list.
const forYouMediumRows = 2;
const forYouLargeRows = 4;

/// The name, on at most two lines: longer is cut.
const _nameLimit = 90;

/// Within this week: starting in the next seven days (the server's
/// `this_week`).
const _week = Duration(days: 7);

/// What the widget calls its list, by why the events are there.
enum ForYouHeader {
  /// At least one is in the person's topics.
  forYou('For you'),

  /// None in their topics, but at least one this week near them.
  nearYou('This week near you'),

  /// This week, anywhere.
  thisWeek('This week'),

  /// Nothing this week: the platform's popular events.
  popular('Popular');

  const ForYouHeader(this.words);

  /// As the widget shows it, and as the JSON carries it.
  final String words;
}

/// What the widget may ask the public front page about, kept beside the
/// events so it can ask again by itself: the API's address, the place (a
/// city and its point, to two decimals: the city, not the phone), and the
/// ids of the person's topics. Nothing else.
class ForYouAsk {
  const ForYouAsk({
    required this.api,
    this.topics = const [],
    this.city,
    this.lat,
    this.lng,
  });

  /// The public API's base, `https://api.myotherapp.in/api/v1`. The widgets
  /// ask only an https one.
  final String api;

  /// The person's topics (interest categories), by id; empty signed out.
  final List<int> topics;

  /// The city the place is in, when known.
  final String? city;
  final double? lat;
  final double? lng;

  /// About [place] (the discover lists' place), for someone whose
  /// interests are under [topics].
  factory ForYouAsk.about({
    required String api,
    DiscoverWhere? place,
    Iterable<int> topics = const [],
  }) {
    final point = place?.point;
    final city = place?.city?.trim();
    final sorted = topics.where((t) => t > 0).toSet().toList()..sort();
    return ForYouAsk(
      api: api,
      topics: List.unmodifiable(sorted),
      city: city == null || city.isEmpty ? null : city,
      lat: point == null ? null : _twoPlaces(point.lat),
      lng: point == null ? null : _twoPlaces(point.lng),
    );
  }

  /// The same, without the person's topics (signed out).
  ForYouAsk get withoutTopics =>
      ForYouAsk(api: api, city: city, lat: lat, lng: lng);

  static double _twoPlaces(double v) => (v * 100).round() / 100;

  Map<String, Object?> toJson() => {
        'api': api,
        'topics': topics,
        if (city != null) 'city': city,
        if (lat != null && lng != null) ...{'lat': lat, 'lng': lng},
      };
}

/// One event on the widget.
class ForYouEvent {
  const ForYouEvent({
    required this.id,
    required this.name,
    required this.link,
    required this.startsAt,
    this.endsAt,
    this.club,
    this.place,
    this.topics = const {},
    this.distanceKm,
    this.isOnline = false,
  });

  final int id;
  final String name;

  /// The event's page: `https://myotherapp.in/events/{slug}` (or its id).
  final String link;

  /// UTC.
  final DateTime startsAt;
  final DateTime? endsAt;

  /// The club hosting it.
  final String? club;

  /// The venue, "Online", or null when not said.
  final String? place;

  /// Its topics' ids, to match against the person's. Not stored.
  final Set<int> topics;

  /// How far from the place asked about; null when online or unknown. Not
  /// stored.
  final double? distanceKm;
  final bool isOnline;

  /// A card of the front page as the widget lists it; null for one without
  /// a start (the front page has none).
  static ForYouEvent? fromDiscover(DiscoverEvent event) {
    final start = event.startsAt;
    if (start == null || event.id <= 0) return null;
    final slug = event.slug?.trim();
    final ref = slug == null || slug.isEmpty ? '${event.id}' : slug;
    final venue = event.locationName?.trim();
    final club = event.club?.name.trim();
    return ForYouEvent(
      id: event.id,
      name: _nameOf(event.name),
      link: siteLink('/events/${Uri.encodeComponent(ref)}'),
      startsAt: start.toUtc(),
      endsAt: event.endsAt?.toUtc(),
      club: club == null || club.isEmpty ? null : club,
      place: event.isOnline
          ? 'Online'
          : (venue == null || venue.isEmpty ? null : venue),
      topics: {for (final t in event.topics) t.id},
      distanceKm: event.distanceKm,
      isOnline: event.isOnline,
    );
  }

  /// Over at [now]: its end has passed (or, with no end, its start).
  bool isOverAt(DateTime now) => !now.isBefore(endsAt ?? startsAt);

  bool isThisWeekAt(DateTime now) => startsAt.isBefore(now.add(_week));

  bool isMineFor(ForYouAsk ask) => ask.topics.any(topics.contains);

  /// In person, within the server's "near" ([nearKm]) of the place asked
  /// about.
  bool get isNear => !isOnline && isNearby(distanceKm);

  /// What the widget is given: what it shows and where a tap goes.
  Map<String, Object?> toJson() {
    final india = inIndia(startsAt);
    return {
      'id': id,
      'name': name,
      'starts_at': startsAt.millisecondsSinceEpoch,
      if (endsAt != null) 'ends_at': endsAt!.millisecondsSinceEpoch,
      'weekday': DateFormat('EEE', 'en_US').format(india).toUpperCase(),
      'day': '${india.day}',
      'month': DateFormat('MMM', 'en_US').format(india).toUpperCase(),
      'time': indiaTimeOfDay(startsAt),
      'date': DateFormat('EEE, d MMM', 'en_US').format(india),
      if (club != null) 'club': club,
      if (place != null) 'place': place,
      'link': link,
    };
  }
}

/// What the widget lists, and what it calls the list.
class ForYouPick {
  const ForYouPick(this.header, this.events);

  /// Nothing on at all.
  static const empty = ForYouPick(null, []);

  /// Null when there is nothing to list.
  final ForYouHeader? header;
  final List<ForYouEvent> events;
}

/// What the widget lists from the front page's [thisWeek], [near] and
/// [popular] at [now], for [ask]:
///
/// 1. this week -- the events in the next seven days, from `this_week` and
///    the near ones in it -- the person's topics first, then those near
///    them, then the rest, each in date order;
/// 2. then the popular ones (`popular`, the server's order), the person's
///    topics first;
///
/// none over yet, each once, at most [limit]. The header says why the first
/// [shown] are there ([ForYouHeader]). The widgets follow these same rules
/// (ForYouData.kt, ForYouData.swift).
ForYouPick pickForYou({
  required List<ForYouEvent> thisWeek,
  List<ForYouEvent> near = const [],
  required List<ForYouEvent> popular,
  required ForYouAsk ask,
  required DateTime now,
  int limit = forYouLimit,
  int shown = forYouLargeRows,
}) {
  final seen = <int>{};
  final week = <ForYouEvent>[
    for (final e in [...thisWeek, ...near])
      if (!e.isOverAt(now) && e.isThisWeekAt(now) && seen.add(e.id)) e,
  ];
  // Date order; the server's order among equals.
  final indexed = [for (var i = 0; i < week.length; i++) (i, week[i])]
    ..sort((a, b) {
      final byDate = a.$2.startsAt.compareTo(b.$2.startsAt);
      return byDate != 0 ? byDate : a.$1.compareTo(b.$1);
    });
  int rank(ForYouEvent e) => e.isMineFor(ask) ? 0 : (e.isNear ? 1 : 2);
  final ranked = [for (final x in indexed) x.$2];
  final weekOrdered = [
    for (final r in [0, 1, 2])
      for (final e in ranked)
        if (rank(e) == r) e,
  ];
  final more = [
    for (final e in popular)
      if (!e.isOverAt(now) && seen.add(e.id)) e,
  ];
  final popularOrdered = [
    for (final e in more)
      if (e.isMineFor(ask)) e,
    for (final e in more)
      if (!e.isMineFor(ask)) e,
  ];
  final picked = [...weekOrdered, ...popularOrdered].take(limit).toList();
  if (picked.isEmpty) return ForYouPick.empty;
  return ForYouPick(headerFor(picked.take(shown), ask, now), picked);
}

/// What the widget calls a list beginning with [first], for [ask].
ForYouHeader headerFor(
    Iterable<ForYouEvent> first, ForYouAsk ask, DateTime now) {
  if (first.any((e) => e.isMineFor(ask))) return ForYouHeader.forYou;
  if (first.any((e) => e.isNear && e.isThisWeekAt(now))) {
    return ForYouHeader.nearYou;
  }
  if (first.any((e) => e.isThisWeekAt(now))) return ForYouHeader.thisWeek;
  return ForYouHeader.popular;
}

/// [pickForYou] on the front page as the app read it.
ForYouPick pickFromHome(DiscoverHome home, ForYouAsk ask, DateTime now) {
  List<ForYouEvent> cards(List<DiscoverEvent> events) => [
        for (final e in events)
          if (ForYouEvent.fromDiscover(e) case final card?) card,
      ];
  return pickForYou(
    thisWeek: cards(home.thisWeek),
    near: cards(home.nearEvents),
    popular: cards(home.popular),
    ask: ask,
    now: now,
  );
}

/// The widget's two faces.
enum ForYouState {
  /// Events to list.
  events('events'),

  /// Nothing on (or nothing read yet): a calm "Find events".
  empty('empty');

  const ForYouState(this.wire);
  final String wire;
}

/// Find events: the app's events directory (the website's `/events`).
final forYouSeeAllLink = siteLink('/events');

/// Everything the widget is given.
class ForYouSnapshot {
  const ForYouSnapshot({
    required this.pick,
    required this.ask,
    required this.fetchedAt,
  });

  /// Nothing read yet, to ask [ask] about: the widget asks the front page
  /// itself on its next draw.
  factory ForYouSnapshot.unread(ForYouAsk ask) => ForYouSnapshot(
      pick: ForYouPick.empty,
      ask: ask,
      fetchedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));

  final ForYouPick pick;
  final ForYouAsk ask;

  /// When the events were read; the widgets ask again a few hours after.
  final DateTime fetchedAt;

  ForYouState get state =>
      pick.events.isEmpty ? ForYouState.empty : ForYouState.events;

  /// The JSON the widgets read (`events_for_you`, version 1). A widget that
  /// finds a version it doesn't know shows "Find events" and asks again.
  Map<String, Object?> toJson() => {
        'v': 1,
        'state': state.wire,
        if (pick.header != null) 'header': pick.header!.words,
        'items': [for (final e in pick.events) e.toJson()],
        'see_all': forYouSeeAllLink,
        'ask': ask.toJson(),
        'fetched_at': fetchedAt.millisecondsSinceEpoch,
      };
}

String _nameOf(String name) {
  var shown = name.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (shown.isEmpty) return 'Event';
  if (shown.length > _nameLimit) {
    shown = shown.substring(0, _nameLimit).trimRight();
  }
  return shown;
}
