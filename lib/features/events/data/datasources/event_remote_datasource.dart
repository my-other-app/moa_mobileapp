import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/events/data/models/event_models.dart';

/// Provider for the event remote data source.
final eventRemoteDataSourceProvider = Provider<EventRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return EventRemoteDataSourceImpl(dio);
});

/// Abstract interface for remote event operations.
///
/// Every path here is checked against `app/api/events/router.py` and
/// `app/api/events/registration/router.py`. The previous version was not:
/// all eight of its calls addressed routes the server has never had
/// (`/events`, `/events/following`, `GET /events/{id}`, `/categories`,
/// `/user/registrations`, ...), sent `page` where the server reads `offset`,
/// and unpacked `results` from an envelope whose list is called `items`.
///
/// It went unnoticed because no screen uses this layer -- the event pages
/// still call APIService directly with the correct paths. The first screen
/// moved onto it would have found every list silently empty, because the
/// wrong envelope key hits the `?? []` fallback and returns nothing without
/// an error.
abstract class EventRemoteDataSource {
  /// One page of events, with whichever filters apply.
  ///
  /// `GET /events/list` is the server's only general event listing.
  Future<List<EventModel>> getEvents({
    int? page,
    int? limit,
    int? categoryId,
    List<int>? interestIds,
    String? search,
    bool? isEnded,
  });

  /// The personalised feed, ranked server-side.
  Future<List<EventModel>> getForYouEvents({int? page, int? limit});

  /// Events from clubs the user follows.
  Future<List<EventModel>> getFollowingEvents({int? page, int? limit});

  /// Get event details.
  Future<EventModel> getEventDetails(int eventId);

  /// Register for an event.
  Future<void> registerForEvent(
    int eventId, {
    required String fullName,
    required String email,
    required String phone,
    Map<String, dynamic>? additionalDetails,
  });

  /// Events the user has registered for.
  Future<List<EventModel>> getMyRegistrations({
    int? page,
    int? limit,
    bool? isEnded,
  });

  /// Get event categories.
  Future<List<CategoryModel>> getCategories();
}

/// Implementation of event remote data source.
class EventRemoteDataSourceImpl implements EventRemoteDataSource {
  final Dio _dio;

  EventRemoteDataSourceImpl(this._dio);

  /// Matches the server's own default for `limit`.
  static const _defaultLimit = 10;

  /// Build the pagination the server expects.
  ///
  /// It reads `offset`, not `page`. `page` is kept in the domain because
  /// that is how the callers count, and converted here.
  Map<String, dynamic> _paging(int? page, int? limit) {
    final size = limit ?? _defaultLimit;
    return <String, dynamic>{
      'limit': size,
      'offset': page == null ? 0 : (page - 1).clamp(0, 1 << 30) * size,
    };
  }

  /// Unpack the paginated envelope.
  ///
  /// The list is under `items` -- `PaginatedResponse` in
  /// `app/core/response/pagination.py`. Reading `results` instead returned
  /// the empty fallback on every call, with no error to show for it.
  List<EventModel> _eventsFrom(Map<String, dynamic>? body) {
    final items = (body?['items'] as List<dynamic>?) ?? const [];
    return items
        .whereType<Map<String, dynamic>>()
        .map(EventModel.fromJson)
        .toList();
  }

  @override
  Future<List<EventModel>> getEvents({
    int? page,
    int? limit,
    int? categoryId,
    List<int>? interestIds,
    String? search,
    bool? isEnded,
  }) async {
    final queryParams = _paging(page, limit);
    if (interestIds != null && interestIds.isNotEmpty) {
      queryParams['interest_ids'] = interestIds.join(',');
    }
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (isEnded != null) queryParams['is_ended'] = isEnded;
    // `category_id`, `is_online`, `is_free`, `start_date` and `end_date` are
    // deliberately absent: /events/list does not accept them, and FastAPI
    // ignores unknown query parameters, so sending them looked like
    // filtering while returning everything.

    final response = await _dio.get<Map<String, dynamic>>(
      '/events/list',
      queryParameters: queryParams,
    );
    return _eventsFrom(response.data);
  }

  @override
  Future<List<EventModel>> getForYouEvents({int? page, int? limit}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/for-you',
      queryParameters: _paging(page, limit),
    );
    return _eventsFrom(response.data);
  }

  @override
  Future<List<EventModel>> getFollowingEvents({int? page, int? limit}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/list',
      queryParameters: {
        ..._paging(page, limit),
        'is_following': true,
        // Finished events are not something to follow up on in a feed.
        'is_ended': false,
      },
    );
    return _eventsFrom(response.data);
  }

  @override
  Future<EventModel> getEventDetails(int eventId) async {
    final response =
        await _dio.get<Map<String, dynamic>>('/events/info/$eventId');
    return EventModel.fromJson(response.data ?? const <String, dynamic>{});
  }

  @override
  Future<void> registerForEvent(
    int eventId, {
    required String fullName,
    required String email,
    required String phone,
    Map<String, dynamic>? additionalDetails,
  }) async {
    // The endpoint lives under the registration sub-router, and the server
    // requires the submitted email to match the signed-in user.
    await _dio.post<dynamic>(
      '/events/registration/$eventId/register',
      data: {
        'full_name': fullName,
        'email': email,
        'phone': phone,
        if (additionalDetails != null) 'additional_details': additionalDetails,
      },
    );
  }

  @override
  Future<List<EventModel>> getMyRegistrations({
    int? page,
    int? limit,
    bool? isEnded,
  }) async {
    // There is no /user/registrations: the user's own registrations are the
    // event list filtered by is_registered.
    final response = await _dio.get<Map<String, dynamic>>(
      '/events/list',
      queryParameters: {
        ..._paging(page, limit),
        'is_registered': true,
        if (isEnded != null) 'is_ended': isEnded,
      },
    );
    return _eventsFrom(response.data);
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response =
        await _dio.get<List<dynamic>>('/events/categories/list');
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList();
  }
}
