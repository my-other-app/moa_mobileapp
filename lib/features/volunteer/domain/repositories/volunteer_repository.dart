import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';

/// What the presentation layer may ask of the volunteer feature.
abstract class VolunteerRepository {
  Future<Result<List<VolunteerEvent>>> myEvents();
}
