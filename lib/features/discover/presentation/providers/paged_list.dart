import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/discover/domain/discover_paging.dart';

/// A list a page at a time: what is shown, what is loading, and where the
/// next page starts.
///
/// [meta] is what came beside the first page (where the server placed the
/// caller, the facets); null until a page has come.
class PagedState<T, M> {
  const PagedState({
    this.items = const [],
    this.meta,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.loadMoreError,
    this.next,
    this.total = 0,
    this.capped = false,
    this.fromSaved = false,
  });

  final List<T> items;
  final M? meta;

  /// The first page is on its way and nothing is shown yet.
  final bool isLoading;
  final bool isLoadingMore;

  /// Why the first page failed, with nothing saved to show instead.
  final String? error;

  /// Why a later page failed: shown under the list, with a retry.
  final String? loadMoreError;

  /// Where the next page starts; null at the end.
  final PageRequest? next;
  final int total;
  final bool capped;

  /// What is shown is the copy saved on this phone, not yet confirmed.
  final bool fromSaved;

  bool get hasMore => next != null;
  bool get isEmpty => items.isEmpty;

  PagedState<T, M> copyWith({
    List<T>? items,
    M? meta,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? loadMoreError,
    bool clearLoadMoreError = false,
    PageRequest? next,
    bool clearNext = false,
    int? total,
    bool? capped,
    bool? fromSaved,
  }) {
    return PagedState<T, M>(
      items: items ?? this.items,
      meta: meta ?? this.meta,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      loadMoreError:
          clearLoadMoreError ? null : (loadMoreError ?? this.loadMoreError),
      next: clearNext ? null : (next ?? this.next),
      total: total ?? this.total,
      capped: capped ?? this.capped,
      fromSaved: fromSaved ?? this.fromSaved,
    );
  }
}

/// One page and what came beside it.
typedef PageWithMeta<T, M> = (DiscoverPage<T> page, M meta);

/// Pages through one of the discover lists.
///
/// * The first page comes from the copy saved on this phone at once, then
///   from the network; with a copy on screen, a failure leaves it there
///   (the offline strip says why) rather than an error.
/// * Later pages start where the last one said (`after=next_cursor`); a
///   server without cursors is paged by offset, never past 1,000
///   ([nextPageAfter]). Not while the first page is being refreshed: a
///   fresh first page would otherwise replace pages appended under it.
/// * A row already shown is not shown twice (a new event shifts a page).
abstract class PagedNotifier<T, M> extends StateNotifier<PagedState<T, M>> {
  PagedNotifier({this.pageSize = discoverPageSize})
      : super(PagedState<T, M>(isLoading: true));

  final int pageSize;

  /// Rows read from the server so far (before dropping repeats): where an
  /// offset-paged list goes on from.
  int _read = 0;
  bool _refreshing = false;

  Future<Result<PageWithMeta<T, M>>> fetchPage(PageRequest page);

  /// The first page as saved on this phone, or null. Never the network.
  Future<PageWithMeta<T, M>?> savedFirstPage() async => null;

  /// What makes two rows the same row.
  Object keyOf(T item);

  PagedState<T, M> _firstPage(PageWithMeta<T, M> answer,
      {required bool saved}) {
    final (page, meta) = answer;
    final seen = <Object>{};
    final items = [
      for (final item in page.items)
        if (seen.add(keyOf(item))) item,
    ];
    return PagedState<T, M>(
      items: items,
      meta: meta,
      next: nextPageAfter(page, page.items.length, limit: pageSize),
      total: page.total,
      capped: page.capped,
      fromSaved: saved,
    );
  }

  /// Load the first page (the saved copy first), replacing what is shown.
  Future<void> load() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      state = state.copyWith(
        isLoading: state.items.isEmpty,
        clearError: true,
        clearLoadMoreError: true,
      );
      var showingSaved = false;
      if (state.items.isEmpty) {
        final saved = await savedFirstPage();
        if (!mounted) return;
        if (saved != null && saved.$1.items.isNotEmpty) {
          state = _firstPage(saved, saved: true);
          _read = saved.$1.items.length;
          showingSaved = true;
        }
      }
      final result = await fetchPage(PageRequest.first(limit: pageSize));
      if (!mounted) return;
      result.fold(
        (failure) {
          if (showingSaved || state.items.isNotEmpty) {
            state = state.copyWith(isLoading: false);
          } else {
            state = state.copyWith(isLoading: false, error: failure.message);
          }
        },
        (answer) {
          _read = answer.$1.items.length;
          state = _firstPage(answer, saved: false);
        },
      );
    } finally {
      _refreshing = false;
    }
  }

  /// Pull to refresh: what is shown stays until the new first page is in.
  Future<void> refresh() => load();

  /// Append the next page, if there is one and nothing else is loading.
  Future<void> loadMore() async {
    final next = state.next;
    if (next == null || _refreshing || state.isLoading || state.isLoadingMore) {
      return;
    }
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    final result = await fetchPage(next);
    if (!mounted) return;
    result.fold(
      (failure) => state = state.copyWith(
        isLoadingMore: false,
        loadMoreError: failure.message,
      ),
      (answer) {
        final (page, _) = answer;
        _read += page.items.length;
        final seen = {for (final item in state.items) keyOf(item)};
        final items = [
          ...state.items,
          for (final item in page.items)
            if (seen.add(keyOf(item))) item,
        ];
        final after = nextPageAfter(page, _read, limit: pageSize);
        state = state.copyWith(
          items: items,
          isLoadingMore: false,
          next: after,
          clearNext: after == null,
          // At the end the count is what was shown; before it, the
          // server's (a floor when it stopped counting).
          total:
              after == null ? items.length : math.max(page.total, items.length),
          capped: after != null && page.capped,
        );
      },
    );
  }

  /// Replace a row shown (matched by [keyOf]).
  void replaceItem(T item) {
    final key = keyOf(item);
    final index = state.items.indexWhere((i) => keyOf(i) == key);
    if (index == -1) return;
    state = state.copyWith(items: List<T>.of(state.items)..[index] = item);
  }

  /// Drop the row with [key] (a post the server says is gone).
  void removeItem(Object key) {
    if (!state.items.any((i) => keyOf(i) == key)) return;
    state = state.copyWith(
        items: state.items.where((i) => keyOf(i) != key).toList());
  }

  /// The row shown with [key], if any.
  T? itemWithKey(Object key) {
    for (final item in state.items) {
      if (keyOf(item) == key) return item;
    }
    return null;
  }
}
