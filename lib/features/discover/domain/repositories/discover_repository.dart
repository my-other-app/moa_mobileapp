import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

/// The public discovery API -- what the website is built on -- for the app.
///
/// Everything works signed out. Signed in, the token goes along, which only
/// changes whether a post shows as liked.
///
/// The `saved*` reads are the copy last saved on this phone (no network),
/// for the screens to draw at once: the front page and the first page of
/// each list.
abstract class DiscoverRepository {
  /// `GET /discover/home`, placing the caller by their connection.
  Future<Result<DiscoverHome>> home();
  Future<DiscoverHome?> savedHome();

  /// `GET /discover/events`.
  Future<Result<EventResults>> events(EventFilters filters, PageRequest page);
  Future<EventResults?> savedEvents(EventFilters filters);

  /// `GET /discover/calendar` for [month] (`YYYY-MM`).
  Future<Result<CalendarMonth>> calendar(EventFilters filters, String month);
  Future<CalendarMonth?> savedCalendar(EventFilters filters, String month);

  /// `GET /discover/clubs`.
  Future<Result<ClubResults>> clubs(ClubFilters filters, PageRequest page);
  Future<ClubResults?> savedClubs(ClubFilters filters);

  /// `GET /discover/threads`: every club's newest posts.
  Future<Result<DiscoverPage<Thread>>> threads(PageRequest page);
  Future<DiscoverPage<Thread>?> savedThreads();

  /// `GET /interests/topics/{slug}`: one topic with its counts. Fails with
  /// code '404' for a slug no live topic has.
  Future<Result<Topic>> topic(String slug);
  Future<Topic?> savedTopic(String slug);

  /// The first page of the person's followed clubs' upcoming events
  /// (`/events/list?is_following=true`, the FOLLOWING tab's): signed in
  /// only.
  Future<Result<List<DiscoverEvent>>> followingEvents({int limit = 10});
  Future<List<DiscoverEvent>?> savedFollowingEvents({int limit = 10});
}
