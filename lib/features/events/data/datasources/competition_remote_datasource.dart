import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/network/dio_client.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/events/data/models/competition_model.dart';
import 'package:finnet/features/events/domain/entities/competition.dart';

final competitionRemoteDataSourceProvider =
    Provider<CompetitionRemoteDataSource>((ref) {
  return CompetitionRemoteDataSourceImpl(ref.watch(dioProvider));
});

/// A registered guest's competition calls, as the website makes them
/// (moa_backend `app/api/competitions/router.py`, `/events/{id}/competition/me*`).
/// Every one answers the whole `MyState`, so the screen shows what the
/// server now has after each.
abstract class CompetitionRemoteDataSource {
  Future<MyCompetition> me(int eventId);
  Future<MyCompetition> makeTeam(int eventId, String name, {int? trackId});
  Future<MyCompetition> joinTeam(int eventId, int teamId);
  Future<MyCompetition> leaveTeam(int eventId);

  /// Rename the team, or put it on a track ([trackId] null: no track).
  Future<MyCompetition> setTrack(int eventId, int? trackId);
  Future<MyCompetition> seeking(int eventId,
      {required bool on, List<String> skills, String? note});
  Future<MyCompetition> submit(int eventId, Map<String, String> fields);
  Future<MyCompetition> bookSlot(int eventId, int slotId);
  Future<MyCompetition> freeSlot(int eventId, int slotId);

  /// The event's id for [ref], a slug: `/events/info/{ref}`'s `id`.
  Future<int?> eventIdFor(String ref);
}

class CompetitionRemoteDataSourceImpl implements CompetitionRemoteDataSource {
  CompetitionRemoteDataSourceImpl(this._dio);

  final Dio _dio;

  static String _base(int eventId) => '/events/$eventId/competition/me';

  MyCompetition _read(Response<dynamic> response) {
    final state = myCompetitionFromJson(response.data);
    if (state == null) {
      throw const FormatException("The competition didn't come back.");
    }
    return state;
  }

  @override
  Future<MyCompetition> me(int eventId) async =>
      _read(await _dio.get<dynamic>(_base(eventId)));

  @override
  Future<MyCompetition> makeTeam(int eventId, String name,
          {int? trackId}) async =>
      _read(await _dio.post<dynamic>('${_base(eventId)}/team',
          data: {'name': name, 'track_id': trackId}));

  @override
  Future<MyCompetition> joinTeam(int eventId, int teamId) async =>
      _read(await _dio.post<dynamic>('${_base(eventId)}/team/join/$teamId'));

  @override
  Future<MyCompetition> leaveTeam(int eventId) async =>
      _read(await _dio.post<dynamic>('${_base(eventId)}/team/leave'));

  @override
  Future<MyCompetition> setTrack(int eventId, int? trackId) async =>
      _read(await _dio.patch<dynamic>('${_base(eventId)}/team',
          data: {'track_id': trackId}));

  @override
  Future<MyCompetition> seeking(int eventId,
          {required bool on,
          List<String> skills = const [],
          String? note}) async =>
      _read(await _dio.put<dynamic>('${_base(eventId)}/seeking', data: {
        'on': on,
        'skills': skills,
        'note': (note?.trim().isEmpty ?? true) ? null : note!.trim(),
      }));

  @override
  Future<MyCompetition> submit(int eventId, Map<String, String> fields) async =>
      _read(await _dio.put<dynamic>('${_base(eventId)}/submission',
          data: {'fields': fields}));

  @override
  Future<MyCompetition> bookSlot(int eventId, int slotId) async =>
      _read(await _dio.post<dynamic>('${_base(eventId)}/slots/$slotId'));

  @override
  Future<MyCompetition> freeSlot(int eventId, int slotId) async =>
      _read(await _dio.delete<dynamic>('${_base(eventId)}/slots/$slotId'));

  @override
  Future<int?> eventIdFor(String ref) async {
    final response = await _dio
        .get<dynamic>('/events/info/${Uri.encodeComponent(ref.trim())}');
    final id = jsonInt(jsonObject(response.data)?['id']);
    return id != null && id > 0 ? id : null;
  }
}
