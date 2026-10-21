import 'package:equatable/equatable.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_club.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';

/// A category with how many upcoming events it has (the events list's
/// facets, the home page's categories).
class CategoryCount extends Equatable {
  const CategoryCount({required this.id, required this.name, this.upcoming});

  final int id;
  final String name;

  /// Null when not counted.
  final int? upcoming;

  @override
  List<Object?> get props => [id, name, upcoming];
}

/// A topic beside the events list, with what is on in it.
class TopicFacet extends Equatable {
  const TopicFacet({
    required this.id,
    required this.slug,
    required this.name,
    this.color,
    this.upcoming = 0,
  });

  final int id;
  final String slug;
  final String name;
  final String? color;
  final int upcoming;

  @override
  List<Object?> get props => [id, slug, name, color, upcoming];
}

/// An interest beside the clubs list, with how many clubs pick it.
class InterestCount extends Equatable {
  const InterestCount({required this.id, required this.name, this.clubs});

  final int id;
  final String name;
  final int? clubs;

  @override
  List<Object?> get props => [id, name, clubs];
}

/// A page of `/discover/events`, with where the server placed the caller
/// and the facets beside the list.
class EventResults extends Equatable {
  const EventResults({
    this.page = const DiscoverPage<DiscoverEvent>(),
    this.where = DiscoverWhere.unknown,
    this.categories = const [],
    this.topics = const [],
  });

  final DiscoverPage<DiscoverEvent> page;
  final DiscoverWhere where;
  final List<CategoryCount> categories;
  final List<TopicFacet> topics;

  /// The page as asked about [place]'s point: under its name. Without one,
  /// as the server placed the caller.
  EventResults about(DiscoverWhere? place) => place == null
      ? this
      : EventResults(
          page: page, where: place, categories: categories, topics: topics);

  @override
  List<Object?> get props => [page, where, categories, topics];
}

/// A page of `/discover/clubs`.
class ClubResults extends Equatable {
  const ClubResults({
    this.page = const DiscoverPage<DiscoverClub>(),
    this.where = DiscoverWhere.unknown,
    this.interests = const [],
  });

  final DiscoverPage<DiscoverClub> page;
  final DiscoverWhere where;
  final List<InterestCount> interests;

  /// As [EventResults.about].
  ClubResults about(DiscoverWhere? place) => place == null
      ? this
      : ClubResults(page: page, where: place, interests: interests);

  @override
  List<Object?> get props => [page, where, interests];
}

/// The numbers on the front page.
class DiscoverStats extends Equatable {
  const DiscoverStats(
      {this.upcomingEvents = 0, this.clubs = 0, this.cities = 0});

  final int upcomingEvents;
  final int clubs;
  final int cities;

  @override
  List<Object?> get props => [upcomingEvents, clubs, cities];
}

/// `/discover/home`: what is on near the caller, this week, online and
/// popular; the clubs (nearest, or most followed); the clubs' latest posts.
///
/// [nearEvents], [nearClubs] and [moreClubs] are what the page shows: only
/// what is within [nearKm] is called near.
class DiscoverHome extends Equatable {
  const DiscoverHome({
    this.where = DiscoverWhere.unknown,
    this.near = const [],
    this.thisWeek = const [],
    this.online = const [],
    this.popular = const [],
    this.categories = const [],
    this.clubs = const [],
    this.threads = const [],
    this.stats = const DiscoverStats(),
  });

  final DiscoverWhere where;
  final List<DiscoverEvent> near;
  final List<DiscoverEvent> thisWeek;
  final List<DiscoverEvent> online;
  final List<DiscoverEvent> popular;
  final List<CategoryCount> categories;
  final List<DiscoverClub> clubs;
  final List<Thread> threads;
  final DiscoverStats stats;

  /// Nothing at all to show.
  bool get isEmpty =>
      near.isEmpty &&
      thisWeek.isEmpty &&
      online.isEmpty &&
      popular.isEmpty &&
      clubs.isEmpty &&
      threads.isEmpty;

  /// The near rail: in-person events within [nearKm]. The server sends
  /// only those; anything else it might add is near no one, and is left
  /// out rather than shown as near.
  List<DiscoverEvent> get nearEvents => [
        if (where.isPlaced)
          for (final e in near)
            if (!e.isOnline && isNearby(e.distanceKm)) e,
      ];

  /// "Clubs near you": the clubs within [nearKm].
  List<DiscoverClub> get nearClubs => [
        if (where.isPlaced)
          for (final c in clubs)
            if (isNearby(c.distanceKm)) c,
      ];

  /// The other clubs the server sent. Placed, it sends the nearest few
  /// however far (near Thiruvananthapuram: two within 11 km, then six from
  /// 126 to 415 km off), so these are further away: "More clubs". Not
  /// placed, they are the most followed.
  List<DiscoverClub> get moreClubs => [
        for (final c in clubs)
          if (!where.isPlaced || !isNearby(c.distanceKm)) c,
      ];

  /// The page as asked about [place]'s point: under its name. Without one,
  /// as the server placed the caller.
  DiscoverHome about(DiscoverWhere? place) => place == null
      ? this
      : DiscoverHome(
          where: place,
          near: near,
          thisWeek: thisWeek,
          online: online,
          popular: popular,
          categories: categories,
          clubs: clubs,
          threads: threads,
          stats: stats,
        );

  @override
  List<Object?> get props => [
        where,
        near,
        thisWeek,
        online,
        popular,
        categories,
        clubs,
        threads,
        stats
      ];
}

/// How many events each day of a month has (`/discover/calendar`): days in
/// India, only days with something on.
class CalendarMonth extends Equatable {
  const CalendarMonth({required this.month, this.days = const {}});

  /// `YYYY-MM`.
  final String month;

  /// `YYYY-MM-DD` to a count above zero.
  final Map<String, int> days;

  int countOn(String day) => days[day] ?? 0;

  /// The month's days with something on, in order.
  List<String> get busyDays => (days.keys.toList()..sort());

  /// Events touching the month's days (one over three days counts thrice).
  int get total => days.values.fold(0, (sum, n) => sum + n);

  @override
  List<Object?> get props => [month, days];
}
