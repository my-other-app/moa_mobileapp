import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/discover/data/models/discover_models.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/domain/entities/discover_results.dart';
import 'package:finnet/features/discover/domain/entities/discover_where.dart';
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
/// `app/api/interests/router.py`). The lists are asked about [at], the
/// place the app keeps (`lat`, `lng`); without one, the server places the
/// caller by their connection's address.
///
/// The front page and each list's first page are sent with the shared
/// cache policy, so the answer is saved (and revalidated by ETag) and the
/// `saved*` reads can draw it at once next time, or offline. Later pages
/// are not saved. The point is part of what is asked, so each copy is kept
/// for its place: one place's copy is never drawn for another.
abstract class DiscoverRemoteDataSource {
  Future<DiscoverHome> home({DiscoverPoint? at});
  Future<DiscoverHome?> savedHome({DiscoverPoint? at});

  Future<EventResults> events(EventFilters filters, PageRequest page,
      {DiscoverPoint? at});
  Future<EventResults?> savedEvents(EventFilters filters, {DiscoverPoint? at});

  Future<CalendarMonth> calendar(EventFilters filters, String month,
      {DiscoverPoint? at});
  Future<CalendarMonth?> savedCalendar(EventFilters filters, String month,
      {DiscoverPoint? at});

  Future<ClubResults> clubs(ClubFilters filters, PageRequest page,
      {DiscoverPoint? at});
  Future<ClubResults?> savedClubs(ClubFilters filters, {DiscoverPoint? at});

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

  /// [query] about [at]: its `lat` and `lng`.
  static Map<String, dynamic> about(DiscoverPoint? at,
          [Map<String, dynamic> query = const {}]) =>
      at == null ? query : {...query, 'lat': at.lat, 'lng': at.lng};

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
  Future<DiscoverHome> home({DiscoverPoint? at}) async =>
      parseHome(await _get(homePath, query: about(at)));

  @override
  Future<DiscoverHome?> savedHome({DiscoverPoint? at}) async {
    final data = await _read(homePath, about(at));
    return data == null ? null : parseHome(data);
  }

  @override
  Future<EventResults> events(EventFilters filters, PageRequest page,
          {DiscoverPoint? at}) async =>
      parseEventResults(await _get(
        eventsPath,
        query: about(at, filters.eventsQuery(page)),
        save: page.isFirst,
      ));

  @override
  Future<EventResults?> savedEvents(EventFilters filters,
      {DiscoverPoint? at}) async {
    final data = await _read(eventsPath, about(at, filters.eventsQuery()));
    return data == null ? null : parseEventResults(data);
  }

  @override
  Future<CalendarMonth> calendar(EventFilters filters, String month,
          {DiscoverPoint? at}) async =>
      parseCalendar(
        await _get(calendarPath,
            query: about(at, filters.calendarQuery(month))),
        month: month,
      );

  @override
  Future<CalendarMonth?> savedCalendar(EventFilters filters, String month,
      {DiscoverPoint? at}) async {
    final data =
        await _read(calendarPath, about(at, filters.calendarQuery(month)));
    return data == null ? null : parseCalendar(data, month: month);
  }

  @override
  Future<ClubResults> clubs(ClubFilters filters, PageRequest page,
          {DiscoverPoint? at}) async =>
      parseClubResults(await _get(
        clubsPath,
        query: about(at, filters.clubsQuery(page)),
        save: page.isFirst,
      ));

  @override
  Future<ClubResults?> savedClubs(ClubFilters filters,
      {DiscoverPoint? at}) async {
    final data = await _read(clubsPath, about(at, filters.clubsQuery()));
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
