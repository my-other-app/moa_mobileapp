import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:myotherapp/common/models/clubs/club_model.dart';

part 'notification_model.freezed.dart';
part 'notification_model.g.dart';

/// Brief event info included in notifications
@freezed
class NotificationEventBrief with _$NotificationEventBrief {
  const factory NotificationEventBrief({
    required int id,
    required String name,
  }) = _NotificationEventBrief;

  factory NotificationEventBrief.fromJson(Map<String, dynamic> json) =>
      _$NotificationEventBriefFromJson(json);
}

/// Brief club info included in notifications
@freezed
class NotificationClubBrief with _$NotificationClubBrief {
  const factory NotificationClubBrief({
    required int id,
    required String name,
    String? logo,
  }) = _NotificationClubBrief;

  factory NotificationClubBrief.fromJson(Map<String, dynamic> json) =>
      _$NotificationClubBriefFromJson(json);
}

/// Notification status enum
enum NotificationStatus {
  read,
  unread,
}

/// Notification type enum matching backend types
enum NotificationType {
  @JsonValue('certificate_generated')
  certificateGenerated,
  @JsonValue('event_started')
  eventStarted,
  @JsonValue('event_invited')
  eventInvited,
  @JsonValue('event_checkin')
  eventCheckin,
  @JsonValue('event_registered')
  eventRegistered,
  @JsonValue('event_reminder')
  eventReminder,
  @JsonValue('new_event')
  newEvent,
  @JsonValue('nearby_event')
  nearbyEvent,
  @JsonValue('club_announcement')
  clubAnnouncement,
  @JsonValue('volunteer_added')
  volunteerAdded,
  @JsonValue('volunteer_removed')
  volunteerRemoved,
}

/// In-app notification model
@freezed
class NotificationModel with _$NotificationModel {
  const NotificationModel._();

  const factory NotificationModel({
    required String id,
    @JsonKey(name: 'user_id') required int userId,
    required String title,
    required String description,
    required String type,
    required String status,
    @JsonKey(name: 'from_club') NotificationClubBrief? fromClub,
    NotificationEventBrief? event,
    Map<String, dynamic>? data,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
  }) = _NotificationModel;

  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  /// Check if notification is unread
  bool get isUnread => status == 'unread';

  /// Get the notification type as enum
  NotificationType? get notificationType {
    try {
      return NotificationType.values.firstWhere(
        (t) => t.name == type || _typeToJsonValue(t) == type,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get display icon based on notification type
  String get iconEmoji {
    switch (type) {
      case 'certificate_generated':
        return '🏆';
      case 'event_checkin':
        return '✅';
      case 'new_event':
        return '🎉';
      case 'nearby_event':
        return '📌';
      case 'volunteer_added':
        return '🎖️';
      case 'club_announcement':
        return '📣';
      case 'event_reminder':
        return '⏰';
      default:
        return '🔔';
    }
  }

  /// Get time ago string
  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${(diff.inDays / 7).floor()}w ago';
    }
  }
}

String _typeToJsonValue(NotificationType type) {
  switch (type) {
    case NotificationType.certificateGenerated:
      return 'certificate_generated';
    case NotificationType.eventStarted:
      return 'event_started';
    case NotificationType.eventInvited:
      return 'event_invited';
    case NotificationType.eventCheckin:
      return 'event_checkin';
    case NotificationType.eventRegistered:
      return 'event_registered';
    case NotificationType.eventReminder:
      return 'event_reminder';
    case NotificationType.newEvent:
      return 'new_event';
    case NotificationType.nearbyEvent:
      return 'nearby_event';
    case NotificationType.clubAnnouncement:
      return 'club_announcement';
    case NotificationType.volunteerAdded:
      return 'volunteer_added';
    case NotificationType.volunteerRemoved:
      return 'volunteer_removed';
  }
}
