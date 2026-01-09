import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/core/api/api_helper.dart';

/// Custom search delegate that searches events and clubs from the API.
class CustomSearchDelegate extends SearchDelegate<String> {
  List<dynamic> _events = [];
  List<dynamic> _clubs = [];
  bool _isLoading = false;
  String? _error;

  @override
  String get searchFieldLabel => 'Search events, clubs...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            query = '';
            _events = [];
            _clubs = [];
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
              'Search for events or clubs',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return FutureBuilder(
      future: _search(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

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
                    showResults(context);
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (_events.isEmpty && _clubs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No results found for "$query"',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView(
          children: [
            // Events section
            if (_events.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'EVENTS',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._events.map((event) => _buildEventTile(context, event)),
            ],
            // Clubs section
            if (_clubs.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'CLUBS',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ..._clubs.map((club) => _buildClubTile(context, club)),
            ],
          ],
        );
      },
    );
  }

  Widget _buildEventTile(BuildContext context, dynamic event) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          event['poster']?['thumbnail'] ?? 'https://via.placeholder.com/50',
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: 50,
            height: 50,
            color: Colors.grey[200],
            child: const Icon(Icons.event),
          ),
        ),
      ),
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

  Widget _buildClubTile(BuildContext context, dynamic club) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(
          club['logo']?['thumbnail'] ?? 'https://via.placeholder.com/50',
        ),
        onBackgroundImageError: (_, __) {},
      ),
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
    if (q.isEmpty || _isLoading) return;

    _isLoading = true;
    _error = null;

    try {
      // Search events
      final eventsResponse = await APIService.instance.request(
        '/events/list?search=$q&offset=0&limit=5',
        DioMethod.get,
      );
      _events = eventsResponse.data['items'] ?? [];

      // Search clubs
      final clubsResponse = await APIService.instance.request(
        '/clubs/list?search=$q&offset=0&limit=5',
        DioMethod.get,
      );
      _clubs = clubsResponse.data['items'] ?? [];
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
    }
  }
}
