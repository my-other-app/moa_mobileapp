import 'package:flutter/material.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';

/// Search delegate for EVENTS ONLY - used on home and events pages.
/// Supports tab-based filtering (for_you, following, registered, past).
class EventSearchDelegate extends SearchDelegate<String> {
  List<dynamic> _events = [];
  String? _error;
  String _lastSearchedQuery = '';

  /// Filter type based on current tab context
  /// Values: 'for_you', 'following', 'registered', 'past'
  final String filterType;

  EventSearchDelegate({
    this.filterType = 'for_you',
  });

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
            _events = [];
            _lastSearchedQuery = '';
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
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
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

  Widget _buildSearchResults(BuildContext context) {
    if (query != _lastSearchedQuery && query.isNotEmpty) {
      _lastSearchedQuery = query;
      return FutureBuilder(
        future: _search(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildResultsList(context);
        },
      );
    }
    return _buildResultsList(context);
  }

  Widget _buildResultsList(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _error = null;
                _lastSearchedQuery = '';
                showResults(context);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty && _lastSearchedQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No events found for "$query"',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _events.length,
      itemBuilder: (context, index) => _buildEventTile(context, _events[index]),
    );
  }

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
      subtitle: Text(event['club']?['name'] ?? ''),
      trailing: Container(
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

  Future<void> _search(String q) async {
    if (q.isEmpty) return;

    _error = null;

    try {
      // Build query params based on filter type
      String endpoint = '/events/list?search=$q&offset=0&limit=20';

      switch (filterType) {
        case 'following':
          endpoint += '&is_following=true';
          break;
        case 'registered':
          endpoint += '&is_registered=true&is_ended=false';
          break;
        case 'past':
          endpoint += '&is_registered=true&is_ended=true';
          break;
        // 'for_you' - no additional filter, shows all events
      }

      final response = await APIService.instance.request(
        endpoint,
        DioMethod.get,
      );
      _events = response.data['items'] ?? [];
    } catch (e) {
      _error = extractErrorMessage(
        e,
        defaultMessage: 'Search failed. Please try again.',
      );
      debugPrint('Event search error: $e');
    }
  }
}

/// Search delegate for CLUBS ONLY - used on clubs page.
class ClubSearchDelegate extends SearchDelegate<String> {
  List<dynamic> _clubs = [];
  String? _error;
  String _lastSearchedQuery = '';

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
            _clubs = [];
            _lastSearchedQuery = '';
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
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
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

  Widget _buildSearchResults(BuildContext context) {
    if (query != _lastSearchedQuery && query.isNotEmpty) {
      _lastSearchedQuery = query;
      return FutureBuilder(
        future: _search(query),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildResultsList(context);
        },
      );
    }
    return _buildResultsList(context);
  }

  Widget _buildResultsList(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _error = null;
                _lastSearchedQuery = '';
                showResults(context);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_clubs.isEmpty && _lastSearchedQuery.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No clubs found for "$query"',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _clubs.length,
      itemBuilder: (context, index) => _buildClubTile(context, _clubs[index]),
    );
  }

  /// The club's logo, or a grey disc with a group icon when it has none or
  /// it fails -- not a placeholder service's image.
  Widget _clubAvatar(Object? url) {
    final hasUrl = url is String && url.trim().isNotEmpty;
    return CircleAvatar(
      backgroundColor: const Color(0xFFF3F3F3),
      foregroundImage: hasUrl ? NetworkImage(url) : null,
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

  Future<void> _search(String q) async {
    if (q.isEmpty) return;

    _error = null;

    try {
      final response = await APIService.instance.request(
        '/clubs/list?search=$q&offset=0&limit=20',
        DioMethod.get,
      );
      _clubs = response.data['items'] ?? [];
    } catch (e) {
      _error = extractErrorMessage(
        e,
        defaultMessage: 'Search failed. Please try again.',
      );
      debugPrint('Club search error: $e');
    }
  }
}
