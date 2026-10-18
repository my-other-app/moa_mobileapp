import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';

/// Reporting and blocking: what a reader can do about a post or comment that
/// should not be there (App Store guideline 1.2).
abstract class ModerationRepository {
  /// Report [target] to the moderation team. A rate-limited report fails
  /// with code '429'.
  Future<Result<void>> report(
    ReportTarget target,
    ReportReason reason, {
    String? note,
  });

  /// Block [userId]: the server stops showing this person their comments.
  Future<Result<void>> block(int userId);

  /// Take a block back.
  Future<Result<void>> unblock(int userId);

  /// Everyone this person has blocked.
  Future<Result<List<BlockedUser>>> getBlockedUsers();
}
