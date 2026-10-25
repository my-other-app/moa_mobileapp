import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';

/// Provider for the volunteer remote data source.
final volunteerRemoteDataSourceProvider =
    Provider<VolunteerRemoteDataSource>((ref) {
  return VolunteerRemoteDataSourceImpl(ref.watch(dioProvider));
});

/// The events a volunteer helps at. Checking guests in is the door
/// console's (`data/gate_api.dart`).
abstract class VolunteerRemoteDataSource {
  /// Events this user is a volunteer for.
  Future<List<VolunteerEvent>> myEvents();
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
}
