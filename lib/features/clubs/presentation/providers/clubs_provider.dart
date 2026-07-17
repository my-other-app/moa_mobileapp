import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/clubs/data/repositories/club_repository_impl.dart';
import 'package:finnet/features/clubs/domain/entities/club_entity.dart';
import 'package:finnet/features/clubs/domain/repositories/club_repository.dart';

/// State for clubs list.
class ClubsState {
  final List<ClubListItem> clubs;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;
  // Filter state
  final int? organizationId;
  final List<int>? interestIds;

  const ClubsState({
    this.clubs = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.organizationId,
    this.interestIds,
  });

  ClubsState copyWith({
    List<ClubListItem>? clubs,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
    int? organizationId,
    List<int>? interestIds,
    bool clearOrganization = false,
    bool clearInterests = false,
  }) {
    return ClubsState(
      clubs: clubs ?? this.clubs,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      organizationId:
          clearOrganization ? null : (organizationId ?? this.organizationId),
      interestIds: clearInterests ? null : (interestIds ?? this.interestIds),
    );
  }

  bool get hasFilters =>
      organizationId != null ||
      (interestIds != null && interestIds!.isNotEmpty);
}

/// Provider for clubs the user follows.
final followingClubsProvider =
    StateNotifierProvider<ClubsNotifier, ClubsState>((ref) {
  final repository = ref.watch(clubRepositoryProvider);
  return ClubsNotifier(repository, ClubsType.following);
});

/// Provider for all clubs (explore).
final exploreClubsProvider =
    StateNotifierProvider<ClubsNotifier, ClubsState>((ref) {
  final repository = ref.watch(clubRepositoryProvider);
  return ClubsNotifier(repository, ClubsType.all);
});

/// Type of clubs to fetch.
enum ClubsType { following, all, pinned }

/// Notifier for clubs list operations.
class ClubsNotifier extends StateNotifier<ClubsState> {
  final ClubRepository _repository;
  final ClubsType _type;
  static const int _pageSize = 10;

  ClubsNotifier(this._repository, this._type) : super(const ClubsState());

  /// Load initial clubs.
  Future<void> loadClubs() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    final result = await _fetchClubs(page: 1);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (clubs) {
        state = state.copyWith(
          isLoading: false,
          clubs: clubs,
          currentPage: 1,
          hasMore: clubs.length >= _pageSize,
        );
      },
    );
  }

  /// Load more clubs (pagination).
  Future<void> loadMoreClubs() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    final nextPage = state.currentPage + 1;
    final result = await _fetchClubs(page: nextPage);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoadingMore: false,
          error: failure.message,
        );
      },
      (newClubs) {
        state = state.copyWith(
          isLoadingMore: false,
          clubs: [...state.clubs, ...newClubs],
          currentPage: nextPage,
          hasMore: newClubs.length >= _pageSize,
        );
      },
    );
  }

  /// Refresh clubs.
  Future<void> refresh() async {
    state = const ClubsState();
    await loadClubs();
  }

  /// Toggle follow status for a club.
  Future<bool> toggleFollow(int clubId) async {
    final clubIndex = state.clubs.indexWhere((c) => c.id == clubId);
    if (clubIndex == -1) return false;

    final club = state.clubs[clubIndex];
    final isCurrentlyFollowing = club.isFollowing;

    // Optimistic update
    final updatedClubs = List<ClubListItem>.from(state.clubs);
    updatedClubs[clubIndex] = club.copyWith(isFollowing: !isCurrentlyFollowing);
    state = state.copyWith(clubs: updatedClubs);

    final result = isCurrentlyFollowing
        ? await _repository.unfollowClub(clubId)
        : await _repository.followClub(clubId);

    return result.fold(
      (failure) {
        // Revert on failure
        final revertedClubs = List<ClubListItem>.from(state.clubs);
        revertedClubs[clubIndex] = club;
        state = state.copyWith(clubs: revertedClubs, error: failure.message);
        return false;
      },
      (_) => true,
    );
  }

  /// Toggle pin status for a club.
  Future<bool> togglePin(int clubId) async {
    final clubIndex = state.clubs.indexWhere((c) => c.id == clubId);
    if (clubIndex == -1) return false;

    final club = state.clubs[clubIndex];
    final isCurrentlyPinned = club.isPinned;

    // Optimistic update
    final updatedClubs = List<ClubListItem>.from(state.clubs);
    updatedClubs[clubIndex] = club.copyWith(isPinned: !isCurrentlyPinned);
    state = state.copyWith(clubs: updatedClubs);

    final result = isCurrentlyPinned
        ? await _repository.unpinClub(clubId)
        : await _repository.pinClub(clubId);

    return result.fold(
      (failure) {
        // Revert on failure
        final revertedClubs = List<ClubListItem>.from(state.clubs);
        revertedClubs[clubIndex] = club;
        state = state.copyWith(clubs: revertedClubs, error: failure.message);
        return false;
      },
      (_) => true,
    );
  }

  Future<dynamic> _fetchClubs({required int page}) async {
    switch (_type) {
      case ClubsType.following:
        return _repository.getFollowingClubs(page: page, limit: _pageSize);
      case ClubsType.all:
        return _repository.getClubs(
          page: page,
          limit: _pageSize,
          organizationId: state.organizationId,
          interestIds: state.interestIds,
        );
      case ClubsType.pinned:
        return _repository.getPinnedClubs();
    }
  }

  /// Apply filters and reload clubs.
  Future<void> applyFilters({
    int? organizationId,
    List<int>? interestIds,
  }) async {
    state = state.copyWith(
      organizationId: organizationId,
      interestIds: interestIds,
      clearOrganization: organizationId == null,
      clearInterests: interestIds == null || interestIds.isEmpty,
    );
    await loadClubs();
  }

  /// Clear all filters and reload.
  Future<void> clearFilters() async {
    state = state.copyWith(
      clearOrganization: true,
      clearInterests: true,
    );
    await loadClubs();
  }

  /// Set organization filter.
  void setOrganizationFilter(int? orgId) {
    state = state.copyWith(
      organizationId: orgId,
      clearOrganization: orgId == null,
    );
  }

  /// Set interests filter.
  void setInterestsFilter(List<int>? ids) {
    state = state.copyWith(
      interestIds: ids,
      clearInterests: ids == null || ids.isEmpty,
    );
  }
}

