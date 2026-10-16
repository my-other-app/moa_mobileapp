import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:finnet/shared/widgets/event_cover.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/core/utils/error_utils.dart';

/// Page to display club's events (past or upcoming)
class ClubEventsPage extends StatefulWidget {
  final int clubId;
  final String clubName;
  final String clubLogo;
  final bool isPastEvents;

  const ClubEventsPage({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.clubLogo,
    required this.isPastEvents,
  });

  @override
  State<ClubEventsPage> createState() => _ClubEventsPageState();
}

class _ClubEventsPageState extends State<ClubEventsPage> {
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

    try {
      final Response res = await APIService.instance.request(
        '/clubs/${widget.clubId}/events',
        DioMethod.get,
        param: {
          'limit': _limit,
          'offset': _offset,
          'is_ended': widget.isPastEvents,
        },
      );

      final List<Map<String, dynamic>> newEvents =
          List<Map<String, dynamic>>.from(res.data['items'] ?? []);

      setState(() {
        _events.addAll(newEvents);
        _filteredEvents = List.from(_events);
        _offset += newEvents.length;
        _hasMore = newEvents.length >= _limit;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = extractErrorMessage(
          e,
          defaultMessage: 'Could not load this club\'s events.',
        );
        _isLoading = false;
      });
    }
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

          final event = _filteredEvents[index];
          return EventCard(
            clubSlug: event['club']?['slug'] ?? '',
            // Use club logo from widget if event's club logo is missing
            orgImage: event['club']?['logo']?['thumbnail'] ?? widget.clubLogo,
            title: event['name'] ?? 'No Title',
            organizer: event['club']?['name'] ?? widget.clubName,
            tags: [
              event['category']?['name'] ?? '',
              event['is_online'] == true ? 'Online' : 'Offline',
              event['has_fee'] == true ? 'Paid' : 'Free',
              '${event['duration']} Hours'
            ],
            onTap: () {},
            poster: event['poster'],
            categoryId: event['category']?['id'],
            categoryName: event['category']?['name'],
            startsAt: parseEventStart(event['event_datetime']),
            isOnline: event['is_online'] == true,
            eventId: event['id'],
            clubId: event['club']?['id'] ?? widget.clubId,
            eventSlug: event['slug'] ?? '',
            status: widget.isPastEvents
                ? EventCardStatus.none
                : EventCardStatus.none,
            showShareIcon: !widget.isPastEvents,
          );
        },
      ),
    );
  }
}
