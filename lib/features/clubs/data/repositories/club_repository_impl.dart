import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/features/clubs/data/datasources/club_remote_datasource.dart';
import 'package:finnet/features/clubs/domain/entities/club_entity.dart';
import 'package:finnet/features/clubs/domain/entities/club_note.dart';
import 'package:finnet/features/clubs/domain/repositories/club_repository.dart';

/// Provider for the club repository.
final clubRepositoryProvider = Provider<ClubRepository>((ref) {
  final remoteDataSource = ref.watch(clubRemoteDataSourceProvider);
  return ClubRepositoryImpl(remoteDataSource: remoteDataSource);
});

/// Implementation of club repository.
class ClubRepositoryImpl implements ClubRepository {
  final ClubRemoteDataSource remoteDataSource;

  ClubRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<List<ClubListItem>>> getClubs({
    int? page,
    int? limit,
    String? search,
    int? organizationId,
    List<int>? interestIds,
  }) async {
    try {
      final response = await remoteDataSource.getClubs(
        page: page,
        limit: limit,
        search: search,
        organizationId: organizationId,
        interestIds: interestIds,
      );
      return Either.right(response.map((e) => e.toListItem()).toList());
    } catch (e) {
      debugPrint('ClubRepository.getClubs error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<ClubListItem>>> getFollowingClubs({
    int? page,
    int? limit,
  }) async {
    try {
      final response = await remoteDataSource.getFollowingClubs(
        page: page,
        limit: limit,
      );
      return Either.right(response.map((e) => e.toListItem()).toList());
    } catch (e) {
      debugPrint('ClubRepository.getFollowingClubs error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<ClubListItem>>> getPinnedClubs() async {
    try {
      final response = await remoteDataSource.getPinnedClubs();
      return Either.right(response.map((e) => e.toListItem()).toList());
    } catch (e) {
      debugPrint('ClubRepository.getPinnedClubs error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<Club>> getClubDetails(int clubId) async {
    try {
      final response = await remoteDataSource.getClubDetails(clubId);
      return Either.right(response.toEntity());
    } catch (e) {
      debugPrint('ClubRepository.getClubDetails error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<void>> followClub(int clubId) async {
    try {
      await remoteDataSource.followClub(clubId);
      return Either.right(null);
    } catch (e) {
      debugPrint('ClubRepository.followClub error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<void>> unfollowClub(int clubId) async {
    try {
      await remoteDataSource.unfollowClub(clubId);
      return Either.right(null);
    } catch (e) {
      debugPrint('ClubRepository.unfollowClub error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<bool>> togglePin(int clubId) async {
    try {
      return Either.right(await remoteDataSource.togglePin(clubId));
    } catch (e) {
      debugPrint('ClubRepository.togglePin error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<bool>> toggleHide(int clubId) async {
    try {
      return Either.right(await remoteDataSource.toggleHide(clubId));
    } catch (e) {
      debugPrint('ClubRepository.toggleHide error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<ClubListItem>>> searchClubs(String query) async {
    try {
      final response = await remoteDataSource.searchClubs(query);
      return Either.right(response.map((e) => e.toListItem()).toList());
    } catch (e) {
      debugPrint('ClubRepository.searchClubs error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }
  @override
  Future<Result<List<ClubNote>>> getClubNotes(int clubId, {int? page}) async {
    try {
      return Either.right(
        await remoteDataSource.getClubNotes(clubId, page: page),
      );
    } catch (e) {
      debugPrint('ClubRepository.getClubNotes error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

}
