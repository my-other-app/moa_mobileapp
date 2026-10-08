import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';

/// Provider for the volunteer remote data source.
final volunteerRemoteDataSourceProvider =
    Provider<VolunteerRemoteDataSource>((ref) {
  return VolunteerRemoteDataSourceImpl(ref.watch(dioProvider));
});

/// Abstract interface for the three volunteer endpoints.
abstract class VolunteerRemoteDataSource {
  /// Events this user is a volunteer for.
  Future<List<VolunteerEvent>> myEvents();

  /// Check a ticket without admitting anyone.
  ///
  /// Returns the raw body so the repository can build the [CheckinResult];
  /// throws on any refusal, since the server answers every refusal with a
  /// non-2xx.
  Future<Map<String, dynamic>> validate(int eventId, String ticketId);

  /// Admit the holder, marking attendance. Not idempotent: a second call for
  /// the same ticket is refused with "User already checked-in".
  Future<void> checkin(int eventId, String ticketId);
}

class VolunteerRemoteDataSourceImpl implements VolunteerRemoteDataSource {
  final Dio _dio;

  VolunteerRemoteDataSourceImpl(this._dio);

  @override
  Future<List<VolunteerEvent>> myEvents() async {
    final response =
        await _dio.get<List<dynamic>>('/events/volunteer/my-events');
    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(VolunteerEvent.fromJson)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> validate(int eventId, String ticketId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/events/volunteer/validate/$eventId',
      data: {'ticket_id': ticketId},
    );
    return response.data ?? const <String, dynamic>{};
  }

  @override
  Future<void> checkin(int eventId, String ticketId) async {
    await _dio.post<dynamic>(
      '/events/volunteer/checkin/$eventId',
      data: {'ticket_id': ticketId},
    );
  }
}
