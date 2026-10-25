import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/common/models/events/live_model.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/sse/sse_transport.dart';
import 'package:finnet/core/utils/error_utils.dart';

final liveRemoteDataSourceProvider = Provider<LiveRemoteDataSource>((ref) {
  return LiveRemoteDataSourceImpl(ref.watch(dioProvider));
});

/// The event's live room, as the event page reads it: the `room` view, and
/// the small `banner` view the LIVE NOW strip polls.
///
/// The poll and the stream carry the same body and are sent with the same
/// credentials: the app's Dio adds the signed-in person's token to both,
/// and neither sends a browser key (`X-Live-Key`) -- the page shows the
/// room's state, not one browser's votes.
abstract class LiveRemoteDataSource {
  /// The strip's view (`BannerFeed`: the event's status, start and end, and
  /// the banner): `GET /events/{id}/live/banner`, a few hundred bytes. A
  /// server without that route (today's) is asked for the whole room
  /// instead, which says the same and more; once it has said so, the room
  /// is asked straight away. Throws when the call fails.
  Future<LiveFeed?> fetchBanner(int eventId);

  /// `GET /events/{id}/live/stream?view=banner`. Every status is returned.
  Future<SseResponse> openBannerStream(
    int eventId, {
    String? lastEventId,
    Future<void>? abort,
  });

  /// `GET /events/{id}/live`: the room now, or null for a body that is not
  /// one. Throws when the call fails.
  Future<LiveFeed?> fetchRoom(int eventId);

  /// `GET /events/{id}/live/stream?view=room`, sending [lastEventId] as
  /// `Last-Event-ID`. Every status is returned, not thrown.
  Future<SseResponse> openRoomStream(
    int eventId, {
    String? lastEventId,
    Future<void>? abort,
  });
}

class LiveRemoteDataSourceImpl implements LiveRemoteDataSource {
  LiveRemoteDataSourceImpl(this._dio, {SseTransport? transport})
      : _transport = transport ?? DioSseTransport(_dio);

  final Dio _dio;
  final SseTransport _transport;

  /// The server has no `/live/banner`: it answered 404 (or 405) for it and
  /// then gave the room for the same event.
  bool _noBannerRoute = false;

  @override
  Future<LiveFeed?> fetchBanner(int eventId) async {
    if (_noBannerRoute) return fetchRoom(eventId);
    try {
      final response = await _dio.get<dynamic>('/events/$eventId/live/banner');
      return LiveFeed.tryParse(response.data);
    } catch (e) {
      final status = statusCodeOf(e);
      if (status != 404 && status != 405) rethrow;
    }
    // Today's server, or an event it can't find: the room says which.
    final room = await fetchRoom(eventId);
    _noBannerRoute = true;
    return room;
  }

  @override
  Future<SseResponse> openBannerStream(
    int eventId, {
    String? lastEventId,
    Future<void>? abort,
  }) =>
      _transport.open(
        '/events/$eventId/live/stream',
        query: const {'view': 'banner'},
        headers: {if (lastEventId != null) 'Last-Event-ID': lastEventId},
        abort: abort,
      );

  @override
  Future<LiveFeed?> fetchRoom(int eventId) async {
    final response = await _dio.get<dynamic>('/events/$eventId/live');
    return LiveFeed.tryParse(response.data);
  }

  @override
  Future<SseResponse> openRoomStream(
    int eventId, {
    String? lastEventId,
    Future<void>? abort,
  }) =>
      _transport.open(
        '/events/$eventId/live/stream',
        query: const {'view': 'room'},
        headers: {if (lastEventId != null) 'Last-Event-ID': lastEventId},
        abort: abort,
      );
}
