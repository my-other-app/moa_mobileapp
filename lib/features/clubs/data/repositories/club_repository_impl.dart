import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/error/either.dart';
import 'package:myotherapp/core/error/failures.dart';
import 'package:myotherapp/core/network/api_exception.dart';
import 'package:myotherapp/features/clubs/data/datasources/club_remote_datasource.dart';
import 'package:myotherapp/features/clubs/domain/entities/club_entity.dart';
import 'package:myotherapp/features/clubs/domain/repositories/club_repository.dart';

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
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('ClubRepository.getClubs error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
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
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('ClubRepository.getFollowingClubs error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<ClubListItem>>> getPinnedClubs() async {
    try {
      final response = await remoteDataSource.getPinnedClubs();
      return Either.right(response.map((e) => e.toListItem()).toList());
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('ClubRepository.getPinnedClubs error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<Club>> getClubDetails(int clubId) async {
    try {
      final response = await remoteDataSource.getClubDetails(clubId);
      return Either.right(response.toEntity());
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('ClubRepository.getClubDetails error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> followClub(int clubId) async {
    try {
      await remoteDataSource.followClub(clubId);
      return Either.right(null);
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('ClubRepository.followClub error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> unfollowClub(int clubId) async {
    try {
      await remoteDataSource.unfollowClub(clubId);
      return Either.right(null);
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('ClubRepository.unfollowClub error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> pinClub(int clubId) async {
    try {
      await remoteDataSource.pinClub(clubId);
      return Either.right(null);
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('ClubRepository.pinClub error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<void>> unpinClub(int clubId) async {
    try {
      await remoteDataSource.unpinClub(clubId);
      return Either.right(null);
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('ClubRepository.unpinClub error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Result<List<ClubListItem>>> searchClubs(String query) async {
    try {
      final response = await remoteDataSource.searchClubs(query);
      return Either.right(response.map((e) => e.toListItem()).toList());
    } on ApiException catch (e) {
      return Either.left(_mapApiExceptionToFailure(e));
    } catch (e) {
      debugPrint('ClubRepository.searchClubs error: $e');
      return Either.left(UnknownFailure(message: e.toString()));
    }
  }

  /// Map API exceptions to domain failures.
  Failure _mapApiExceptionToFailure(ApiException e) {
    switch (e.type) {
      case ApiExceptionType.network:
        return NetworkFailure(message: e.message);
      case ApiExceptionType.unauthorized:
        return AuthFailure(message: e.message);
      case ApiExceptionType.forbidden:
        return AuthFailure(message: e.message);
      case ApiExceptionType.badRequest:
        return ValidationFailure(message: e.message);
      case ApiExceptionType.notFound:
        return ServerFailure(message: e.message, code: '404');
      case ApiExceptionType.server:
        return ServerFailure(message: e.message);
      case ApiExceptionType.timeout:
        return NetworkFailure(message: e.message);
      case ApiExceptionType.cancelled:
        return UnknownFailure(message: e.message);
      case ApiExceptionType.unknown:
        return UnknownFailure(message: e.message);
    }
  }
}
