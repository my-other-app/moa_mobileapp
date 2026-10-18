import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/features/notifications/data/datasources/push_settings_remote_datasource.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';
import 'package:finnet/features/notifications/domain/repositories/push_settings_repository.dart';

final pushSettingsRepositoryProvider = Provider<PushSettingsRepository>(
  (ref) => PushSettingsRepositoryImpl(
      ref.watch(pushSettingsRemoteDataSourceProvider)),
);

class PushSettingsRepositoryImpl implements PushSettingsRepository {
  PushSettingsRepositoryImpl(this._remote);

  final PushSettingsRemoteDataSource _remote;

  @override
  Future<Result<PushSwitches?>> switches() =>
      _guard(_remote.switches, 'switches');

  @override
  Future<Result<PushSwitches>> setSwitches(
          {bool? clubs, bool? topics, bool? platform}) =>
      _guard(
        () => _remote.setSwitches({
          if (clubs != null) 'clubs': clubs,
          if (topics != null) 'topics': topics,
          if (platform != null) 'platform': platform,
        }),
        'setSwitches',
      );

  @override
  Future<Result<bool?>> isClubMuted(int clubId) =>
      _guard(() => _remote.isClubMuted(clubId), 'isClubMuted');

  @override
  Future<Result<void>> setClubMuted(int clubId, {required bool muted}) =>
      _guard(() => _remote.setClubMuted(clubId, muted: muted), 'setClubMuted');

  Future<Result<T>> _guard<T>(Future<T> Function() call, String label) async {
    try {
      return Either.right(await call());
    } catch (e) {
      debugPrint('PushSettingsRepository.$label error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }
}
