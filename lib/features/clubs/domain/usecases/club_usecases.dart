import 'package:myotherapp/core/error/either.dart';
import 'package:myotherapp/core/usecases/usecase.dart';
import 'package:myotherapp/features/clubs/domain/entities/club_entity.dart';
import 'package:myotherapp/features/clubs/domain/repositories/club_repository.dart';

/// Parameters for getting clubs list.
class GetClubsParams {
  final int? page;
  final int? limit;
  final String? search;
  final int? organizationId;
  final List<int>? interestIds;

  const GetClubsParams({
    this.page,
    this.limit,
    this.search,
    this.organizationId,
    this.interestIds,
  });
}

/// Use case for getting clubs list.
class GetClubsUseCase extends UseCase<List<ClubListItem>, GetClubsParams> {
  final ClubRepository repository;

  GetClubsUseCase(this.repository);

  @override
  Future<Result<List<ClubListItem>>> call(GetClubsParams params) {
    return repository.getClubs(
      page: params.page,
      limit: params.limit,
      search: params.search,
      organizationId: params.organizationId,
      interestIds: params.interestIds,
    );
  }
}

/// Parameters for pagination.
class ClubPaginationParams {
  final int? page;
  final int? limit;

  const ClubPaginationParams({this.page, this.limit});
}

/// Use case for getting followed clubs.
class GetFollowingClubsUseCase
    extends UseCase<List<ClubListItem>, ClubPaginationParams> {
  final ClubRepository repository;

  GetFollowingClubsUseCase(this.repository);

  @override
  Future<Result<List<ClubListItem>>> call(ClubPaginationParams params) {
    return repository.getFollowingClubs(
      page: params.page,
      limit: params.limit,
    );
  }
}

/// Use case for getting pinned clubs.
class GetPinnedClubsUseCase extends NoParamsUseCase<List<ClubListItem>> {
  final ClubRepository repository;

  GetPinnedClubsUseCase(this.repository);

  @override
  Future<Result<List<ClubListItem>>> call() {
    return repository.getPinnedClubs();
  }
}

/// Use case for getting club details.
class GetClubDetailsUseCase extends UseCase<Club, int> {
  final ClubRepository repository;

  GetClubDetailsUseCase(this.repository);

  @override
  Future<Result<Club>> call(int clubId) {
    return repository.getClubDetails(clubId);
  }
}

/// Use case for following a club.
class FollowClubUseCase extends UseCase<void, int> {
  final ClubRepository repository;

  FollowClubUseCase(this.repository);

  @override
  Future<Result<void>> call(int clubId) {
    return repository.followClub(clubId);
  }
}

/// Use case for unfollowing a club.
class UnfollowClubUseCase extends UseCase<void, int> {
  final ClubRepository repository;

  UnfollowClubUseCase(this.repository);

  @override
  Future<Result<void>> call(int clubId) {
    return repository.unfollowClub(clubId);
  }
}

/// Use case for pinning a club.
class PinClubUseCase extends UseCase<void, int> {
  final ClubRepository repository;

  PinClubUseCase(this.repository);

  @override
  Future<Result<void>> call(int clubId) {
    return repository.pinClub(clubId);
  }
}

/// Use case for unpinning a club.
class UnpinClubUseCase extends UseCase<void, int> {
  final ClubRepository repository;

  UnpinClubUseCase(this.repository);

  @override
  Future<Result<void>> call(int clubId) {
    return repository.unpinClub(clubId);
  }
}

/// Use case for searching clubs.
class SearchClubsUseCase extends UseCase<List<ClubListItem>, String> {
  final ClubRepository repository;

  SearchClubsUseCase(this.repository);

  @override
  Future<Result<List<ClubListItem>>> call(String query) {
    return repository.searchClubs(query);
  }
}
