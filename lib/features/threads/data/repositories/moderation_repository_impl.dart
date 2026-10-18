import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/threads/data/datasources/moderation_remote_datasource.dart';
import 'package:finnet/features/threads/data/repositories/thread_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/domain/repositories/moderation_repository.dart';

/// Provider for the moderation repository.
final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepositoryImpl(
    remoteDataSource: ref.watch(moderationRemoteDataSourceProvider),
  );
});

/// Implementation of [ModerationRepository].
///
/// Failures are built the way the rest of Threads builds them
/// ([threadFailureFrom]), so a 401 is an AuthFailure that offers sign-in and
/// a rate-limited call carries the code '429'.
class ModerationRepositoryImpl implements ModerationRepository {
  final ModerationRemoteDataSource remoteDataSource;

  ModerationRepositoryImpl({required this.remoteDataSource});

  Future<Result<T>> _guard<T>(String name, Future<T> Function() call) async {
    try {
      return Either.right(await call());
    } catch (e) {
      debugPrint('ModerationRepository.$name error: $e');
      return Either.left(threadFailureFrom(e));
    }
  }

  @override
  Future<Result<void>> report(
    ReportTarget target,
    ReportReason reason, {
    String? note,
  }) {
    return _guard('report', () => remoteDataSource.report(
          target,
          reason,
          note: note,
        ));
  }

  @override
  Future<Result<void>> block(int userId) {
    return _guard('block', () => remoteDataSource.block(userId));
  }

  @override
  Future<Result<void>> unblock(int userId) {
    return _guard('unblock', () => remoteDataSource.unblock(userId));
  }

  @override
  Future<Result<List<BlockedUser>>> getBlockedUsers() {
    return _guard('getBlockedUsers', () async {
      final users = await remoteDataSource.getBlockedUsers();
      return users.map((u) => u.toEntity()).toList();
    });
  }
}
