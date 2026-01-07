import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/network/dio_client.dart';
import 'package:myotherapp/features/events/data/models/event_models.dart';

/// Provider for the event remote data source.
final eventRemoteDataSourceProvider = Provider<EventRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return EventRemoteDataSourceImpl(dio);
});

/// Abstract interface for remote event operations.
abstract class EventRemoteDataSource {
  /// Get list of events.
  Future<List<EventModel>> getEvents({
    int? page,
    int? limit,
    int? categoryId,
    List<int>? interestIds,
    bool? isOnline,
    bool? isFree,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// Get "For You" events.
  Future<List<EventModel>> getForYouEvents({int? page, int? limit});

  /// Get events from followed clubs.
  Future<List<EventModel>> getFollowingEvents({int? page, int? limit});

  /// Get event details.
  Future<EventModel> getEventDetails(int eventId);

  /// Register for an event.
  Future<void> registerForEvent(int eventId,
      {Map<String, dynamic>? additionalData});

  /// Cancel event registration.
  Future<void> cancelRegistration(int eventId);

  /// Get user's event registrations.
  Future<List<EventModel>> getMyRegistrations({int? page, int? limit});

  /// Get event categories.
  Future<List<CategoryModel>> getCategories();
}

/// Implementation of event remote data source.
class EventRemoteDataSourceImpl implements EventRemoteDataSource {
  final Dio _dio;

  EventRemoteDataSourceImpl(this._dio);

  @override
  Future<List<EventModel>> getEvents({
    int? page,
    int? limit,
    int? categoryId,
    List<int>? interestIds,
    bool? isOnline,
    bool? isFree,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    if (limit != null) queryParams['limit'] = limit;
    if (categoryId != null) queryParams['category_id'] = categoryId;
    if (interestIds != null && interestIds.isNotEmpty) {
      queryParams['interest_ids'] = interestIds.join(',');
    }
    if (isOnline != null) queryParams['is_online'] = isOnline;
    if (isFree != null) queryParams['is_free'] = isFree;
    if (startDate != null) {
      queryParams['start_date'] = startDate.toIso8601String();
    }
    if (endDate != null) {
      queryParams['end_date'] = endDate.toIso8601String();
    }

    final response = await _dio.get('/events', queryParameters: queryParams);
    final List<dynamic> data = response.data['results'] as List<dynamic>? ??
        response.data as List<dynamic>? ??
        [];
    return data
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<EventModel>> getForYouEvents({int? page, int? limit}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    if (limit != null) queryParams['limit'] = limit;

    final response =
        await _dio.get('/events/for-you', queryParameters: queryParams);
    final List<dynamic> data = response.data['results'] as List<dynamic>? ??
        response.data as List<dynamic>? ??
        [];
    return data
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<EventModel>> getFollowingEvents({int? page, int? limit}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    if (limit != null) queryParams['limit'] = limit;

    final response =
        await _dio.get('/events/following', queryParameters: queryParams);
    final List<dynamic> data = response.data['results'] as List<dynamic>? ??
        response.data as List<dynamic>? ??
        [];
    return data
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<EventModel> getEventDetails(int eventId) async {
    final response = await _dio.get('/events/$eventId');
    return EventModel.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> registerForEvent(int eventId,
      {Map<String, dynamic>? additionalData}) async {
    await _dio.post(
      '/events/$eventId/register',
      data: additionalData,
    );
  }

  @override
  Future<void> cancelRegistration(int eventId) async {
    await _dio.delete('/events/$eventId/register');
  }

  @override
  Future<List<EventModel>> getMyRegistrations({int? page, int? limit}) async {
    final queryParams = <String, dynamic>{};
    if (page != null) queryParams['page'] = page;
    if (limit != null) queryParams['limit'] = limit;

    final response =
        await _dio.get('/user/registrations', queryParameters: queryParams);
    final List<dynamic> data = response.data['results'] as List<dynamic>? ??
        response.data as List<dynamic>? ??
        [];
    return data
        .map((e) => EventModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await _dio.get('/categories');
    final List<dynamic> data = response.data as List<dynamic>? ?? [];
    return data
        .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
