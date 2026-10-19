import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_filter.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_filter_bar.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';

/// The query `/events/list` gets for upcoming events under [filter],
/// matching [search], a page from [offset].
///
/// Only parameters the endpoint has: a topic goes as its interests'
/// `interest_ids` (see [TopicFilter]).
@visibleForTesting
Map<String, dynamic> exploreEventsQuery({
  TopicFilter filter = TopicFilter.none,
  String search = '',
  int offset = 0,
  int limit = ExploreEventsPage.pageSize,
}) {
  return {
    'is_ended': false,
    'offset': offset,
    'limit': limit,
    ...filter.queryParameters,
    if (search.trim().isNotEmpty) 'search': search.trim(),
  };
}

/// Upcoming events to browse by topic and interest, with a search.
///
/// Reached from Home's "Browse by topic" and from the topic chips on an
/// event's page. [initialTopic] is a topic's slug or id; [initialInterestId]
/// an interest's. Both wait for the topics to arrive before the first
/// fetch, since a topic is asked for by its interests.
class ExploreEventsPage extends ConsumerStatefulWidget {
  final String? initialTopic;
  final int? initialInterestId;

  static const int pageSize = 10;

  const ExploreEventsPage({
    super.key,
    this.initialTopic,
    this.initialInterestId,
  });

  @override
  ConsumerState<ExploreEventsPage> createState() => _ExploreEventsPageState();
}

class _ExploreEventsPageState extends ConsumerState<ExploreEventsPage> {
  final List<Map<String, dynamic>> _events = [];
  TopicFilter _filter = TopicFilter.none;
  String _search = '';
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _offset = 0;

  /// Bumped per fetch, so an answer to an older filter is dropped.
  int _generation = 0;

  /// While the first page is still on its way from the network (after the
  /// saved copy), no more pages are appended: the fresh first page would
  /// replace them.
  bool _firstPageInFlight = false;

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  bool get _waitsForTopics =>
      (widget.initialTopic?.isNotEmpty ?? false) ||
      widget.initialInterestId != null;

  @override
  void initState() {
    super.initState();
    if (!_waitsForTopics) {
      _fetch();
      return;
    }
    var resolved = false;
    ref.listenManual<AsyncValue<List<Topic>>>(topicDirectoryProvider,
        (_, next) {
      if (resolved || next.isLoading) return;
      resolved = true;
      // Topics that failed to load filter nothing: the list still shows.
      final topics = next.valueOrNull ?? const <Topic>[];
      _filter = TopicFilter.resolve(
        topics,
        topicRef: widget.initialTopic,
        interestId: widget.initialInterestId,
      );
      _fetch();
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search = value.trim();
      _fetch();
    });
  }

  void _setFilter(TopicFilter filter) {
    if (filter == _filter) return;
    _filter = filter;
    _fetch();
  }

  void _clearFilters() {
    _searchController.clear();
    _search = '';
    _filter = TopicFilter.none;
    _fetch();
  }

  Future<void> _fetch() async {
    final generation = ++_generation;
    if (mounted) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
        _errorMessage = null;
        _offset = 0;
        _events.clear();
      });
    }

    // A topic with no interests yet: nothing can be under it.
    if (_filter.matchesNothing) {
      setState(() {
        _hasMore = false;
        _isLoading = false;
      });
      return;
    }

    void show(List<Map<String, dynamic>> page) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _events
          ..clear()
          ..addAll(page);
        _offset = 0;
        _hasMore = page.length >= ExploreEventsPage.pageSize;
        _isLoading = false;
      });
    }

    _firstPageInFlight = true;
    try {
      if (_search.isEmpty) {
        // A topic's (or everything's) first page: the saved copy at once,
        // then the network's. A search is always asked fresh.
        await APIService.instance.getSavedThenFresh(
          '/events/list',
          param: exploreEventsQuery(filter: _filter),
          onData: (data, {required fresh}) => show(_itemsOf(data)),
        );
      } else {
        show(await _page(0));
      }
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _errorMessage = readableError(e, fallback: 'Could not load events.');
        _isLoading = false;
      });
    } finally {
      if (generation == _generation) _firstPageInFlight = false;
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || _isLoading || _firstPageInFlight) {
      return;
    }
    final generation = _generation;
    final next = _offset + ExploreEventsPage.pageSize;
    setState(() => _isLoadingMore = true);
    try {
      final page = await _page(next);
      if (!mounted || generation != _generation) return;
      setState(() {
        _offset = next;
        _events.addAll(page);
        _hasMore = page.length >= ExploreEventsPage.pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<List<Map<String, dynamic>>> _page(int offset) async {
    final res = await APIService.instance.request(
      '/events/list',
      DioMethod.get,
      param: exploreEventsQuery(
          filter: _filter, search: _search, offset: offset),
    );
    return _itemsOf(res.data);
  }

  static List<Map<String, dynamic>> _itemsOf(Object? data) {
    final items = data is Map ? data['items'] : null;
    return [
      if (items is List)
        for (final e in items)
          if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification is ScrollEndNotification &&
        notification.metrics.pixels >=
            notification.metrics.maxScrollExtent - 200) {
      _loadMore();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topics = ref.watch(topicDirectoryProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text(
          'EXPLORE EVENTS',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 12),
          topics.when(
            data: (list) => TopicFilterBar(
              key: const ValueKey('explore-events-filters'),
              topics: list,
              filter: _filter,
              onChanged: _setFilter,
              topicCount: (t) => t.upcomingEvents,
              interestCount: (i) => i.upcomingEvents,
            ),
            loading: () => const SizedBox(height: 36),
            // Filters are extra; without them the list still works.
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        key: const ValueKey('explore-events-search'),
        controller: _searchController,
        onChanged: _onSearchChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search events...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Color(0xFF979797)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF1E1E1E)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF17A58F), width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ShimmerEventCard(),
            SizedBox(height: 32),
            ShimmerEventCard(),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return ErrorView(message: _errorMessage, onRetry: _fetch);
    }

    if (_events.isEmpty) {
      final filtered = _filter.isActive || _search.isNotEmpty;
      final what = _filter.label;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                !filtered
                    ? 'No upcoming events yet'
                    : what.isNotEmpty && _search.isEmpty
                        ? 'No upcoming events in $what yet'
                        : 'No upcoming events match',
                key: const ValueKey('explore-events-empty'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              if (filtered) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Clear filters'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _events.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(
              thickness: 1,
              color: Colors.black,
              indent: 50,
              endIndent: 50,
            ),
          ),
          itemBuilder: (context, index) {
            if (index == _events.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            return eventCardFromJson(_events[index]);
          },
        ),
      ),
    );
  }
}
