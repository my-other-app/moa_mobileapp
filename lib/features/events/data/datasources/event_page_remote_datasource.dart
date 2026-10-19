import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/json_read.dart';

final eventPageRemoteDataSourceProvider =
    Provider<EventPageRemoteDataSource>((ref) {
  return EventPageRemoteDataSourceImpl(
    ref.watch(dioProvider),
    cache: ref.watch(apiCacheProvider),
  );
});

/// The public reads the event page makes beside `/events/info`.
abstract class EventPageRemoteDataSource {
  /// `GET /discover/events/{ref}` (a slug or an id): what the website's
  /// event page shows. Public and the same for everyone, so it is sent
  /// without the person's token and saved as a shared answer. Throws a 404
  /// for an event the public can't see (a draft, an unverified club's).
  Future<EventPageDetails?> fetchPage(String ref);

  /// The page last saved on this phone for [ref], or null. No network.
  Future<EventPageDetails?> savedPage(String ref);

  /// `GET /events/{id}/competition/leaderboard`'s `enabled`: whether the
  /// event runs a competition, so the page and the ticket show the way to
  /// "Your team". Public; reads only (it never makes one).
  Future<bool> competitionEnabled(int eventId);
}

class EventPageRemoteDataSourceImpl implements EventPageRemoteDataSource {
  EventPageRemoteDataSourceImpl(this._dio, {ApiCache? cache}) : _cache = cache;

  final Dio _dio;
  final ApiCache? _cache;

  static String _path(String ref) =>
      '/discover/events/${Uri.encodeComponent(ref.trim())}';

  @override
  Future<EventPageDetails?> fetchPage(String ref) async {
    final response = await _dio.get<dynamic>(
      _path(ref),
      options: Options(extra: {
        'skipAuth': true,
        ...CachePolicy.shared.extra,
      }),
    );
    return EventPageDetails.fromJson(response.data);
  }

  @override
  Future<EventPageDetails?> savedPage(String ref) async {
    final data =
        await (_cache ?? ApiCache.instance).savedAnswer(_dio, _path(ref));
    return data == null ? null : EventPageDetails.fromJson(data);
  }

  @override
  Future<bool> competitionEnabled(int eventId) async {
    final response = await _dio.get<dynamic>(
      '/events/$eventId/competition/leaderboard',
      options: Options(extra: {'skipAuth': true}),
    );
    return jsonBool(jsonObject(response.data)?['enabled']) ?? false;
  }
}
