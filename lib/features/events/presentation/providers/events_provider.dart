import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/features/events/data/repositories/event_repository_impl.dart';
import 'package:myotherapp/features/events/domain/entities/event_entity.dart';
import 'package:myotherapp/features/events/domain/repositories/event_repository.dart';

/// State for events list.
class EventsState {
  final List<EventListItem> events;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;

  const EventsState({
    this.events = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
  });

  EventsState copyWith({
    List<EventListItem>? events,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? currentPage,
    bool? hasMore,
  }) {
    return EventsState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

/// Provider for "For You" events.
final forYouEventsProvider =
    StateNotifierProvider<EventsNotifier, EventsState>((ref) {
  final repository = ref.watch(eventRepositoryProvider);
  return EventsNotifier(repository, EventsType.forYou);
});

/// Provider for "Following" events.
final followingEventsProvider =
    StateNotifierProvider<EventsNotifier, EventsState>((ref) {
  final repository = ref.watch(eventRepositoryProvider);
  return EventsNotifier(repository, EventsType.following);
});

/// Type of events to fetch.
enum EventsType { forYou, following, all }

/// Notifier for events list operations.
class EventsNotifier extends StateNotifier<EventsState> {
  final EventRepository _repository;
  final EventsType _type;
  static const int _pageSize = 10;

  EventsNotifier(this._repository, this._type) : super(const EventsState());

  /// Load initial events.
  Future<void> loadEvents() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    final result = await _fetchEvents(page: 1);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (events) {
        state = state.copyWith(
          isLoading: false,
          events: events,
          currentPage: 1,
          hasMore: events.length >= _pageSize,
        );
      },
    );
  }

  /// Load more events (pagination).
  Future<void> loadMoreEvents() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    final nextPage = state.currentPage + 1;
    final result = await _fetchEvents(page: nextPage);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoadingMore: false,
          error: failure.message,
        );
      },
      (newEvents) {
        state = state.copyWith(
          isLoadingMore: false,
          events: [...state.events, ...newEvents],
          currentPage: nextPage,
          hasMore: newEvents.length >= _pageSize,
        );
      },
    );
  }

  /// Refresh events.
  Future<void> refresh() async {
    state = const EventsState();
    await loadEvents();
  }

  Future<dynamic> _fetchEvents({required int page}) async {
    switch (_type) {
      case EventsType.forYou:
        return _repository.getForYouEvents(page: page, limit: _pageSize);
      case EventsType.following:
        return _repository.getFollowingEvents(page: page, limit: _pageSize);
      case EventsType.all:
        return _repository.getEvents(page: page, limit: _pageSize);
    }
  }
}

/// State for event details.
class EventDetailState {
  final Event? event;
  final bool isLoading;
  final String? error;
  final bool isRegistering;
  final bool isRegistered;

  const EventDetailState({
    this.event,
    this.isLoading = false,
    this.error,
    this.isRegistering = false,
    this.isRegistered = false,
  });

  EventDetailState copyWith({
    Event? event,
    bool? isLoading,
    String? error,
    bool? isRegistering,
    bool? isRegistered,
  }) {
    return EventDetailState(
      event: event ?? this.event,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isRegistering: isRegistering ?? this.isRegistering,
      isRegistered: isRegistered ?? this.isRegistered,
    );
  }
}

/// Provider for event details.
final eventDetailProvider =
    StateNotifierProvider.family<EventDetailNotifier, EventDetailState, int>(
  (ref, eventId) {
    final repository = ref.watch(eventRepositoryProvider);
    return EventDetailNotifier(repository, eventId);
  },
);

/// Notifier for event detail operations.
class EventDetailNotifier extends StateNotifier<EventDetailState> {
  final EventRepository _repository;
  final int _eventId;

  EventDetailNotifier(this._repository, this._eventId)
      : super(const EventDetailState());

  /// Load event details.
  Future<void> loadEventDetails() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.getEventDetails(_eventId);

    result.fold(
      (failure) {
        state = state.copyWith(
          isLoading: false,
          error: failure.message,
        );
      },
      (event) {
        state = state.copyWith(
          isLoading: false,
          event: event,
        );
      },
    );
  }

  /// Register for the event.
  Future<bool> registerForEvent({Map<String, dynamic>? additionalData}) async {
    state = state.copyWith(isRegistering: true, error: null);

    final result = await _repository.registerForEvent(
      _eventId,
      additionalData: additionalData,
    );

    return result.fold(
      (failure) {
        state = state.copyWith(
          isRegistering: false,
          error: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          isRegistering: false,
          isRegistered: true,
        );
        return true;
      },
    );
  }

  /// Cancel registration.
  Future<bool> cancelRegistration() async {
    state = state.copyWith(isRegistering: true, error: null);

    final result = await _repository.cancelRegistration(_eventId);

    return result.fold(
      (failure) {
        state = state.copyWith(
          isRegistering: false,
          error: failure.message,
        );
        return false;
      },
      (_) {
        state = state.copyWith(
          isRegistering: false,
          isRegistered: false,
        );
        return true;
      },
    );
  }
}

/// Provider for event categories.
final eventCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  final result = await repository.getCategories();
  return result.fold(
    (failure) {
      debugPrint('Failed to load categories: ${failure.message}');
      return [];
    },
    (categories) => categories,
  );
});

/// Provider for user's registrations.
final myRegistrationsProvider =
    StateNotifierProvider<EventsNotifier, EventsState>((ref) {
  final repository = ref.watch(eventRepositoryProvider);
  return _MyRegistrationsNotifier(repository);
});

class _MyRegistrationsNotifier extends EventsNotifier {
  _MyRegistrationsNotifier(EventRepository repository)
      : super(repository, EventsType.all);

  @override
  Future<dynamic> _fetchEvents({required int page}) {
    return _repository.getMyRegistrations(page: page, limit: 10);
  }
}
