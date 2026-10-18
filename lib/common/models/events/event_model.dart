import 'package:finnet/core/utils/hours.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart'
    as entity;
import 'package:finnet/features/topics/data/models/topic_model.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

class EventInfo {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic> poster;
  final DateTime eventDateTime;
  /// Hours, as a decimal (2.5 is two and a half hours).
  final double duration;
  final String locationName;
  final String locationLink;
  final bool hasFee;
  final int regFee;
  final bool hasPrize;
  final int prizeAmount;
  final bool isOnline;
  final DateTime regStartDate;

  /// When registration closes; null when the event has no deadline.
  final DateTime? regEndDate;
  final Club club;
  final Category category;
  final List<Interest> interests;

  /// The event's `topics`; null from a server that does not send them, when
  /// they are worked out from [interests] instead.
  final List<Topic>? topics;
  final List<AdditionalDetail> additionalDetails;
  final double rating;
  final int totalRating;
  final String about;
  final String contactPhone;
  final String contactEmail;
  final String url;

  // Registration/Attendance status fields
  final bool isRegistered;
  final bool isAttended;
  final String? ticketUrl;
  final String? certificateUrl;
  final double? userRating;
  final int? userPosition;
  final String? positionLabel;
  final List<EventDownload> downloads;

  /// Null when the viewer isn't registered; true for a free registration or
  /// a paid one; false while a paid event's registration waits for payment.
  /// Also null from a server older than the field.
  final bool? isPaid;

  /// The viewer's own registration (a UUID), for `POST /payments/orders`
  /// when it isn't paid yet. Null when not registered, or from an older
  /// server.
  final String? registrationId;

  EventInfo({
    required this.id,
    required this.name,
    required this.slug,
    required this.poster,
    required this.eventDateTime,
    required this.duration,
    required this.locationName,
    required this.locationLink,
    required this.hasFee,
    required this.regFee,
    required this.hasPrize,
    required this.prizeAmount,
    required this.isOnline,
    required this.regStartDate,
    this.regEndDate,
    required this.club,
    required this.category,
    required this.interests,
    this.topics,
    required this.additionalDetails,
    required this.rating,
    required this.totalRating,
    required this.about,
    required this.contactPhone,
    required this.contactEmail,
    required this.url,
    this.isRegistered = false,
    this.isAttended = false,
    this.ticketUrl,
    this.certificateUrl,
    this.userRating,
    this.userPosition,
    this.positionLabel,
    this.downloads = const [],
    this.isPaid,
    this.registrationId,
  });

