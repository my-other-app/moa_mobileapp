import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';

/// What the presentation layer may ask of the volunteer feature.
abstract class VolunteerRepository {
  Future<Result<List<VolunteerEvent>>> myEvents();

  /// Check a ticket without admitting anyone.
  ///
  /// Returns a [CheckinResult] rather than a [Result] because a refusal is an
  /// expected answer here, not a failure: "already checked in" is information
  /// the door needs, and the scanner has a screen for each case.
  Future<CheckinResult> validate(int eventId, String ticketId);

  /// Admit the holder.
  Future<CheckinResult> checkin(int eventId, String ticketId);
}
