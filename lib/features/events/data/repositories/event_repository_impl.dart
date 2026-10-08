import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/features/events/data/datasources/event_remote_datasource.dart';
import 'package:finnet/features/events/domain/entities/event_entity.dart'
    as domain;
import 'package:finnet/features/events/domain/repositories/event_repository.dart';

/// Provider for the event repository.
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final remoteDataSource = ref.watch(eventRemoteDataSourceProvider);
  return EventRepositoryImpl(remoteDataSource: remoteDataSource);
});

/// Implementation of event repository.
class EventRepositoryImpl implements EventRepository {
  final EventRemoteDataSource remoteDataSource;

  EventRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<List<domain.EventListItem>>> getEvents({
    int? page,
    int? limit,
    int? categoryId,
    List<int>? interestIds,
    bool? isOnline,
    bool? isFree,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final response = await remoteDataSource.getEvents(
        page: page,
        limit: limit,
        categoryId: categoryId,
        interestIds: interestIds,
        isOnline: isOnline,
        isFree: isFree,
        startDate: startDate,
        endDate: endDate,
      );
      return Either.right(response.map((e) => e.toListItem()).toList());
    } catch (e) {
      debugPrint('EventRepository.getEvents error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<domain.EventListItem>>> getForYouEvents({
    int? page,
    int? limit,
  }) async {
    try {
      final response = await remoteDataSource.getForYouEvents(
        page: page,
        limit: limit,
      );
      return Either.right(response.map((e) => e.toListItem()).toList());
    } catch (e) {
      debugPrint('EventRepository.getForYouEvents error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<domain.EventListItem>>> getFollowingEvents({
    int? page,
    int? limit,
  }) async {
    try {
      final response = await remoteDataSource.getFollowingEvents(
        page: page,
        limit: limit,
      );
      return Either.right(response.map((e) => e.toListItem()).toList());
    } catch (e) {
      debugPrint('EventRepository.getFollowingEvents error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<domain.Event>> getEventDetails(int eventId) async {
    try {
      final response = await remoteDataSource.getEventDetails(eventId);
      return Either.right(response.toEntity());
    } catch (e) {
      debugPrint('EventRepository.getEventDetails error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<void>> registerForEvent(
    int eventId, {
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await remoteDataSource.registerForEvent(eventId,
          additionalData: additionalData);
      return Either.right(null);
    } catch (e) {
      debugPrint('EventRepository.registerForEvent error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<void>> cancelRegistration(int eventId) async {
    try {
      await remoteDataSource.cancelRegistration(eventId);
      return Either.right(null);
    } catch (e) {
      debugPrint('EventRepository.cancelRegistration error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<domain.EventListItem>>> getMyRegistrations({
    int? page,
    int? limit,
  }) async {
    try {
      final response = await remoteDataSource.getMyRegistrations(
        page: page,
        limit: limit,
      );
      return Either.right(response.map((e) => e.toListItem()).toList());
    } catch (e) {
      debugPrint('EventRepository.getMyRegistrations error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }

  @override
  Future<Result<List<domain.Category>>> getCategories() async {
    try {
      final response = await remoteDataSource.getCategories();
      return Either.right(response.map((e) => e.toEntity()).toList());
    } catch (e) {
      debugPrint('EventRepository.getCategories error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }
}
