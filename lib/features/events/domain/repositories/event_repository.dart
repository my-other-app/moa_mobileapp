import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/events/domain/entities/event_entity.dart';

/// Repository interface for event operations.
abstract class EventRepository {
  /// Get list of events with optional filtering.
  Future<Result<List<EventListItem>>> getEvents({
    int? page,
    int? limit,
    int? categoryId,
    List<int>? interestIds,
    bool? isOnline,
    bool? isFree,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get events for the "For You" feed.
  Future<Result<List<EventListItem>>> getForYouEvents({
    int? page,
    int? limit,
  });

  /// Get events from clubs the user follows.
  Future<Result<List<EventListItem>>> getFollowingEvents({
    int? page,
    int? limit,
  });

  /// Get detailed event information.
  Future<Result<Event>> getEventDetails(int eventId);

  /// Register for an event.
  Future<Result<void>> registerForEvent(
    int eventId, {
    Map<String, dynamic>? additionalData,
  });

  /// Cancel event registration.
  Future<Result<void>> cancelRegistration(int eventId);

  /// Get list of events the user is registered for.
  Future<Result<List<EventListItem>>> getMyRegistrations({
    int? page,
    int? limit,
  });

  /// Get available event categories.
  Future<Result<List<Category>>> getCategories();
}
