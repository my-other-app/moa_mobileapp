import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/core/api/api_helper.dart';

/// Model for volunteer event
class VolunteerEvent {
  final int id;
  final String slug;
  final String name;
  final String? posterUrl;
  final String? clubLogoUrl;
  final String clubName;
  final DateTime eventDatetime;
  final bool hasFee;
  final double regFee;
  final int? maxParticipants;

  const VolunteerEvent({
    required this.id,
    required this.slug,
    required this.name,
    this.posterUrl,
    this.clubLogoUrl,
    required this.clubName,
    required this.eventDatetime,
    required this.hasFee,
    required this.regFee,
    this.maxParticipants,
  });

  factory VolunteerEvent.fromJson(Map<String, dynamic> json) {
    final poster = json['poster'] as Map<String, dynamic>?;
    final club = json['club'] as Map<String, dynamic>?;
    final clubLogo = club?['logo'] as Map<String, dynamic>?;

    return VolunteerEvent(
      id: json['id'] as int,
      slug: json['slug'] as String,
      name: json['name'] as String,
      posterUrl: poster?['large'] as String? ?? poster?['medium'] as String?,
      clubLogoUrl: clubLogo?['thumbnail'] as String?,
      clubName: club?['name'] as String? ?? '',
      eventDatetime: DateTime.parse(json['event_datetime'] as String),
      hasFee: json['has_fee'] as bool? ?? false,
      regFee: (json['reg_fee'] as num?)?.toDouble() ?? 0.0,
      maxParticipants: json['max_participants'] as int?,
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

/// Check-in result type enum matching the UI designs
enum CheckinResultType {
  success, // Valid ticket - show ticket details with grant entry
  notFound, // Ticket not found
  alreadyScanned, // Already checked in
  unpaid, // User hasn't paid
  incorrectEvent, // Ticket belongs to a different event
  // expired,        // Expired ticket (not yet supported by backend)
}

/// Check-in result state with detailed ticket info
class CheckinResult {
  final bool success;
  final CheckinResultType type;
  final String message;
  // Ticket details for success case
  final String? ticketId;
  final String? ticketHolderName;
  final String? ticketHolderEmail;
  final String? ticketType;
  final DateTime? eventDate;
  final String? eventTime;
  final String? location;

  const CheckinResult({
    required this.success,
    required this.type,
    required this.message,
    this.ticketId,
    this.ticketHolderName,
    this.ticketHolderEmail,
    this.ticketType,
    this.eventDate,
    this.eventTime,
    this.location,
  });
}

/// Notifier for volunteer state
class VolunteerNotifier extends StateNotifier<VolunteerState> {
  VolunteerNotifier() : super(const VolunteerState());

  /// Fetch events user is volunteering for
  Future<void> fetchVolunteerEvents() async {
    state = state.copyWith(isLoading: true, error: null);
    debugPrint('🔍 [Volunteer] Fetching volunteer events...');

    try {
      final response = await APIService.instance.request(
        '/events/volunteer/my-events',
        DioMethod.get,
      );

      debugPrint('🔍 [Volunteer] Response status: ${response.statusCode}');
      debugPrint('🔍 [Volunteer] Response data: ${response.data}');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        debugPrint('🔍 [Volunteer] Found ${data.length} volunteer events');
        final events = data
            .map((e) => VolunteerEvent.fromJson(e as Map<String, dynamic>))
            .toList();
        state = state.copyWith(isLoading: false, events: events);
        debugPrint(
            '🔍 [Volunteer] Events loaded successfully: ${events.length}');
      } else {
        debugPrint('🔍 [Volunteer] Non-200 response');
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to fetch volunteer events',
        );
      }
    } catch (e, stack) {
      debugPrint('🔍 [Volunteer] Error: $e');
      debugPrint('🔍 [Volunteer] Stack: $stack');
      state = state.copyWith(
        isLoading: false,
        error: 'Error: ${e.toString()}',
      );
    }
  }

  /// Validate a ticket without marking attendance (for scan preview)
  Future<CheckinResult> validateTicket(int eventId, String ticketId) async {
    try {
      final response = await APIService.instance.request(
        '/events/volunteer/validate/$eventId',
        DioMethod.post,
        param: {'ticket_id': ticketId},
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;

        // Parse event datetime
        DateTime? eventDate;
        String? eventTime;
        if (data['event_datetime'] != null) {
          final dt = DateTime.tryParse(data['event_datetime'] as String);
          if (dt != null) {
            eventDate = dt;
            eventTime =
                '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          }
        }

        return CheckinResult(
          success: true,
          type: CheckinResultType.success,
          message: 'Valid ticket',
          ticketId: ticketId,
          ticketHolderName: data['ticket_holder_name'] as String?,
          ticketHolderEmail: data['ticket_holder_email'] as String?,
          eventDate: eventDate,
          eventTime: eventTime,
          location: data['location'] as String?,
        );
      } else {
        final message =
            response.data['message'] as String? ?? 'Validation failed';
        return CheckinResult(
          success: false,
          type: _getResultTypeFromMessage(message),
          message: message,
        );
      }
    } on ApiException catch (e) {
      String errorMessage = e.message;
      debugPrint('🔍 [Validate] ApiException: $errorMessage');
      return CheckinResult(
        success: false,
        type: _getResultTypeFromMessage(errorMessage),
        message: errorMessage,
      );
    } on DioException catch (e) {
      // Extract error message from response body
      String errorMessage = 'Validation failed';

      if (e.response?.data != null && e.response?.data is Map) {
        final responseData = e.response?.data as Map<String, dynamic>;
        errorMessage = responseData['message'] as String? ?? errorMessage;
      }

      debugPrint('🔍 [Validate] DioException: $errorMessage');
      debugPrint('🔍 [Validate] Response: ${e.response?.data}');

      return CheckinResult(
        success: false,
        type: _getResultTypeFromMessage(errorMessage),
        message: errorMessage,
      );
    } catch (e) {
      debugPrint('🔍 [Validate] Generic error: $e');
      String errorMessage = 'Validation failed';
      final errorString = e.toString();

      if (errorString.contains('Incorrect event') ||
          errorString.contains('belongs to')) {
        return CheckinResult(
          success: false,
          type: CheckinResultType.incorrectEvent,
          message: 'This ticket belongs to a different event',
        );
      } else if (errorString.contains('Registration not found')) {
        return CheckinResult(
          success: false,
          type: CheckinResultType.notFound,
          message: 'Registration not found',
        );
      } else if (errorString.contains('already checked-in')) {
        return CheckinResult(
          success: false,
          type: CheckinResultType.alreadyScanned,
          message: 'User already checked-in',
        );
      } else if (errorString.contains('not paid')) {
        return CheckinResult(
          success: false,
          type: CheckinResultType.unpaid,
          message: 'Payment not verified',
        );
      }

      return CheckinResult(
        success: false,
        type: CheckinResultType.notFound,
        message: errorMessage,
      );
    }
  }

  /// Check-in a participant using ticket ID
  Future<CheckinResult> checkinParticipant(int eventId, String ticketId) async {
    try {
      final response = await APIService.instance.request(
        '/events/volunteer/checkin/$eventId',
        DioMethod.post,
        param: {'ticket_id': ticketId},
      );

      if (response.statusCode == 200) {
        return CheckinResult(
          success: true,
          type: CheckinResultType.success,
          message: 'Check-in successful!',
          ticketId: ticketId,
        );
      } else {
        final message =
            response.data['message'] as String? ?? 'Check-in failed';
        return CheckinResult(
          success: false,
          type: _getResultTypeFromMessage(message),
          message: message,
        );
      }
    } on ApiException catch (e) {
      String errorMessage = e.message;
      debugPrint('🔍 [Checkin] ApiException: $errorMessage');
      return CheckinResult(
        success: false,
        type: _getResultTypeFromMessage(errorMessage),
        message: errorMessage,
      );
    } on DioException catch (e) {
      // Extract error message from response body
      String errorMessage = 'Check-in failed';

      if (e.response?.data != null && e.response?.data is Map) {
        final responseData = e.response?.data as Map<String, dynamic>;
        errorMessage = responseData['message'] as String? ?? errorMessage;
      }

      debugPrint('🔍 [Checkin] DioException: $errorMessage');
      debugPrint('🔍 [Checkin] Response: ${e.response?.data}');

      return CheckinResult(
        success: false,
        type: _getResultTypeFromMessage(errorMessage),
        message: errorMessage,
      );
    } catch (e) {
      debugPrint('🔍 [Checkin] Generic error: $e');
      String errorMessage = 'Check-in failed';
      final errorString = e.toString();

      if (errorString.contains('Registration not found')) {
        return CheckinResult(
          success: false,
          type: CheckinResultType.notFound,
          message: 'Registration not found',
        );
      } else if (errorString.contains('already checked-in')) {
        return CheckinResult(
          success: false,
          type: CheckinResultType.alreadyScanned,
          message: 'User already checked-in',
        );
      } else if (errorString.contains('not paid')) {
        return CheckinResult(
          success: false,
          type: CheckinResultType.unpaid,
          message: 'Payment not verified',
        );
      }

      return CheckinResult(
        success: false,
        type: CheckinResultType.notFound,
        message: errorMessage,
      );
    }
  }

  /// Map error message to result type
  CheckinResultType _getResultTypeFromMessage(String message) {
    final lowerMessage = message.toLowerCase();

    // Check for incorrect event first (most specific)
    if (lowerMessage.contains('incorrect event') ||
        lowerMessage.contains('belongs to')) {
      return CheckinResultType.incorrectEvent;
    } else if (lowerMessage.contains('already') ||
        lowerMessage.contains('checked-in') ||
        lowerMessage.contains('checked in')) {
      return CheckinResultType.alreadyScanned;
    } else if (lowerMessage.contains('paid') ||
        lowerMessage.contains('payment') ||
        lowerMessage.contains('fee')) {
      return CheckinResultType.unpaid;
    } else if (lowerMessage.contains('not found') ||
        lowerMessage.contains('registration')) {
      return CheckinResultType.notFound;
    }

    return CheckinResultType.notFound;
  }

  /// Check if user has any volunteer events
  bool get hasVolunteerEvents => state.events.isNotEmpty;
}

/// Provider for volunteer state
final volunteerProvider =
    StateNotifierProvider<VolunteerNotifier, VolunteerState>((ref) {
  return VolunteerNotifier();
});
