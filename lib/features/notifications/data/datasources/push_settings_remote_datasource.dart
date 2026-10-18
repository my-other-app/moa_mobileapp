import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';

final pushSettingsRemoteDataSourceProvider =
    Provider<PushSettingsRemoteDataSource>(
  (ref) => PushSettingsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

/// `/notifications/settings` and `/notifications/mutes/clubs/{id}`. Every
/// change goes through the app's Dio, whose TopicChangeInterceptor then has
/// the push service reconcile the device's FCM topics.
abstract class PushSettingsRemoteDataSource {
  Future<PushSwitches?> switches();
  Future<PushSwitches> setSwitches(Map<String, bool> changes);
  Future<bool?> isClubMuted(int clubId);
  Future<void> setClubMuted(int clubId, {required bool muted});
}

class PushSettingsRemoteDataSourceImpl implements PushSettingsRemoteDataSource {
  PushSettingsRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  @override
  Future<PushSwitches?> switches() async {
    final data =
        await _orNothing(() => _dio.get<dynamic>('/notifications/settings'));
    return data == null ? null : _switchesFrom(data);
  }

  @override
  Future<PushSwitches> setSwitches(Map<String, bool> changes) async {
    final response =
        await _dio.patch<dynamic>('/notifications/settings', data: changes);
    return _switchesFrom(response.data);
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

  static PushSwitches _switchesFrom(Object? data) {
    final map = data is Map ? data : const {};
    return PushSwitches(
      clubs: map['clubs'] != false,
      topics: map['topics'] != false,
      platform: map['platform'] != false,
    );
  }
}
