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

/// Holds the volunteer events list and forwards scans to the repository.
///
/// All three endpoints moved to [VolunteerRepository]; what is left here is
/// state. The error classification that used to live in this file -- three
/// partial copies of the same substring matching, spread across two methods
/// -- is now in one tested place, `data/ticket_refusal.dart`.
class VolunteerNotifier extends StateNotifier<VolunteerState> {
  VolunteerNotifier(this._repository) : super(const VolunteerState());

  final VolunteerRepository _repository;

  /// Fetch the events this user is volunteering for.
  Future<void> fetchVolunteerEvents() async {
    state = state.copyWith(isLoading: true, error: null);

    final result = await _repository.myEvents();

    state = result.fold(
      (failure) => state.copyWith(isLoading: false, error: failure.message),
      (events) => state.copyWith(isLoading: false, events: events),
    );
  }

  /// Check a ticket without admitting anyone.
  Future<CheckinResult> validateTicket(int eventId, String ticketId) {
    return _repository.validate(eventId, ticketId);
  }

  /// Admit the holder of a ticket.
  Future<CheckinResult> checkinParticipant(int eventId, String ticketId) {
    return _repository.checkin(eventId, ticketId);
  }

  bool get hasVolunteerEvents => state.events.isNotEmpty;
}

/// Provider for volunteer state.
final volunteerProvider =
    StateNotifierProvider<VolunteerNotifier, VolunteerState>((ref) {
  return VolunteerNotifier(ref.watch(volunteerRepositoryProvider));
});
