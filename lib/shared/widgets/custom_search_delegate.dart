import 'package:flutter/material.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/common/models/events/cohost_model.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/domain/registration_status.dart'
    show isAwaitingPayment;
import 'package:finnet/shared/widgets/event_card.dart' show PaymentDueBadge;
import 'package:finnet/shared/widgets/event_poster_image.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/utils/latest_search.dart';

/// `/events/list` for a search, narrowed to the tab it was started from.
///
/// The query is encoded: typed as-is, "C++ & AI" became `search=C++ ` plus a
/// stray `& AI` parameter, and a `#` cut the URL short.
@visibleForTesting
String eventSearchEndpoint(String query, {String filterType = 'for_you'}) {
  final q = Uri.encodeQueryComponent(query);
  final endpoint = StringBuffer('/events/list?search=$q&offset=0&limit=20');
  switch (filterType) {
    case 'following':
      endpoint.write('&is_following=true');
    case 'registered':
      endpoint.write('&is_registered=true&is_ended=false');
    case 'past':
      endpoint.write('&is_registered=true&is_ended=true');
    // 'for_you' - no additional filter, shows all events
  }
  return endpoint.toString();
}

/// `/clubs/list` for a search, the query encoded.
@visibleForTesting
String clubSearchEndpoint(String query) =>
    '/clubs/list?search=${Uri.encodeQueryComponent(query)}&offset=0&limit=20';

/// The `items` of a search's answer, from the server.
Future<List<dynamic>> _searchItems(String endpoint) async {
  final response = await APIService.instance.request(endpoint, DioMethod.get);
  final data = response.data;
  final items = data is Map ? data['items'] : null;
  return items is List ? items : const [];
}

String _searchFailed(Object error) {
  debugPrint('Search error: $error');
  return extractErrorMessage(
    error,
    defaultMessage: 'Search failed. Please try again.',
  );
}

/// The answer under a query: a spinner (or the last answer under a thin
/// bar) while typing pauses and the search is on its way, then the results,
/// the empty line or the failure with Retry.
Widget _searchAnswerView({
  required LatestSearch search,
  required String Function() query,
  required String emptyLine,
  required Widget Function(BuildContext context, dynamic item) tile,
}) {
  return ValueListenableBuilder<SearchAnswer>(
    valueListenable: search.answer,
    builder: (context, answer, _) {
      final q = query();
      if (q.isEmpty) return const SizedBox.shrink();
      Widget list(List<dynamic> items) => ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => tile(context, items[index]),
          );
      if (!answer.answers(q)) {
        if (answer.items.isEmpty || answer.error != null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            const LinearProgressIndicator(minHeight: 2),
            Expanded(child: list(answer.items)),
          ],
        );
      }
      final error = answer.error;
      if (error != null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(error, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: search.retry,
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      if (answer.items.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                emptyLine,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        );
      }
      return list(answer.items);
    },
  );
}

/// Search delegate for EVENTS ONLY - used on home and events pages.
/// Supports tab-based filtering (for_you, following, registered, past).
class EventSearchDelegate extends SearchDelegate<String> {
  /// Filter type based on current tab context
  /// Values: 'for_you', 'following', 'registered', 'past'
  final String filterType;

  /// Searched once typing pauses; only the latest query's answer shows.
  final LatestSearch _search;

  /// [fetch] (the items for an endpoint) and [debounce] are for tests.
  EventSearchDelegate({
    this.filterType = 'for_you',
    Future<List<dynamic>> Function(String endpoint)? fetch,
    Duration debounce = searchDebounce,
  }) : _search = LatestSearch(
          fetch: (q) => (fetch ??
              _searchItems)(eventSearchEndpoint(q, filterType: filterType)),
          errorMessage: _searchFailed,
          debounce: debounce,
        );

