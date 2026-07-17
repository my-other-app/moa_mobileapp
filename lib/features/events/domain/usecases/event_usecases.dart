import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/usecases/usecase.dart';
import 'package:finnet/features/events/domain/entities/event_entity.dart';
import 'package:finnet/features/events/domain/repositories/event_repository.dart';

/// Parameters for getting events list.
class GetEventsParams {
  final int? page;
  final int? limit;
  final int? categoryId;
  final List<int>? interestIds;
  final bool? isOnline;
  final bool? isFree;
  final DateTime? startDate;
  final DateTime? endDate;

  const GetEventsParams({
    this.page,
    this.limit,
    this.categoryId,
    this.interestIds,
    this.isOnline,
    this.isFree,
    this.startDate,
    this.endDate,
  });
}

/// Use case for getting events list.
class GetEventsUseCase extends UseCase<List<EventListItem>, GetEventsParams> {
  final EventRepository repository;

  GetEventsUseCase(this.repository);

  @override
  Future<Result<List<EventListItem>>> call(GetEventsParams params) {
    return repository.getEvents(
      page: params.page,
      limit: params.limit,
      categoryId: params.categoryId,
      interestIds: params.interestIds,
      isOnline: params.isOnline,
      isFree: params.isFree,
      startDate: params.startDate,
      endDate: params.endDate,
    );
  }
}

/// Parameters for pagination.
class PaginationParams {
  final int? page;
  final int? limit;

  const PaginationParams({this.page, this.limit});
}

/// Use case for getting "For You" events.
class GetForYouEventsUseCase
    extends UseCase<List<EventListItem>, PaginationParams> {
  final EventRepository repository;

  GetForYouEventsUseCase(this.repository);

  @override
  Future<Result<List<EventListItem>>> call(PaginationParams params) {
    return repository.getForYouEvents(
      page: params.page,
      limit: params.limit,
    );
  }
}

/// Use case for getting events from followed clubs.
class GetFollowingEventsUseCase
    extends UseCase<List<EventListItem>, PaginationParams> {
  final EventRepository repository;

  GetFollowingEventsUseCase(this.repository);

  @override
  Future<Result<List<EventListItem>>> call(PaginationParams params) {
    return repository.getFollowingEvents(
      page: params.page,
      limit: params.limit,
    );
  }
}

/// Use case for getting event details.
class GetEventDetailsUseCase extends UseCase<Event, int> {
  final EventRepository repository;

  GetEventDetailsUseCase(this.repository);

  @override
  Future<Result<Event>> call(int eventId) {
    return repository.getEventDetails(eventId);
  }
}

/// Parameters for event registration.
class RegisterEventParams {
  final int eventId;
  final Map<String, dynamic>? additionalData;

  const RegisterEventParams({
    required this.eventId,
    this.additionalData,
  });
}

/// Use case for registering for an event.
class RegisterForEventUseCase extends UseCase<void, RegisterEventParams> {
  final EventRepository repository;

  RegisterForEventUseCase(this.repository);

  @override
  Future<Result<void>> call(RegisterEventParams params) {
    return repository.registerForEvent(
      params.eventId,
      additionalData: params.additionalData,
    );
  }
}

/// Use case for canceling event registration.
class CancelRegistrationUseCase extends UseCase<void, int> {
  final EventRepository repository;

  CancelRegistrationUseCase(this.repository);

  @override
  Future<Result<void>> call(int eventId) {
    return repository.cancelRegistration(eventId);
  }
}

/// Use case for getting user's event registrations.
class GetMyRegistrationsUseCase
    extends UseCase<List<EventListItem>, PaginationParams> {
  final EventRepository repository;

  GetMyRegistrationsUseCase(this.repository);

  @override
  Future<Result<List<EventListItem>>> call(PaginationParams params) {
    return repository.getMyRegistrations(
      page: params.page,
      limit: params.limit,
    );
  }
}

/// Use case for getting event categories.
class GetCategoriesUseCase extends NoParamsUseCase<List<Category>> {
  final EventRepository repository;

  GetCategoriesUseCase(this.repository);

  @override
  Future<Result<List<Category>>> call() {
    return repository.getCategories();
  }
}
