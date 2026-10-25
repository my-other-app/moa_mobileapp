import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/features/volunteer/data/datasources/volunteer_remote_datasource.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:finnet/features/volunteer/domain/repositories/volunteer_repository.dart';

/// Provider for the volunteer repository.
final volunteerRepositoryProvider = Provider<VolunteerRepository>((ref) {
  return VolunteerRepositoryImpl(
    remoteDataSource: ref.watch(volunteerRemoteDataSourceProvider),
  );
});

class VolunteerRepositoryImpl implements VolunteerRepository {
  final VolunteerRemoteDataSource remoteDataSource;

  VolunteerRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Result<List<VolunteerEvent>>> myEvents() async {
    try {
      return Either.right(await remoteDataSource.myEvents());
    } catch (e) {
      debugPrint('VolunteerRepository.myEvents error: $e');
      return Either.left(mapErrorToFailure(e));
    }
  }
}
