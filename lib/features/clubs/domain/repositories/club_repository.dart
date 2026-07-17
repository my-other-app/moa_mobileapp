import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/clubs/domain/entities/club_entity.dart';

/// Repository interface for club operations.
abstract class ClubRepository {
  /// Get list of clubs with optional filtering.
  Future<Result<List<ClubListItem>>> getClubs({
    int? page,
    int? limit,
    String? search,
    int? organizationId,
    List<int>? interestIds,
  });

  /// Get clubs that the user follows.
  Future<Result<List<ClubListItem>>> getFollowingClubs({
    int? page,
    int? limit,
  });

  /// Get pinned clubs for the user.
  Future<Result<List<ClubListItem>>> getPinnedClubs();

  /// Get detailed club information.
  Future<Result<Club>> getClubDetails(int clubId);

  /// Follow a club.
  Future<Result<void>> followClub(int clubId);

  /// Unfollow a club.
  Future<Result<void>> unfollowClub(int clubId);

  /// Pin a club.
  Future<Result<void>> pinClub(int clubId);

  /// Unpin a club.
  Future<Result<void>> unpinClub(int clubId);

  /// Search clubs by name.
  Future<Result<List<ClubListItem>>> searchClubs(String query);
}
