import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/features/events/presentation/providers/events_provider.dart';
import 'package:myotherapp/features/events/domain/entities/event_entity.dart';

/// Events page with categories filter.
class EventsPage extends ConsumerStatefulWidget {
  const EventsPage({super.key});

  @override
  ConsumerState<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends ConsumerState<EventsPage> {
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(forYouEventsProvider.notifier).loadEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(eventCategoriesProvider);
    final eventsState = ref.watch(forYouEventsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Events',
            style: TextStyle(
                color: Color(0xFF1a1a2e), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
              icon: const Icon(Icons.search, color: Color(0xFF1a1a2e)),
              onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          categoriesAsync.when(
            data: (categories) => _buildCategoriesFilter(categories),
            loading: () => const SizedBox(height: 50),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(child: _buildEventsList(eventsState)),
        ],
      ),
    );
  }

  Widget _buildCategoriesFilter(List<Category> categories) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildCategoryChip(
                label: 'All',
                isSelected: _selectedCategoryId == null,
                onTap: () {
                  setState(() => _selectedCategoryId = null);
                  ref.read(forYouEventsProvider.notifier).refresh();
                });
          }
          final category = categories[index - 1];
          return _buildCategoryChip(
            label: category.name,
            isSelected: _selectedCategoryId == category.id,
            onTap: () {
              setState(() => _selectedCategoryId = category.id);
              ref.read(forYouEventsProvider.notifier).refresh();
            },
          );
        },
      ),
    );
  }

  Widget _buildCategoryChip(
      {required String label,
      required bool isSelected,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF17A58F).withValues(alpha: 0.2),
        checkmarkColor: const Color(0xFF17A58F),
        labelStyle: TextStyle(
            color: isSelected ? const Color(0xFF17A58F) : Colors.grey[700]),
      ),
    );
  }

  Widget _buildEventsList(EventsState state) {
    if (state.isLoading && state.events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.events.isEmpty) {
      return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Error: ${state.error}'),
        const SizedBox(height: 16),
        ElevatedButton(
            onPressed: () =>
                ref.read(forYouEventsProvider.notifier).loadEvents(),
            child: const Text('Retry')),
      ]));
    }
    if (state.events.isEmpty) {
      return const Center(child: Text('No events found'));
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(forYouEventsProvider.notifier).refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: state.events.length,
        itemBuilder: (context, index) =>
            _EventGridCard(event: state.events[index]),
      ),
    );
  }
}

class _EventGridCard extends StatelessWidget {
  final EventListItem event;

  const _EventGridCard({required this.event});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.pushNamed('eventDetail',
          pathParameters: {'eventId': event.id.toString()}),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 1.2,
                child: event.poster?.thumbnail != null
                    ? Image.network(event.poster!.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.event, size: 40)))
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.event, size: 40)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(children: [
                      Icon(event.isOnline ? Icons.videocam : Icons.location_on,
                          size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(event.isOnline ? 'Online' : 'Offline',
                          style:
                              TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
