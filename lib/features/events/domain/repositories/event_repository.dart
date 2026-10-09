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
    String? search,
    bool? isEnded,
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
  ///
  /// The server requires the submitted email to match the signed-in user,
  /// and validates additionalDetails against the event's own custom fields.
  Future<Result<void>> registerForEvent(
    int eventId, {
    required String fullName,
    required String email,
    required String phone,
    Map<String, dynamic>? additionalDetails,
  });

  // No cancelRegistration: the server has no route for it. It used to call
  // DELETE /events/{id}/register, which has never existed, so the only
  // caller -- EventDetailNotifier, itself unreachable from any screen --
  // would have reported a 404 as an unknown failure.

  /// Get list of events the user is registered for.
  Future<Result<List<EventListItem>>> getMyRegistrations({
    int? page,
    int? limit,
  });

  /// Get available event categories.
  Future<Result<List<Category>>> getCategories();
}
