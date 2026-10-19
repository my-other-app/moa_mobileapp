import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/core/error/failure_mapper.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/events/data/datasources/competition_remote_datasource.dart';
import 'package:finnet/features/events/domain/entities/competition.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart'
    show readableError;

final competitionRepositoryProvider = Provider<CompetitionRepository>((ref) {
  return CompetitionRepository(ref.watch(competitionRemoteDataSourceProvider));
});

/// Why the competition can't be shown.
enum CompetitionProblem {
  /// Signed out, or the session ended (401).
  signIn,

  /// Not registered for the event (403 "Register for the event first").
  notRegistered,

  /// The event runs no competition (404).
  none,

  /// Anything else: the network, the server.
  other,
}

/// A failure from a competition call: what to tell the person, and what
/// kind of problem it is.
class CompetitionFailure extends Failure {
  final CompetitionProblem problem;

  const CompetitionFailure({
    required super.message,
    required this.problem,
    super.code,
  });
}

/// [error] from a competition call, in words a person reads. The server's
/// own sentences (409 "Teams are locked; ask the organisers", "You are
/// already on a team", "Join or make a team first") are kept.
@visibleForTesting
CompetitionFailure competitionFailureFrom(Object error) {
  final status = statusCodeOf(error);
  switch (status) {
    case 401:
      return const CompetitionFailure(
        message: 'Sign in to see your team.',
        problem: CompetitionProblem.signIn,
        code: '401',
      );
    case 403:
      return const CompetitionFailure(
        message: 'Register for the event first, then come back here.',
        problem: CompetitionProblem.notRegistered,
        code: '403',
      );
    case 404:
      return const CompetitionFailure(
        message: 'This event has no competition.',
        problem: CompetitionProblem.none,
        code: '404',
      );
  }
  final mapped = mapErrorToFailure(error);
  return CompetitionFailure(
    message: readableError(error, fallback: mapped.message),
    problem: CompetitionProblem.other,
    code: status?.toString(),
  );
}

/// The person's side of an event's competition.
class CompetitionRepository {
  CompetitionRepository(this._source);

  final CompetitionRemoteDataSource _source;

  Future<Result<MyCompetition>> _guard(
      String name, Future<MyCompetition> Function() call) async {
    try {
      return Either.right(await call());
    } catch (e) {
      debugPrint('CompetitionRepository.$name: $e');
      return Either.left(competitionFailureFrom(e));
    }
  }

  /// The event's id for [ref] (a slug or an id).
  Future<Result<int>> resolve(String ref) async {
    final asId = int.tryParse(ref.trim());
    if (asId != null && asId > 0) return Either.right(asId);
    try {
      final id = await _source.eventIdFor(ref);
      if (id != null) return Either.right(id);
      return Either.left(const CompetitionFailure(
        message: "We couldn't find this event.",
        problem: CompetitionProblem.none,
        code: '404',
      ));
    } catch (e) {
      return Either.left(competitionFailureFrom(e));
    }
  }

  Future<Result<MyCompetition>> me(int eventId) =>
      _guard('me', () => _source.me(eventId));

  Future<Result<MyCompetition>> makeTeam(int eventId, String name,
          {int? trackId}) =>
      _guard('makeTeam',
          () => _source.makeTeam(eventId, name.trim(), trackId: trackId));

  Future<Result<MyCompetition>> joinTeam(int eventId, int teamId) =>
      _guard('joinTeam', () => _source.joinTeam(eventId, teamId));

  Future<Result<MyCompetition>> leaveTeam(int eventId) =>
      _guard('leaveTeam', () => _source.leaveTeam(eventId));

  Future<Result<MyCompetition>> setTrack(int eventId, int? trackId) =>
      _guard('setTrack', () => _source.setTrack(eventId, trackId));

  Future<Result<MyCompetition>> seeking(int eventId,
          {required bool on, List<String> skills = const [], String? note}) =>
      _guard('seeking',
          () => _source.seeking(eventId, on: on, skills: skills, note: note));

  Future<Result<MyCompetition>> submit(
          int eventId, Map<String, String> fields) =>
      _guard('submit', () => _source.submit(eventId, fields));

  Future<Result<MyCompetition>> bookSlot(int eventId, int slotId) =>
      _guard('bookSlot', () => _source.bookSlot(eventId, slotId));

  Future<Result<MyCompetition>> freeSlot(int eventId, int slotId) =>
      _guard('freeSlot', () => _source.freeSlot(eventId, slotId));
}
