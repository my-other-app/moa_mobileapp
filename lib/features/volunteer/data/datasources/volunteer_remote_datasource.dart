import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/cache/api_cache.dart';
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

  /// One row that can't be read is left out; the rest are the list.
  ///
  /// Saved on the phone (encrypted, as the person's, and kept while the
  /// session lasts): the list is the way to the door scanner, and a venue
  /// with no signal must not hide it once it has been read online. With no
  /// answer, the saved copy is the answer; the server's is always taken
  /// when it comes.
  @override
  Future<List<VolunteerEvent>> myEvents() async {
    final response = await _dio.get<dynamic>('/events/volunteer/my-events',
        options: Options(extra: CachePolicy.personalKept.extra));
    final rows = response.data;
    return (rows is List ? rows : const [])
        .map(VolunteerEvent.fromJson)
        .whereType<VolunteerEvent>()
        .toList();
  }
}
