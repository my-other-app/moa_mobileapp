import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/volunteer/data/repositories/volunteer_repository_impl.dart';
import 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';
import 'package:finnet/features/volunteer/domain/repositories/volunteer_repository.dart';

export 'package:finnet/features/volunteer/domain/entities/volunteer_event.dart';

/// State for the volunteer events list.
class VolunteerState {
  final bool isLoading;
  final List<VolunteerEvent> events;
  final String? error;

  const VolunteerState({
    this.isLoading = false,
    this.events = const [],
    this.error,
  });

  VolunteerState copyWith({
    bool? isLoading,
    List<VolunteerEvent>? events,
    String? error,
  }) {
    return VolunteerState(
      isLoading: isLoading ?? this.isLoading,
      events: events ?? this.events,
      error: error,
    );
  }
}

/// Holds the events this person volunteers at. Checking guests in is the
/// door console's (`gate_controller.dart`).
class VolunteerNotifier extends StateNotifier<VolunteerState> {
  VolunteerNotifier(this._repository) : super(const VolunteerState());

  final VolunteerRepository _repository;

  /// Fetch the events this user is volunteering for.
  Future<void> fetchVolunteerEvents() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.myEvents();
    // Signed out (the session's providers disposed) while it was asked:
    // a slow network made that a crash.
    if (!mounted) return;

    state = result.fold(
      (failure) => state.copyWith(isLoading: false, error: failure.message),
      (events) => state.copyWith(isLoading: false, events: events),
    );
  }

  bool get hasVolunteerEvents => state.events.isNotEmpty;
}

/// Provider for volunteer state.
final volunteerProvider =
    StateNotifierProvider<VolunteerNotifier, VolunteerState>((ref) {
  return VolunteerNotifier(ref.watch(volunteerRepositoryProvider));
});
