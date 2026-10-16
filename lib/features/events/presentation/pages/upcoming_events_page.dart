import 'package:flutter/material.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:finnet/shared/widgets/event_cover.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/features/events/presentation/pages/no_registered_event_page.dart';
import 'package:finnet/core/utils/error_utils.dart';

class UpcomingEventsPage extends StatefulWidget {
  const UpcomingEventsPage({super.key});

  @override
  State<UpcomingEventsPage> createState() => _UpcomingEventsPageState();
}

class _UpcomingEventsPageState extends State<UpcomingEventsPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final List<dynamic> _events = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  int _offset = 0;
  static const int _limit = 10;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (metrics.pixels >= metrics.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          _hasMore &&
          !_isLoading) {
        _loadMore();
      }
    }
    return false;
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _offset = 0;
      _events.clear();
    });

    try {
      final res = await APIService.instance.request(
        '/events/list?is_registered=true&is_ended=false&offset=$_offset&limit=$_limit',
        DioMethod.get,
      );
      if (mounted) {
        setState(() {
          _events.addAll(res.data['items'] ?? []);
          _hasMore = (res.data['items'] ?? []).length >= _limit;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = extractErrorMessage(
          e,
          defaultMessage: 'Could not load upcoming events.',
        );
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
      _offset += _limit;
    });

    try {
      final res = await APIService.instance.request(
        '/events/list?is_registered=true&is_ended=false&offset=$_offset&limit=$_limit',
        DioMethod.get,
      );
      if (mounted) {
        setState(() {
          _events.addAll(res.data['items'] ?? []);
          _hasMore = (res.data['items'] ?? []).length >= _limit;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _offset -= _limit;
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    await _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Container(
        color: Colors.white,
        child: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              ShimmerEventCard(),
              SizedBox(height: 32),
              ShimmerEventCard(),
              SizedBox(height: 32),
              ShimmerEventCard(),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        color: Colors.white,
        child: ErrorView(
          message: _errorMessage,
          onRetry: _fetchData,
        ),
      );
    }

    if (_events.isEmpty) {
      return NoRegisteredEventPage();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          primary: true,
          padding: const EdgeInsets.all(16),
          itemCount: _events.length + (_hasMore ? 1 : 0),
          separatorBuilder: (context, index) => const Padding(
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

            final event = _events[index];
            return EventCard(
              clubSlug: event['club']?['slug'] ?? '',
              orgImage: event['club']?['logo']?['thumbnail'] ?? '',
              title: event['name'] ?? 'No Title',
              organizer: event['club']?['name'] ?? 'Unknown Organizer',
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
              clubId: event['club']['id'],
              eventSlug: event['slug'],
              status: EventCardStatus.registered,
              ticketUrl: event['ticket_url'],
            );
          },
        ),
      ),
    );
  }
}
