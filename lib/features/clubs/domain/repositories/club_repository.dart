import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/clubs/domain/entities/club_entity.dart';
import 'package:finnet/features/clubs/domain/entities/club_note.dart';

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

  /// Flip the club's pinned state, answering with what it became.
  ///
  /// Not `pinClub`/`unpinClub`: the server endpoint is a toggle, so neither
  /// intent can be expressed and the result has to be read rather than
  /// assumed. A caller that flipped its own boolean instead got it wrong
  /// whenever its copy was stale -- a double tap, or a pin set on another
  /// device, and "pin" unpinned.
  Future<Result<bool>> togglePin(int clubId);

  /// Flip whether this club's events are hidden, answering with the result.
  Future<Result<bool>> toggleHide(int clubId);

  /// Search clubs by name.
  Future<Result<List<ClubListItem>>> searchClubs(String query);

  /// The club's notes, newest first.
  Future<Result<List<ClubNote>>> getClubNotes(int clubId, {int? page});
}
