import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/either.dart';
import 'package:finnet/features/events/data/repositories/competition_repository.dart';
import 'package:finnet/features/events/domain/entities/competition.dart';

/// The "Your team" screen's state.
class CompetitionState {
  final MyCompetition? data;
  final bool loading;

  /// A change is on its way to the server.
  final bool busy;

  /// Why nothing can be shown (set only while [data] is null).
  final CompetitionFailure? failure;

  /// The last change's refusal, to say once ("Teams are locked…").
  final String? notice;

  const CompetitionState({
    this.data,
    this.loading = true,
    this.busy = false,
    this.failure,
    this.notice,
  });

  CompetitionState copyWith({
    MyCompetition? data,
    bool? loading,
    bool? busy,
    CompetitionFailure? failure,
    bool clearFailure = false,
    String? notice,
    bool clearNotice = false,
  }) =>
      CompetitionState(
        data: data ?? this.data,
        loading: loading ?? this.loading,
        busy: busy ?? this.busy,
        failure: clearFailure ? null : (failure ?? this.failure),
        notice: clearNotice ? null : (notice ?? this.notice),
      );
}

/// The person's side of the competition of the event at [ref] (a slug or
/// an id), kept for as long as the screen is open.
final competitionProvider = StateNotifierProvider.autoDispose
    .family<CompetitionNotifier, CompetitionState, String>((ref, eventRef) {
  return CompetitionNotifier(ref.watch(competitionRepositoryProvider), eventRef)
    ..load();
});

class CompetitionNotifier extends StateNotifier<CompetitionState> {
  CompetitionNotifier(this._repository, this._ref)
      : super(const CompetitionState());

  final CompetitionRepository _repository;
  final String _ref;
  int? _eventId;

  /// The state from the server: at first, on a pull, and every so often
  /// while the screen is open (teams fill up, slots get booked). A failed
  /// refresh keeps what is on screen.
  Future<void> load({bool quietly = false}) async {
    if (!quietly) {
      state = state.copyWith(loading: true, clearFailure: true);
    }
    var id = _eventId;
    if (id == null) {
      final resolved = await _repository.resolve(_ref);
      if (!mounted) return;
      if (resolved.isLeft) {
        state = state.copyWith(
            loading: false, failure: resolved.left as CompetitionFailure);
        return;
      }
      id = _eventId = resolved.right;
    }
    final result = await _repository.me(id);
    if (!mounted) return;
    result.fold(
      (failure) {
        // Already on screen: keep it, and say nothing on a quiet refresh.
        if (state.data != null) {
          state = state.copyWith(loading: false);
          return;
        }
        state = state.copyWith(
            loading: false, failure: failure as CompetitionFailure);
      },
      (data) => state =
          state.copyWith(data: data, loading: false, clearFailure: true),
    );
  }

  Future<bool> _change(
      Future<Result<MyCompetition>> Function(int eventId) call) async {
    final id = _eventId;
    if (id == null || state.busy) return false;
    state = state.copyWith(busy: true, clearNotice: true);
    final result = await call(id);
    if (!mounted) return false;
    return result.fold(
      (failure) {
        state = state.copyWith(busy: false, notice: failure.message);
        return false;
      },
      (data) {
        state = state.copyWith(busy: false, data: data);
        return true;
      },
    );
  }

  /// The notice has been shown.
  void noticeShown() => state = state.copyWith(clearNotice: true);

  Future<bool> makeTeam(String name, {int? trackId}) =>
      _change((id) => _repository.makeTeam(id, name, trackId: trackId));

  Future<bool> joinTeam(int teamId) =>
      _change((id) => _repository.joinTeam(id, teamId));

  Future<bool> leaveTeam() => _change(_repository.leaveTeam);

  Future<bool> setTrack(int? trackId) =>
      _change((id) => _repository.setTrack(id, trackId));

  Future<bool> seeking({required bool on, List<String> skills = const []}) =>
      _change((id) => _repository.seeking(id, on: on, skills: skills));

  Future<bool> submit(Map<String, String> fields) =>
      _change((id) => _repository.submit(id, fields));

  /// Book [slot] for the team, or free it when it is the team's already.
  Future<bool> toggleSlot(MentorSlot slot, {required bool ours}) =>
      _change((id) => ours
          ? _repository.freeSlot(id, slot.id)
          : _repository.bookSlot(id, slot.id));
}

/// "ML, PCB , pitching" -> ["ML", "PCB", "pitching"]: at most eight, as the
/// server keeps.
List<String> skillsFrom(String text) => text
    .split(',')
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .take(8)
    .toList();
