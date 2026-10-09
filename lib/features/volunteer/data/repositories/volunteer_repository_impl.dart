import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/features/volunteer/data/datasources/volunteer_remote_datasource.dart';
import 'package:finnet/features/volunteer/data/ticket_refusal.dart';
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

  @override
  Future<CheckinResult> validate(int eventId, String ticketId) async {
    try {
      final body = await remoteDataSource.validate(eventId, ticketId);
      return _successFrom(body, ticketId);
    } catch (e) {
      debugPrint('VolunteerRepository.validate error: $e');
      return classifyRefusal(e);
    }
  }

  @override
  Future<CheckinResult> checkin(int eventId, String ticketId) async {
    try {
      await remoteDataSource.checkin(eventId, ticketId);
      return CheckinResult(
        success: true,
        type: CheckinResultType.success,
        message: 'Check-in successful!',
        ticketId: ticketId,
      );
    } catch (e) {
      debugPrint('VolunteerRepository.checkin error: $e');
      return classifyRefusal(e);
    }
  }

  /// Build the success result from the validate body.
  ///
  /// The server's `valid` flag is checked rather than assumed: it answers 200
  /// only on a valid ticket today, but a 200 that says `valid: false` must not
  /// open the door.
  CheckinResult _successFrom(Map<String, dynamic> body, String ticketId) {
    if (body['valid'] == false) {
      return classifyRefusalMessage(
        body['message'] as String? ?? 'Ticket is not valid',
      );
    }

    final rawDatetime = body['event_datetime'] as String?;
    final eventDate =
        rawDatetime == null ? null : DateTime.tryParse(rawDatetime);

    return CheckinResult(
      success: true,
      type: CheckinResultType.success,
      message: 'Valid ticket',
      // The server echoes the normalised ticket id -- it matches case
      // insensitively and trims -- so prefer its spelling over the scanned
      // one.
      ticketId: body['ticket_id'] as String? ?? ticketId,
      ticketHolderName: body['ticket_holder_name'] as String?,
      ticketHolderEmail: body['ticket_holder_email'] as String?,
      eventDate: eventDate,
      eventTime: eventDate == null ? null : _hhmm(eventDate),
      location: body['location'] as String?,
    );
  }

  static String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
