import 'dart:async';

import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/domain/repositories/moderation_repository.dart';

/// A [ModerationRepository] that records what was asked and answers what it
/// is told to.
class FakeModerationRepository implements ModerationRepository {
  final List<String> calls = [];
  Result<void> reportResult = Either.right(null);
  Result<void> blockResult = Either.right(null);
  Result<void> unblockResult = Either.right(null);
  Result<List<BlockedUser>> listResult = Either.right(const []);

  /// When set, block waits for this before answering.
  Completer<void>? blockGate;

  ReportTarget? lastTarget;
  ReportReason? lastReason;
  String? lastNote;

  @override
  Future<Result<void>> report(
    ReportTarget target,
    ReportReason reason, {
    String? note,
  }) async {
    calls.add('report');
    lastTarget = target;
    lastReason = reason;
    lastNote = note;
    return reportResult;
  }

  @override
  Future<Result<void>> block(int userId) async {
    calls.add('block:$userId');
    await blockGate?.future;
    return blockResult;
  }

  @override
  Future<Result<void>> unblock(int userId) async {
    calls.add('unblock:$userId');
    return unblockResult;
  }

  @override
  Future<Result<List<BlockedUser>>> getBlockedUsers() async {
    calls.add('list');
    return listResult;
  }
}
