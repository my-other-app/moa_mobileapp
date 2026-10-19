import 'package:flutter/widgets.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';

/// The `items` of a paginated answer, or nothing when the body is not one.
///
/// `res.data['items'] ?? []` threw on an answer that was a list, a string or
/// null -- a red screen for an unexpected body rather than an empty feed.
List<dynamic> feedItems(Object? body) {
  final items = body is Map ? body['items'] : null;
  return items is List ? List<dynamic>.of(items) : const [];
}

/// The paging every event feed shares (for you, following, upcoming, past).
///
/// The first page comes from the saved copy at once, then from the network
/// ([APIService.getSavedThenFresh]); later pages only from the network, and
/// not while the first page is being refreshed -- a fresh first page would
/// otherwise replace pages already appended under it.
///
/// A screen gives the address of a page ([feedPage]), whose answer it is
/// ([feedPolicy]), and the words for a failure ([feedErrorFallback]); it
/// calls [fetchFirstPage] in `initState` and on pull-to-refresh, and hands
/// its scroll notifications to [onFeedScroll].
mixin SavedFirstPageFeed<W extends StatefulWidget> on State<W> {
  static const pageSize = 10;

  final List<dynamic> events = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMore = true;
  String? errorMessage;

  int _offset = 0;
  bool _refreshingFirstPage = false;

  /// The address of the page starting at [offset], query included.
  String feedPage(int offset);

  /// Shared for what is the same for everyone; personal for the person's
  /// own registrations.
  CachePolicy get feedPolicy;

  /// What a failure with nothing saved to show says.
  String get feedErrorFallback;

  /// Load (or reload) the first page. The list on screen stays while it
  /// reloads; the shimmer shows only when there is nothing to show.
  Future<void> fetchFirstPage() async {
    if (_refreshingFirstPage) return;
    _refreshingFirstPage = true;
    setState(() {
      isLoading = events.isEmpty;
      errorMessage = null;
    });
    try {
      await APIService.instance.getSavedThenFresh(
        feedPage(0),
        policy: feedPolicy,
        onData: (data, {required fresh}) {
          if (!mounted) return;
          final items = feedItems(data);
          setState(() {
            events
              ..clear()
              ..addAll(items);
            _offset = 0;
            hasMore = items.length >= pageSize;
            isLoading = false;
          });
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = readableError(e, fallback: feedErrorFallback);
          isLoading = false;
        });
      }
    } finally {
      _refreshingFirstPage = false;
    }
  }

  /// Append the next page.
  Future<void> loadMore() async {
    if (isLoadingMore || _refreshingFirstPage || !hasMore) return;
    final next = _offset + pageSize;
    setState(() => isLoadingMore = true);
    try {
      final res = await APIService.instance.request(
        feedPage(next),
        DioMethod.get,
      );
      if (!mounted) return;
      final items = feedItems(res.data);
      setState(() {
        events.addAll(items);
        _offset = next;
        hasMore = items.length >= pageSize;
        isLoadingMore = false;
      });
    } catch (e) {
      if (mounted) setState(() => isLoadingMore = false);
    }
  }

  /// Load the next page near the end of the list.
  bool onFeedScroll(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics.pixels >= metrics.maxScrollExtent - 200 && !isLoading) {
        loadMore();
      }
    }
    return false; // Don't consume the notification
  }
}
