import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/core/utils/error_utils.dart';

/// Page to display club's events (past or upcoming).
///
/// Signed in, from `/clubs/{id}/events`. Signed out that answers 401, so
/// the club's public list is read instead, as the website does:
/// `/discover/clubs/{slug}/events?when=past|upcoming`.
class ClubEventsPage extends ConsumerStatefulWidget {
  final int clubId;

  /// What the public list is read by, signed out.
  final String clubSlug;
  final String clubName;
  final String clubLogo;
  final bool isPastEvents;

  const ClubEventsPage({
    super.key,
    required this.clubId,
    this.clubSlug = '',
    required this.clubName,
    required this.clubLogo,
    required this.isPastEvents,
  });

  @override
  ConsumerState<ClubEventsPage> createState() => _ClubEventsPageState();
}

class _ClubEventsPageState extends ConsumerState<ClubEventsPage> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _filteredEvents = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _hasMore = true;
  int _offset = 0;
  static const int _limit = 10;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_filterEvents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMore && !_isLoading) {
        _fetchEvents();
      }
    }
  }

  void _filterEvents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEvents = List.from(_events);
      } else {
        _filteredEvents = _events.where((event) {
          final name = (event['name'] ?? '').toString().toLowerCase();
          final category =
              (event['category']?['name'] ?? '').toString().toLowerCase();
          return name.contains(query) || category.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _fetchEvents() async {
    if (!_hasMore && _offset > 0) return;

    setState(() {
      _isLoading = true;
    });

    final public =
        !ref.read(isAuthenticatedProvider) && widget.clubSlug.trim().isNotEmpty;
    final path = public
        ? '/discover/clubs/${Uri.encodeComponent(widget.clubSlug.trim())}/events'
        : '/clubs/${widget.clubId}/events';
    final query = public
        ? {
            'when': widget.isPastEvents ? 'past' : 'upcoming',
            'offset': _offset,
            'limit': _limit,
          }
        : {
            'limit': _limit,
            'offset': _offset,
            'is_ended': widget.isPastEvents,
          };
    List<Map<String, dynamic>> eventsOf(Object? data) {
      final page = _eventsOf(data);
      return public ? page.map(discoverEventAsListItem).toList() : page;
    }

    try {
      if (_offset == 0) {
        // The first page: the saved copy at once, then the network's.
        await APIService.instance.getSavedThenFresh(
          path,
          param: query,
          onData: (data, {required fresh}) {
            if (!mounted) return;
            final page = eventsOf(data);
            setState(() {
              _events
                ..clear()
                ..addAll(page);
              _offset = page.length;
              _settle(page);
            });
          },
        );
      } else {
        final Response res = await APIService.instance.request(
          path,
          DioMethod.get,
          param: query,
        );
        if (!mounted) return;
        final page = eventsOf(res.data);
        setState(() {
          _events.addAll(page);
          _offset += page.length;
          _settle(page);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = extractErrorMessage(
          e,
          defaultMessage: 'Could not load this club\'s events.',
        );
        _isLoading = false;
      });
    }
  }

  void _settle(List<Map<String, dynamic>> page) {
    _filteredEvents = List.from(_events);
    _hasMore = page.length >= _limit;
    _isLoading = false;
    _errorMessage = null;
  }

  /// The events in an answer; anything that is not one is skipped rather
  /// than thrown on.
  static List<Map<String, dynamic>> _eventsOf(Object? data) {
    final items = data is Map ? data['items'] : null;
    return [
      if (items is List)
        for (final item in items)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  Future<void> _refresh() async {
    setState(() {
      _events.clear();
      _filteredEvents.clear();
      _offset = 0;
      _hasMore = true;
    });
    await _fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            SliverAppBar(
              floating: true,
              snap: true,
              pinned: false,
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                widget.clubName,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(100),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText:
                                'Search ${widget.isPastEvents ? 'past' : 'upcoming'} events...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            prefixIcon:
                                const Icon(Icons.search, color: Colors.grey),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      // Page title
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.isPastEvents
                                ? 'Past Events'
                                : 'Upcoming Events',
                            style: const TextStyle(
                              fontSize: 24,
                              fontFamily: 'BebasNeue',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ];
        },
        body: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _events.isEmpty) {
      return ShimmerList.events();
    }

    if (_errorMessage != null && _events.isEmpty) {
      return ErrorView(
        message: _errorMessage,
        onRetry: _refresh,
      );
    }

    if (_filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.isPastEvents ? Icons.history : Icons.event_available,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No events found'
                  : 'No ${widget.isPastEvents ? 'past' : 'upcoming'} events',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredEvents.length + (_hasMore && _isLoading ? 1 : 0),
        separatorBuilder: (context, index) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(
            color: Colors.black,
            indent: 50,
            endIndent: 50,
          ),
        ),
        itemBuilder: (context, index) {
          if (index == _filteredEvents.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          return eventCardFromJson(
            clubEventWithClub(
              _filteredEvents[index],
              clubId: widget.clubId,
              clubName: widget.clubName,
              clubLogo: widget.clubLogo,
            ),
            showShareIcon: !widget.isPastEvents,
          );
        },
      ),
    );
  }
}

/// [event] with the club whose page this is filled in where the item leaves
/// it out. Every event here is this club's, so the page's own id, name and
/// logo stand in for a missing (or logo-less) `club`; the card is then built
/// by [eventCardFromJson] like every other list's.
@visibleForTesting
Map<String, dynamic> clubEventWithClub(
  Map<String, dynamic> event, {
  required int clubId,
  required String clubName,
  required String clubLogo,
}) {
  final club = event['club'] is Map
      ? Map<String, dynamic>.from(event['club'] as Map)
      : <String, dynamic>{};
  final id = eventClubId(event);
  final name = club['name'];
  return {
    ...event,
    'club': {
      ...club,
      'id': id != 0 ? id : clubId,
      'name': name is String && name.trim().isNotEmpty ? name : clubName,
      'logo': imageUrlFrom(club['logo']) ?? clubLogo,
    },
  };
}

/// An event from the club's public list (`/discover/clubs/{slug}/events`,
/// the website's card) in the shape the app's lists send, so the same card
/// draws it.
@visibleForTesting
Map<String, dynamic> discoverEventAsListItem(Map<String, dynamic> card) {
  final starts = DateTime.tryParse('${card['starts_at'] ?? ''}');
  final ends = DateTime.tryParse('${card['ends_at'] ?? ''}');
  final hours = starts != null && ends != null && ends.isAfter(starts)
      ? ends.difference(starts).inMinutes / 60
      : null;
  return {
    'id': card['id'],
    'name': card['name'],
    'slug': card['slug'],
    'poster': card['poster'],
    'event_datetime': card['starts_at'],
    if (hours != null) 'duration': hours,
    'is_online': card['is_online'] == true,
    'has_fee': card['has_fee'] == true,
    'category': card['category'],
    'club': card['club'],
  };
}