/// Provider for pinned clubs.
final pinnedClubsProvider = FutureProvider<List<ClubListItem>>((ref) async {
  final repository = ref.watch(clubRepositoryProvider);
  final result = await repository.getPinnedClubs();
  return result.fold(
    (failure) {
      debugPrint('Failed to load pinned clubs: ${failure.message}');
      return [];
    },
    (clubs) => clubs,
  );
});

/// State for club details.
class ClubDetailState {
  final Club? club;
  final bool isLoading;
  final String? error;
  final bool isTogglingFollow;

  const ClubDetailState({
    this.club,
    this.isLoading = false,
    this.error,
    this.isTogglingFollow = false,
  });

  ClubDetailState copyWith({
    Club? club,
    bool? isLoading,
    String? error,
    bool? isTogglingFollow,
  }) {
    return ClubDetailState(
      club: club ?? this.club,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isTogglingFollow: isTogglingFollow ?? this.isTogglingFollow,
    );
  }
}

/// Provider for club details.
final clubDetailProvider =
    StateNotifierProvider.family<ClubDetailNotifier, ClubDetailState, int>(
  (ref, clubId) {
    final repository = ref.watch(clubRepositoryProvider);
    return ClubDetailNotifier(repository, clubId);
  },
);

/// Notifier for club detail operations.
class ClubDetailNotifier extends StateNotifier<ClubDetailState> {
  final ClubRepository _repository;
  final int _clubId;

  ClubDetailNotifier(this._repository, this._clubId)
      : super(const ClubDetailState());

  /// Load club details.
  Future<void> loadClubDetails() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getClubDetails(_clubId);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (club) {
        state = state.copyWith(
          isLoading: false,
          club: club,
        );
      },
    );
  }

  /// Toggle follow status.
  Future<bool> toggleFollow() async {
    final club = state.club;
    if (club == null) return false;

    state = state.copyWith(isTogglingFollow: true, error: null);

    final result = club.isFollowing
        ? await _repository.unfollowClub(_clubId)
        : await _repository.followClub(_clubId);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isTogglingFollow: false,
          error: failure.message,
        );
        return false;
      },
      (_) {
        // Reload details to get updated state
        loadClubDetails();
        return true;
      },
    );
  }

  /// Toggle pin status.
  Future<bool> togglePin() async {
    final club = state.club;
    if (club == null) return false;

    final result = club.isPinned
        ? await _repository.unpinClub(_clubId)
        : await _repository.pinClub(_clubId);

    return result.fold(
      (failure) {
        state = state.copyWith(error: failure.message);
        return false;
      },
      (_) {
        // Reload details to get updated state
        loadClubDetails();
        return true;
      },
    );
  }
}

/// Provider for club search.
final clubSearchProvider =
    StateNotifierProvider<ClubSearchNotifier, ClubsState>((ref) {
  final repository = ref.watch(clubRepositoryProvider);
  return ClubSearchNotifier(repository);
});

/// Notifier for club search.
class ClubSearchNotifier extends StateNotifier<ClubsState> {
  final ClubRepository _repository;

  ClubSearchNotifier(this._repository) : super(const ClubsState());

  /// Search clubs by query.
  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const ClubsState();
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.searchClubs(query);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (clubs) {
        state = state.copyWith(
          isLoading: false,
          clubs: clubs,
          hasMore: false,
        );
      },
    );
  }

  /// Clear search results.
  void clear() {
    state = const ClubsState();
  }
}
