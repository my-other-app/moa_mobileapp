import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/api/api_helper.dart';

/// Model for volunteer event data
class VolunteerEvent {
  final int id;
  final String slug;
  final String name;
  final String? posterUrl;
  final DateTime eventDatetime;
  final bool hasFee;
  final double? regFee;
  final int? maxParticipants;
  final String clubName;
  final String clubSlug;
  final String? clubLogoUrl;

  VolunteerEvent({
    required this.id,
    required this.slug,
    required this.name,
    this.posterUrl,
    required this.eventDatetime,
    required this.hasFee,
    this.regFee,
    this.maxParticipants,
    required this.clubName,
    required this.clubSlug,
    this.clubLogoUrl,
  });

  factory VolunteerEvent.fromJson(Map<String, dynamic> json) {
    final club = json['club'] as Map<String, dynamic>? ?? {};
    final poster = json['poster'] as Map<String, dynamic>?;
    final clubLogo = club['logo'] as Map<String, dynamic>?;

    return VolunteerEvent(
      id: json['id'] as int,
      slug: json['slug'] as String,
      name: json['name'] as String,
      posterUrl: poster?['url'] as String?,
      eventDatetime: DateTime.parse(json['event_datetime'] as String),
      hasFee: json['has_fee'] as bool? ?? false,
      regFee: (json['reg_fee'] as num?)?.toDouble(),
      maxParticipants: json['max_participants'] as int?,
      clubName: club['name'] as String? ?? '',
      clubSlug: club['slug'] as String? ?? '',
      clubLogoUrl: clubLogo?['url'] as String?,
    );
  }
}

/// State for volunteer events
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

/// Check-in result state
class CheckinResult {
  final bool success;
  final String message;

  const CheckinResult({required this.success, required this.message});
}

/// Notifier for volunteer state
class VolunteerNotifier extends StateNotifier<VolunteerState> {
  VolunteerNotifier() : super(const VolunteerState());

  /// Fetch events user is volunteering for
  Future<void> fetchVolunteerEvents() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final response = await APIService.instance.request(
        '/api/v1/events/volunteer/my-events',
        DioMethod.get,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        final events = data
            .map((e) => VolunteerEvent.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(isLoading: false, events: events);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to fetch volunteer events',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error: ${e.toString()}',
      );
    }
  }

  /// Check-in a participant using ticket ID
  Future<CheckinResult> checkinParticipant(int eventId, String ticketId) async {
    try {
      final response = await APIService.instance.request(
        '/api/v1/events/volunteer/checkin/$eventId',
        DioMethod.post,
        param: {'ticket_id': ticketId},
      );

      if (response.statusCode == 200) {
        return const CheckinResult(
          success: true,
          message: 'Check-in successful!',
        );
      } else {
        final message = response.data['detail'] as String? ?? 'Check-in failed';
        return CheckinResult(success: false, message: message);
      }
    } on ApiException catch (e) {
      return CheckinResult(success: false, message: e.userMessage);
    } catch (e) {
      return CheckinResult(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }

  /// Check if user has any volunteer events
  bool get hasVolunteerEvents => state.events.isNotEmpty;
}

/// Provider for volunteer state
final volunteerProvider =
    StateNotifierProvider<VolunteerNotifier, VolunteerState>((ref) {
  return VolunteerNotifier();
});

/// Provider to check if user has volunteer events (for settings visibility)
final hasVolunteerEventsProvider = FutureProvider<bool>((ref) async {
  final notifier = ref.read(volunteerProvider.notifier);
  await notifier.fetchVolunteerEvents();
  return notifier.hasVolunteerEvents;
});
