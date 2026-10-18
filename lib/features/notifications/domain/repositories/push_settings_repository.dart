import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/notifications/domain/entities/push_switches.dart';

/// The person's say over broadcast pushes: the switches, and muted clubs.
///
/// A server from before these kept none: the reads answer null then, and the
/// screens show nothing to change.
abstract class PushSettingsRepository {
  /// The switches, or null when the server keeps none.
  Future<Result<PushSwitches?>> switches();

  /// Turn some switches on or off; the switches as the server now has them.
  Future<Result<PushSwitches>> setSwitches({
    bool? clubs,
    bool? topics,
    bool? platform,
  });

  /// Whether they muted a club, or null when the server keeps no mutes.
  Future<Result<bool?>> isClubMuted(int clubId);

  /// Mute or unmute a club they follow.
  Future<Result<void>> setClubMuted(int clubId, {required bool muted});
}