  factory EventInfo.fromJson(Map<String, dynamic> json) {
    return EventInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      poster: json['poster'] ?? {},
      eventDateTime:
          DateTime.tryParse(json['event_datetime'] as String? ?? '') ??
              DateTime.now(),
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
      locationName: json['location_name'] as String? ?? '',
      locationLink: json['location_link'] as String? ?? '',
      hasFee: json['has_fee'] as bool? ?? false,
      regFee: (json['reg_fee'] as num?)?.toInt() ?? 0,
      hasPrize: json['has_prize'] as bool? ?? false,
      prizeAmount: (json['prize_amount'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] as bool? ?? false,
      regStartDate: DateTime.tryParse(json['reg_startdate'] as String? ?? '') ??
          DateTime.now(),
      // Optional on the server. Read as "now" when missing, it closed
      // registration for every event without a deadline.
      regEndDate: DateTime.tryParse(json['reg_enddate'] as String? ?? ''),
      club: Club.fromJson(json['club'] is Map<String, dynamic>
          ? json['club'] as Map<String, dynamic>
          : const <String, dynamic>{}),
      category: Category.fromJson(json['category'] ?? {}),
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => Interest.fromJson(e))
              .toList() ??
          [],
      topics: TopicModel.declaredIn(json),
      additionalDetails: (json['additional_details'] as List<dynamic>?)
              ?.map((e) => AdditionalDetail.fromJson(e))
              .toList() ??
          [],
      // The server sends a float (app/api/events/schemas.py). Reading it
      // as an int silently truncated 4.5 to 4, so half a star went missing
      // before anything got as far as drawing it.
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      totalRating: (json['total_rating'] as num?)?.toInt() ?? 0,
      about: json['about'] as String? ?? '',
      contactPhone: json['contact_phone'] as String? ?? '',
      contactEmail: json['contact_email'] as String? ?? '',
      url: json['url'] as String? ?? '',
      // New registration/attendance fields
      isRegistered: json['is_registered'] as bool? ?? false,
      isAttended: json['is_attended'] as bool? ?? false,
      ticketUrl: json['ticket_url'] as String?,
      certificateUrl: json['certificate_url'] as String?,
      userRating: (json['user_rating'] as num?)?.toDouble(),
      userPosition: (json['user_position'] as num?)?.toInt(),
      positionLabel: json['position_label'] as String?,
      downloads: (json['downloads'] as List<dynamic>?)
              ?.map((e) => EventDownload.fromJson(e))
              .toList() ??
          [],
      isPaid: json['is_paid'] as bool?,
      registrationId: _id(json['registration_id']),
    );
  }

  /// A registration id as text: the server sends a UUID string.
  static String? _id(Object? value) {
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is num) return value.toString();
    return null;
  }

  /// Check if the event has ended
  bool get isEventEnded =>
      eventDateTime.add(hoursToDuration(duration)).isBefore(DateTime.now());

  /// Check if certificate is available
  bool get hasCertificate =>
      certificateUrl != null && certificateUrl!.isNotEmpty;

  /// Check if ticket is available
  bool get hasTicket => ticketUrl != null && ticketUrl!.isNotEmpty;
}

class EventDownload {
  final String name;
  final String url;

  EventDownload({required this.name, required this.url});

  factory EventDownload.fromJson(Map<String, dynamic> json) {
    return EventDownload(
      name: json['name'] as String? ?? '',
      url: json['url'] as String? ?? '',
    );
  }
}

class Club {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic> logo;

  Club({
    required this.id,
    required this.name,
    required this.slug,
    required this.logo,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    final logo = json['logo'];
    return Club(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      // The S3 dict. An older row's bare URL is kept as its thumbnail, and a
      // club that never uploaded a logo (null) has none -- reading either as
      // a map threw and took the event page down.
      logo: logo is Map<String, dynamic>
          ? logo
          : logo is String && logo.trim().isNotEmpty
              ? <String, dynamic>{'thumbnail': logo.trim()}
              : <String, dynamic>{},
    );
  }
}

class Category {
  final int id;
  final String name;
  final String icon;
  final String iconType;

  Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconType,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      iconType: json['icon_type'] ?? '',
    );
  }
}

class Interest {
  final int id;
  final String name;
  final String icon;
  final String iconType;

  /// Its topic; null from a server that does not say.
  final int? categoryId;

  Interest({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconType,
    this.categoryId,
  });

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      iconType: json['icon_type'] as String? ?? '',
      categoryId: (json['category_id'] as num?)?.toInt(),
    );
  }

  entity.Interest toEntity() => entity.Interest(
        id: id,
        name: name,
        icon: icon.isEmpty ? null : icon,
        iconType: iconType.isEmpty ? null : iconType,
        categoryId: categoryId,
      );
}

class AdditionalDetail {
  final String key;
  final String label;
  final String fieldType;
  final bool requiredField;
  final List<String> options;

  AdditionalDetail({
    required this.key,
    required this.label,
    required this.fieldType,
    required this.requiredField,
    required this.options,
  });

  factory AdditionalDetail.fromJson(Map<String, dynamic> json) {
    return AdditionalDetail(
      key: json['key'] ?? '',
      label: json['label'] ?? '',
      fieldType: json['field_type'] ?? '',
      requiredField: json['required'] ?? false,
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
