import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';

final pushSettingsRemoteDataSourceProvider =
    Provider<PushSettingsRemoteDataSource>(
  (ref) => PushSettingsRemoteDataSourceImpl(ref.watch(dioProvider),
      cache: ref.watch(apiCacheProvider)),
);

/// `/notifications/settings` and `/notifications/mutes/clubs/{id}`. Every
/// change goes through the app's Dio, whose TopicChangeInterceptor then has
/// the push service reconcile the device's FCM topics.
abstract class PushSettingsRemoteDataSource {
  Future<PushSwitches?> switches();

  /// The switches as last saved on this phone, or null. No network.
  Future<PushSwitches?> savedSwitches();

  Future<PushSwitches> setSwitches(Map<String, bool> changes);
  Future<bool?> isClubMuted(int clubId);
  Future<void> setClubMuted(int clubId, {required bool muted});
}

class PushSettingsRemoteDataSourceImpl implements PushSettingsRemoteDataSource {
  PushSettingsRemoteDataSourceImpl(this._dio, {ApiCache? cache})
      : _cache = cache;

  final Dio _dio;
  final ApiCache? _cache;

  ApiCache get _store => _cache ?? ApiCache.instance;

  static const _settings = '/notifications/settings';

  @override
  Future<PushSwitches?> switches() async {
    final data = await _orNothing(() => _dio.get<dynamic>(
          _settings,
          // Saved, encrypted and never pruned for room: Settings draws the
          // switches from this copy at once -- and offline -- rather than
          // waiting a round trip to us-east-1 with the section blank.
          options: Options(extra: CachePolicy.personalKept.extra),
        ));
    return data == null ? null : _switchesFrom(data);
  }

  @override
  Future<PushSwitches?> savedSwitches() async {
    final data = await _store.savedAnswer(_dio, _settings,
        scope: CacheScope.personal);
    return data is Map ? _switchesFrom(data) : null;
  }

  @override
  Future<PushSwitches> setSwitches(Map<String, bool> changes) async {
    final response = await _dio.patch<dynamic>(_settings, data: changes);
    final saved = _switchesFrom(response.data);
    // The answer is the switches as the server now keeps them: the saved
    // copy becomes that, so the next Settings opens on the change.
    await _store.saveAnswer(_dio, _settings, _toJson(saved),
        scope: CacheScope.personal, keep: true);
    return saved;
  }

  @override
  Future<bool?> isClubMuted(int clubId) async {
    final data = await _orNothing(
        () => _dio.get<dynamic>('/notifications/mutes/clubs/$clubId'));
    if (data is! Map) return null;
    return data['muted'] == true;
  }

  @override
  Future<void> setClubMuted(int clubId, {required bool muted}) async {
    final path = '/notifications/mutes/clubs/$clubId';
    if (muted) {
      await _dio.put<dynamic>(path);
    } else {
      await _dio.delete<dynamic>(path);
    }
  }

  /// The body, or null when the server has no such endpoint (404, 405).
  Future<Object?> _orNothing(Future<Response<dynamic>> Function() call) async {
    try {
      return (await call()).data;
    } catch (e) {
      final status = statusCodeOf(e) ??
          (e is DioException ? e.response?.statusCode : null);
      if (status == 404 || status == 405) return null;
      rethrow;
    }
  }

  static Map<String, bool> _toJson(PushSwitches s) =>
      {'clubs': s.clubs, 'topics': s.topics, 'platform': s.platform};

  static PushSwitches _switchesFrom(Object? data) {
    final map = data is Map ? data : const {};
    return PushSwitches(
      clubs: map['clubs'] != false,
      topics: map['topics'] != false,
      platform: map['platform'] != false,
    );
  }
}
