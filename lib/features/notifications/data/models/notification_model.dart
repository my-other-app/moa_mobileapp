/// Brief event info included in notifications
class NotificationEventBrief {
  final int id;
  final String name;

  const NotificationEventBrief({
    required this.id,
    required this.name,
  });

  factory NotificationEventBrief.fromJson(Map<String, dynamic> json) {
    return NotificationEventBrief(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}

/// Brief club info included in notifications
class NotificationClubBrief {
  final int id;
  final String name;
  final String? logo;

  const NotificationClubBrief({
    required this.id,
    required this.name,
    this.logo,
  });

  factory NotificationClubBrief.fromJson(Map<String, dynamic> json) {
    String? logoUrl;
    final logoData = json['logo'];

    if (logoData is Map) {
      logoUrl =
          logoData['thumbnail'] ?? logoData['original'] ?? logoData['medium'];
    } else if (logoData is String) {
      logoUrl = logoData;
    }

    return NotificationClubBrief(
      id: json['id'] as int,
      name: json['name'] as String,
      logo: logoUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'logo': logo,
      };
}

/// Notification status enum
enum NotificationStatus {
  read,
  unread,
}

/// Notification type enum matching backend types
enum NotificationType {
  certificateGenerated('certificate_generated'),
  eventStarted('event_started'),
  eventInvited('event_invited'),
  eventCheckin('event_checkin'),
  eventRegistered('event_registered'),
  eventReminder('event_reminder'),
  newEvent('new_event'),
  nearbyEvent('nearby_event'),
  clubAnnouncement('club_announcement'),
  volunteerAdded('volunteer_added'),
  volunteerRemoved('volunteer_removed');

  final String value;
  const NotificationType(this.value);

  static NotificationType? fromValue(String value) {
    try {
      return NotificationType.values.firstWhere((t) => t.value == value);
    } catch (_) {
      return null;
    }
  }
}

/// In-app notification model
class NotificationModel {
  final String id;
  final int userId;
  final String title;
  final String description;
  final String type;
  final String status;
  final NotificationClubBrief? fromClub;
  final NotificationEventBrief? event;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    this.fromClub,
    this.event,
    this.data,
    required this.createdAt,
    required this.updatedAt,
  });

  /// The same notification with a new status.
  ///
  /// The provider used to rebuild all twelve fields by hand at each of the
  /// two call sites that mark something read. Twenty-four chances to drop a
  /// field, and dropping one would silently blank it in the list.
  NotificationModel copyWithStatus(String newStatus) => NotificationModel(
        id: id,
        userId: userId,
        title: title,
        description: description,
        type: type,
        status: newStatus,
        fromClub: fromClub,
        event: event,
        data: data,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as int,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: json['type'] as String,
      status: json['status'] as String,
      fromClub: json['from_club'] != null
          ? NotificationClubBrief.fromJson(
              json['from_club'] as Map<String, dynamic>)
          : null,
      event: json['event'] != null
          ? NotificationEventBrief.fromJson(
              json['event'] as Map<String, dynamic>)
          : null,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'description': description,
        'type': type,
        'status': status,
        'from_club': fromClub?.toJson(),
        'event': event?.toJson(),
        'data': data,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Check if notification is unread
  bool get isUnread => status == 'unread';

  /// Get the notification type as enum
  NotificationType? get notificationType => NotificationType.fromValue(type);

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

  /// Create a copy with updated status
  NotificationModel copyWith({
    String? id,
    int? userId,
    String? title,
    String? description,
    String? type,
    String? status,
    NotificationClubBrief? fromClub,
    NotificationEventBrief? event,
    Map<String, dynamic>? data,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      fromClub: fromClub ?? this.fromClub,
      event: event ?? this.event,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