  @override
  String get searchFieldLabel => 'Search for events...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  void close(BuildContext context, String result) {
    _search.cancel();
    super.close(context, result);
  }

  @override
  Widget buildResults(BuildContext context) {
    _search.submit(query);
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _search.update(query);
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Search for ${_getFilterLabel()} events',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  String _getFilterLabel() {
    switch (filterType) {
      case 'following':
        return 'following';
      case 'registered':
        return 'registered';
      case 'past':
        return 'past';
      default:
        return '';
    }
  }

  Widget _buildSearchResults(BuildContext context) => _searchAnswerView(
        search: _search,
        query: () => query,
        emptyLine: 'No events found for "$query"',
        tile: _buildEventTile,
      );

  Widget _buildEventTile(BuildContext context, dynamic event) {
    return ListTile(
      leading: event is Map
          ? EventPosterImage.fromEvent(
              event,
              slot: PosterSlot.thumb,
              width: 50,
              height: 50,
              borderRadius: BorderRadius.circular(8),
            )
          : null,
      title: Text(event['name'] ?? 'Unnamed Event'),
      subtitle: Text(_clubNameOf(event)),
      // A registration whose fee is still owed says so, as its card does.
      trailing: _awaitsPayment(event)
          ? const PaymentDueBadge()
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.yellow.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                event['category']?['name'] ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            ),
      onTap: () {
        close(context, '');
        context.push('/events/${event['id']}');
      },
    );
  }

  /// The hosting club's name ("A and B", "A + 2" with co-hosts), or nothing
  /// for an event that came without its club.
  static String _clubNameOf(dynamic event) {
    final club = event is Map ? event['club'] : null;
    final name = club is Map ? club['name'] : null;
    if (name is! String) return '';
    final cohosts = EventCohost.listFrom(
        event is Map ? event['cohosts'] : null,
        hostId: club is Map ? jsonInt(club['id']) : null);
    return hostNamesCompact(name, [for (final c in cohosts) c.name]);
  }

  /// Registered (by the tab searched from, or by the result itself) and
  /// still owing the fee. Not on the past tab: an event that is over can no
  /// longer be paid for.
  bool _awaitsPayment(dynamic event) {
    if (event is! Map || !isAwaitingPayment(event)) return false;
    if (filterType == 'past') return false;
    return filterType == 'registered' || event['is_registered'] == true;
  }
}

/// Search delegate for CLUBS ONLY - used on clubs page.
class ClubSearchDelegate extends SearchDelegate<String> {
  /// Searched once typing pauses; only the latest query's answer shows.
  final LatestSearch _search;

  /// [fetch] (the items for an endpoint) and [debounce] are for tests.
  ClubSearchDelegate({
    Future<List<dynamic>> Function(String endpoint)? fetch,
    Duration debounce = searchDebounce,
  }) : _search = LatestSearch(
          fetch: (q) => (fetch ?? _searchItems)(clubSearchEndpoint(q)),
          errorMessage: _searchFailed,
          debounce: debounce,
        );

  @override
  String get searchFieldLabel => 'Search for clubs...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.grey),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, ''),
    );
  }

  @override
  void close(BuildContext context, String result) {
    _search.cancel();
    super.close(context, result);
  }

  @override
  Widget buildResults(BuildContext context) {
    _search.submit(query);
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    _search.update(query);
    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Search for clubs',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) => _searchAnswerView(
        search: _search,
        query: () => query,
        emptyLine: 'No clubs found for "$query"',
        tile: _buildClubTile,
      );

  /// The club's logo, or a grey disc with a group icon when it has none or
  /// it fails -- not a placeholder service's image.
  Widget _clubAvatar(Object? url) {
    final hasUrl = url is String && url.trim().isNotEmpty;
    return CircleAvatar(
      backgroundColor: const Color(0xFFF3F3F3),
      foregroundImage: hasUrl
          // A 40pt disc: 160px is enough on any phone's screen.
          ? appImageProvider(url, decodeWidth: 160)
          : null,
      onForegroundImageError: hasUrl ? (_, __) {} : null,
      child: const Icon(Icons.group, color: Colors.grey),
    );
  }

  Widget _buildClubTile(BuildContext context, dynamic club) {
    return ListTile(
      leading: _clubAvatar(imageUrlFrom(club['logo'])),
      title: Text(club['name'] ?? 'Unnamed Club'),
      subtitle: Text('${club['followers_count'] ?? 0} followers'),
      onTap: () {
        close(context, '');
        context.push(
          '/clubs/${club['id']}',
          extra: {
            'clubId': club['id'],
            'clubSlug': club['slug'] ?? '',
            'clubname': club['name'] ?? '',
          },
        );
      },
    );
  }
}
