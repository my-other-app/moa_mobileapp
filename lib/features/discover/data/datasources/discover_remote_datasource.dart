import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/event_filters.dart';
import 'package:finnet/features/threads/domain/entities/thread.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

final discoverRemoteDataSourceProvider =
    Provider<DiscoverRemoteDataSource>((ref) {
  return DiscoverRemoteDataSourceImpl(
    ref.watch(dioProvider),
    cache: ref.watch(apiCacheProvider),
  );
});

/// The calls behind the website's discovery, over the app's Dio.
///
/// Every path is public (`app/api/discover/router.py`,
/// `app/api/interests/router.py`). No coordinates are ever sent: the server
/// places the caller by their connection's address.
///
/// The front page and each list's first page are sent with the shared
/// cache policy, so the answer is saved (and revalidated by ETag) and the
/// `saved*` reads can draw it at once next time, or offline. Later pages
/// are not saved.
abstract class DiscoverRemoteDataSource {
  Future<DiscoverHome> home();
  Future<DiscoverHome?> savedHome();

  Future<EventResults> events(EventFilters filters, PageRequest page);
  Future<EventResults?> savedEvents(EventFilters filters);

  Future<CalendarMonth> calendar(EventFilters filters, String month);
  Future<CalendarMonth?> savedCalendar(EventFilters filters, String month);

  Future<ClubResults> clubs(ClubFilters filters, PageRequest page);
  Future<ClubResults?> savedClubs(ClubFilters filters);

  Future<DiscoverPage<Thread>> threads(PageRequest page);
  Future<DiscoverPage<Thread>?> savedThreads();

  Future<Topic> topic(String slug);
  Future<Topic?> savedTopic(String slug);

  Future<List<DiscoverEvent>> followingEvents({required int limit});
  Future<List<DiscoverEvent>?> savedFollowingEvents({required int limit});
}

class DiscoverRemoteDataSourceImpl implements DiscoverRemoteDataSource {
  DiscoverRemoteDataSourceImpl(this._dio, {ApiCache? cache}) : _cache = cache;

  final Dio _dio;
  final ApiCache? _cache;

  ApiCache get _saved => _cache ?? ApiCache.instance;

  static const homePath = '/discover/home';
  static const eventsPath = '/discover/events';
  static const calendarPath = '/discover/calendar';
  static const clubsPath = '/discover/clubs';
  static const threadsPath = '/discover/threads';
  static const followingPath = '/events/list';

  static String topicPath(String slug) =>
      '/interests/topics/${Uri.encodeComponent(slug)}';

  static Map<String, dynamic> followingQuery(int limit) => {
        'is_following': true,
        'is_ended': false,
        'offset': 0,
        'limit': limit,
      };

  static Options _options({required bool save}) =>
      Options(extra: save ? CachePolicy.shared.extra : const {});

  Future<dynamic> _get(String path,
      {Map<String, dynamic>? query, bool save = true}) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: query,
      options: _options(save: save),
    );
    return response.data;
  }

  Future<dynamic> _read(String path, [Map<String, dynamic>? query]) =>
      _saved.savedAnswer(_dio, path, query: query);

  @override
  Future<DiscoverHome> home() async => parseHome(await _get(homePath));

  @override
  Future<DiscoverHome?> savedHome() async {
    final data = await _read(homePath);
    return data == null ? null : parseHome(data);
  }

  @override
  Future<EventResults> events(EventFilters filters, PageRequest page) async =>
      parseEventResults(await _get(
        eventsPath,
        query: filters.eventsQuery(page),
        save: page.isFirst,
      ));

  @override
  Future<EventResults?> savedEvents(EventFilters filters) async {
    final data = await _read(eventsPath, filters.eventsQuery());
    return data == null ? null : parseEventResults(data);
  }

  @override
  Future<CalendarMonth> calendar(EventFilters filters, String month) async =>
      parseCalendar(
        await _get(calendarPath, query: filters.calendarQuery(month)),
        month: month,
      );

  @override
  Future<CalendarMonth?> savedCalendar(
      EventFilters filters, String month) async {
    final data = await _read(calendarPath, filters.calendarQuery(month));
    return data == null ? null : parseCalendar(data, month: month);
  }

  @override
  Future<ClubResults> clubs(ClubFilters filters, PageRequest page) async =>
      parseClubResults(await _get(
        clubsPath,
        query: filters.clubsQuery(page),
        save: page.isFirst,
      ));

  @override
  Future<ClubResults?> savedClubs(ClubFilters filters) async {
    final data = await _read(clubsPath, filters.clubsQuery());
    return data == null ? null : parseClubResults(data);
  }

  @override
  Future<DiscoverPage<Thread>> threads(PageRequest page) async =>
      parseThreadsPage(
          await _get(threadsPath, query: page.query, save: page.isFirst));

  @override
  Future<DiscoverPage<Thread>?> savedThreads() async {
    final data = await _read(threadsPath, const PageRequest.first().query);
    return data == null ? null : parseThreadsPage(data);
  }

  @override
  Future<Topic> topic(String slug) async {
    final topic = parseTopic(await _get(topicPath(slug)));
    if (topic == null) {
      throw const FormatException('The topic came back without its name.');
    }
    return topic;
  }

  @override
  Future<Topic?> savedTopic(String slug) async =>
      parseTopic(await _read(topicPath(slug)));

  List<DiscoverEvent> _following(Object? body) {
    final o = jsonObject(body);
    final items = o?['items'];
    return [
      if (items is List)
        for (final item in items)
          if (parseListEvent(item) case final event?) event,
    ];
  }

  @override
  Future<List<DiscoverEvent>> followingEvents({required int limit}) async =>
      _following(await _get(followingPath, query: followingQuery(limit)));

  @override
  Future<List<DiscoverEvent>?> savedFollowingEvents(
      {required int limit}) async {
    final data = await _read(followingPath, followingQuery(limit));
    return data == null ? null : _following(data);
  }
}
