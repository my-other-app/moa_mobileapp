import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/common/models/events/live_model.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/network/sse/sse_transport.dart';

final liveRemoteDataSourceProvider = Provider<LiveRemoteDataSource>((ref) {
  return LiveRemoteDataSourceImpl(ref.watch(dioProvider));
});

/// The event's live room, as the event page reads it: the `room` view.
///
/// The poll and the stream carry the same body (`Feed`) and are sent with
/// the same credentials: the app's Dio adds the signed-in person's token to
/// both, and neither sends a browser key (`X-Live-Key`) -- the page shows
/// the room's state, not one browser's votes.
abstract class LiveRemoteDataSource {
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
