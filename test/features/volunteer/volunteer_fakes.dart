import 'dart:async';

import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:finnet/features/volunteer/domain/repositories/volunteer_repository.dart';

/// The volunteer endpoints, scripted: the events (or a failure), each
/// scan's answer, and every call made, in order.
class FakeVolunteerRepository implements VolunteerRepository {
  FakeVolunteerRepository({
    this.events = const [],
    this.failure,
    CheckinResult? validation,
    CheckinResult? checkinResult,
  })  : validation = validation ?? validTicket,
        checkinResult = checkinResult ?? admitted;

  List<VolunteerEvent> events;
  Failure? failure;
  CheckinResult validation;
  CheckinResult checkinResult;

  /// Holds [myEvents] until completed, to see the loading state.
  Completer<void>? hold;

  final calls = <String>[];

  @override
  Future<Result<List<VolunteerEvent>>> myEvents() async {
    calls.add('myEvents');
    if (hold != null) await hold!.future;
    final refused = failure;
    if (refused != null) return Either.left(refused);
    return Either.right(events);
  }

  @override
  Future<CheckinResult> validate(int eventId, String ticketId) async {
    calls.add('validate($eventId,$ticketId)');
    return validation;
  }

  @override
  Future<CheckinResult> checkin(int eventId, String ticketId) async {
    calls.add('checkin($eventId,$ticketId)');
    return checkinResult;
  }
}

/// A ticket the server says is good, with its holder.
final validTicket = CheckinResult(
  success: true,
  type: CheckinResultType.success,
  message: 'Valid ticket',
  ticketId: 'MOA-4KD9W-22XQZ',
  ticketHolderName: 'Aarav Menon',
  ticketHolderEmail: 'aarav@example.com',
  eventDate: DateTime(2026, 10, 11, 19, 30),
  eventTime: '19:30',
  location: 'Lab 2, Block C',
);

const admitted = CheckinResult(
  success: true,
  type: CheckinResultType.success,
  message: 'Check-in successful!',
  ticketId: 'MOA-4KD9W-22XQZ',
);

VolunteerEvent volunteerEvent({
  int id = 7,
  String name = 'Hack Night 04',
  String club = 'Makers',
  bool hasFee = true,
  int? maxParticipants = 120,
}) =>
    VolunteerEvent(
      id: id,
      slug: 'hack-night-04',
      name: name,
      clubName: club,
      eventDatetime: DateTime(2026, 10, 11, 19, 30),
      hasFee: hasFee,
      regFee: hasFee ? 250 : 0,
      maxParticipants: maxParticipants,
    );
