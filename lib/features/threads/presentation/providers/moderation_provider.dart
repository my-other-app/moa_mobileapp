import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/threads/data/repositories/moderation_repository_impl.dart';
import 'package:finnet/features/threads/domain/entities/moderation.dart';
import 'package:finnet/features/threads/domain/repositories/moderation_repository.dart';

/// The longest note a report carries.
const maxReportNoteLength = 500;

/// Words for a failed report, block or unblock, for a snackbar or the
/// reasons sheet.
///
/// A rate limit (429) and a dropped connection get their own plain copy --
/// the server's 429 text is "Rate limit exceeded: 5 per 1 minute", which is
/// not for people. A 400 keeps the server's words ("You can't block
/// yourself"); anything else gets [fallback] rather than a status code.
String moderationFailureMessage(Failure failure, {required String fallback}) {
  if (failure.code == '429') {
    return "You're doing that a lot. Please wait a few minutes and try again.";
  }
  if (failure is NetworkFailure) {
    return 'No connection. Check your internet and try again.';
  }
  if (failure is ValidationFailure) {
    final said = failure.message.trim();
    if (said.isNotEmpty) return said;
  }
  return fallback;
}

/// Who this person has blocked, and whose comments to keep off screen.
class ModerationState {
  /// The Settings list: everyone blocked, as the server reports them plus
  /// anyone blocked since it was loaded.
  final List<BlockedUser> blocked;

  /// User ids whose comments are hidden right now. A block lands here the
  /// moment it is confirmed, before the server answers, so the comments go
  /// at once; a failed block takes it back out.
  final Set<int> hiddenUserIds;

  final bool isLoading;

  /// The list has been fetched at least once.
  final bool hasLoaded;

  /// Why the list could not be fetched.
  final String? error;

  /// Unblocks in flight.
  final Set<int> unblocking;

  const ModerationState({
    this.blocked = const [],
    this.hiddenUserIds = const {},
    this.isLoading = false,
    this.hasLoaded = false,
    this.error,
    this.unblocking = const {},
  });

  ModerationState copyWith({
    List<BlockedUser>? blocked,
    Set<int>? hiddenUserIds,
    bool? isLoading,
    bool? hasLoaded,
    String? error,
    bool clearError = false,
    Set<int>? unblocking,
  }) {
    return ModerationState(
      blocked: blocked ?? this.blocked,
      hiddenUserIds: hiddenUserIds ?? this.hiddenUserIds,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      error: clearError ? null : (error ?? this.error),
      unblocking: unblocking ?? this.unblocking,
    );
  }
}

/// Reports and blocks, for the whole session.
///
/// Rebuilt whenever the person signs in or out: one account's blocks are
/// not the next one's. Nothing is fetched until Settings asks for the list --
/// the server already leaves blocked people's comments out of every page.
final moderationProvider =
    StateNotifierProvider<ModerationNotifier, ModerationState>((ref) {
  ref.watch(isAuthenticatedProvider);
  return ModerationNotifier(ref);
});

/// Notifier behind [moderationProvider].
class ModerationNotifier extends StateNotifier<ModerationState> {
  ModerationNotifier(this._ref) : super(const ModerationState());

  final Ref _ref;

  // Read when needed, not at construction: a page that only filters by
  // [ModerationState.hiddenUserIds] should not build a network client.
  ModerationRepository get _repository =>
      _ref.read(moderationRepositoryProvider);

  /// Fetch the blocked list for Settings.
  Future<void> loadBlocked() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _repository.getBlockedUsers();
    if (!mounted) return;
    result.fold(
      (failure) => state = state.copyWith(
        isLoading: false,
        error: moderationFailureMessage(
          failure,
          fallback: "Couldn't load your blocked list.",
        ),
      ),
      (users) => state = state.copyWith(
        isLoading: false,
        hasLoaded: true,
        blocked: users,
        hiddenUserIds: {...state.hiddenUserIds, ...users.map((u) => u.userId)},
      ),
    );
  }

  /// Report [target]. Answers with the failure, if there was one.
  Future<Failure?> report(
    ReportTarget target,
    ReportReason reason, {
    String? note,
  }) async {
    final trimmed = note?.trim() ?? '';
    // Code points, as the server counts them.
    if (trimmed.runes.length > maxReportNoteLength) {
      return const ValidationFailure(
        message: 'Keep the note under $maxReportNoteLength characters.',
      );
    }
    final result = await _repository.report(
      target,
      reason,
      note: trimmed.isEmpty ? null : trimmed,
    );
    return result.fold((failure) => failure, (_) => null);
  }

  /// Block [userId]. Their comments are hidden at once; if the server
  /// refuses, they come back and the failure is answered.
  Future<Failure?> block(
    int userId, {
    required String name,
    String? avatarUrl,
  }) async {
    if (userId <= 0) {
      return const ValidationFailure(message: "This person can't be blocked.");
    }
    // Already blocked, or a block is on its way.
    if (state.hiddenUserIds.contains(userId)) return null;

    state = state.copyWith(hiddenUserIds: {...state.hiddenUserIds, userId});
    final result = await _repository.block(userId);
    if (!mounted) return null;

    return result.fold(
      (failure) {
        // "Already blocked" is the outcome that was asked for.
        if (failure.code == '409') {
          _addBlocked(userId, name, avatarUrl);
          return null;
        }
        state = state.copyWith(
          hiddenUserIds: {...state.hiddenUserIds}..remove(userId),
        );
        return failure;
      },
      (_) {
        _addBlocked(userId, name, avatarUrl);
        return null;
      },
    );
  }

  /// Take back a block. Answers with the failure, if there was one.
  Future<Failure?> unblock(int userId) async {
    if (state.unblocking.contains(userId)) return null;
    state = state.copyWith(unblocking: {...state.unblocking, userId});

    final result = await _repository.unblock(userId);
    if (!mounted) return null;

    final unblocking = {...state.unblocking}..remove(userId);
    return result.fold(
      (failure) {
        // Not blocked (any more) is the outcome that was asked for.
        if (failure.code == '404') {
          _dropBlocked(userId, unblocking);
          return null;
        }
        state = state.copyWith(unblocking: unblocking);
        return failure;
      },
      (_) {
        _dropBlocked(userId, unblocking);
        return null;
      },
    );
  }

  void _addBlocked(int userId, String name, String? avatarUrl) {
    if (state.blocked.any((u) => u.userId == userId)) return;
    state = state.copyWith(blocked: [
      ...state.blocked,
      BlockedUser(userId: userId, name: name, avatarUrl: avatarUrl),
    ]);
  }

  void _dropBlocked(int userId, Set<int> unblocking) {
    state = state.copyWith(
      unblocking: unblocking,
      blocked: state.blocked.where((u) => u.userId != userId).toList(),
      hiddenUserIds: {...state.hiddenUserIds}..remove(userId),
    );
  }
}
