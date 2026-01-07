import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:myotherapp/features/events/presentation/providers/events_provider.dart';
import 'package:myotherapp/features/events/domain/entities/event_entity.dart';
import 'package:myotherapp/features/home/presentation/providers/home_provider.dart';

/// Home page with For You and Following tabs.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(currentHomeTabProvider.notifier).state =
            _tabController.index == 0 ? HomeTab.forYou : HomeTab.following;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(forYouEventsProvider.notifier).loadEvents();
      ref.read(followingEventsProvider.notifier).loadEvents();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Home',
          style:
              TextStyle(color: Color(0xFF1a1a2e), fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Color(0xFF1a1a2e)),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF17A58F),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF17A58F),
          tabs: const [Tab(text: 'FOR YOU'), Tab(text: 'FOLLOWING')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_ForYouEventsTab(), _FollowingEventsTab()],
      ),
    );
  }
}

class _ForYouEventsTab extends ConsumerWidget {
  const _ForYouEventsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(forYouEventsProvider);

    if (state.isLoading && state.events.isEmpty) {
      return _buildShimmerList();
    }
    if (state.error != null && state.events.isEmpty) {
      return _buildErrorState(state.error!,
          () => ref.read(forYouEventsProvider.notifier).loadEvents());
    }
    if (state.events.isEmpty) {
      return _buildEmptyState('No events to show.\nCheck back soon!');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(forYouEventsProvider.notifier).refresh(),
      child: _EventsList(
        events: state.events,
        isLoadingMore: state.isLoadingMore,
        hasMore: state.hasMore,
        onLoadMore: () =>
            ref.read(forYouEventsProvider.notifier).loadMoreEvents(),
      ),
    );
  }
}

class _FollowingEventsTab extends ConsumerWidget {
  const _FollowingEventsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(followingEventsProvider);

    if (state.isLoading && state.events.isEmpty) return _buildShimmerList();
    if (state.error != null && state.events.isEmpty) {
      return _buildErrorState(state.error!,
          () => ref.read(followingEventsProvider.notifier).loadEvents());
    }
    if (state.events.isEmpty) {
      return _buildEmptyState(
          'No events from clubs you follow.\nStart following clubs to see their events!');
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(followingEventsProvider.notifier).refresh(),
      child: _EventsList(
        events: state.events,
        isLoadingMore: state.isLoadingMore,
        hasMore: state.hasMore,
        onLoadMore: () =>
            ref.read(followingEventsProvider.notifier).loadMoreEvents(),
      ),
    );
  }
}

class _EventsList extends StatelessWidget {
  final List<EventListItem> events;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const _EventsList({
    required this.events,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            hasMore &&
            !isLoadingMore) {
          onLoadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: events.length + (isLoadingMore ? 1 : 0),
        separatorBuilder: (context, index) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(thickness: 0.5),
        ),
        itemBuilder: (context, index) {
          if (index >= events.length) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator()));
          }
          return _EventCard(event: events[index]);
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final EventListItem event;

  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed('eventDetail',
          pathParameters: {'eventId': event.id.toString()}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200]),
                child: event.club.logo?.thumbnail != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(event.club.logo!.thumbnail!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const Icon(Icons.business, color: Colors.grey)))
                    : const Icon(Icons.business, color: Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1a1a2e)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text(event.club.name,
                        style:
                            TextStyle(fontSize: 14, color: Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (event.poster?.medium != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(event.poster!.medium!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      height: 200,
                      color: Colors.grey[200],
                      child: const Center(
                          child: Icon(Icons.image,
                              size: 48, color: Colors.grey)))),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTag(event.category.name),
              _buildTag(event.isOnline ? 'Online' : 'Offline'),
              _buildTag(event.hasFee ? 'Paid' : 'Free'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
      child:
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
    );
  }
}

Widget _buildShimmerList() {
  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: 3,
    itemBuilder: (context, index) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 200, height: 16, color: Colors.white),
                const SizedBox(height: 8),
                Container(width: 120, height: 12, color: Colors.white),
              ]),
            ]),
            const SizedBox(height: 16),
            Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12))),
          ],
        ),
      ),
    ),
  );
}

Widget _buildErrorState(String error, VoidCallback onRetry) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF17A58F)),
              child: const Text('Retry')),
        ],
      ),
    ),
  );
}

Widget _buildEmptyState(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.event_busy, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    ),
  );
}
