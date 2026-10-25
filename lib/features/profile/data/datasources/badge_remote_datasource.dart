import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/profile/domain/entities/profile_badge.dart';

/// The server's badges (`app/api/badges/router.py`):
///
///   * `GET /badges/me` -- the person's own, each with `awarded_at`. The
///     server checks for new ones first, so a badge earned at the door
///     shows the next time the screen opens.
///   * `GET /badges/definitions` -- every badge there is, to show the ones
///     not earned yet. Public.
class BadgeRemoteDataSource {
  BadgeRemoteDataSource(this._dio);

  final Dio _dio;

  /// The person's shelf. Their own badges must load; the full list may
  /// not, and then only the earned ones show.
  Future<BadgeShelf> myShelf() async {
    final definitions = _definitions();
    final mine = await _dio.get<dynamic>(
      '/badges/me',
      // The person's own: kept encrypted, shown offline.
      options: Options(extra: CachePolicy.personal.extra),
    );
    final awards = jsonObjects(jsonObject(mine.data)?['badges'])
        .map(ProfileBadge.fromAward)
        .whereType<ProfileBadge>()
        .toList();
    return BadgeShelf.from(awards: awards, definitions: await definitions);
  }

  Future<List<ProfileBadge>> _definitions() async {
    try {
      final response = await _dio.get<dynamic>(
        '/badges/definitions',
        options: Options(extra: CachePolicy.shared.extra),
      );
      final list = response.data;
      return (list is List ? list : const [])
          .map((d) => ProfileBadge.fromJson(d))
          .whereType<ProfileBadge>()
          .toList();
    } catch (e) {
      debugPrint('BadgeRemoteDataSource: no badge list: $e');
      return const [];
    }
  }
}

final badgeRemoteDataSourceProvider = Provider<BadgeRemoteDataSource>(
  (ref) => BadgeRemoteDataSource(ref.watch(dioProvider)),
);

/// The signed-in person's badges, read each time the screen opens.
final myBadgesProvider = FutureProvider.autoDispose<BadgeShelf>(
  (ref) => ref.watch(badgeRemoteDataSourceProvider).myShelf(),
);
