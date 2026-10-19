import 'package:finnet/core/utils/hours.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart'
    as entity;
import 'package:finnet/features/topics/data/models/topic_model.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/core/utils/json_read.dart';

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
      id: jsonInt(json['id']) ?? 0,
      name: jsonString(json['name']) ?? '',
      slug: jsonString(json['slug']) ?? '',
      // The S3 dict; an older row's bare URL is kept as its original.
      poster: jsonObject(json['poster']) ??
          (jsonString(json['poster'])?.trim().isNotEmpty ?? false
              ? <String, dynamic>{'original': jsonString(json['poster'])!.trim()}
              : <String, dynamic>{}),
      eventDateTime:
          DateTime.tryParse(jsonString(json['event_datetime']) ?? '') ??
              DateTime.now(),
      duration: jsonDouble(json['duration']) ?? 0,
      locationName: jsonString(json['location_name']) ?? '',
      locationLink: jsonString(json['location_link']) ?? '',
      hasFee: jsonBool(json['has_fee']) ?? false,
      regFee: jsonInt(json['reg_fee']) ?? 0,
      hasPrize: jsonBool(json['has_prize']) ?? false,
      prizeAmount: jsonInt(json['prize_amount']) ?? 0,
      isOnline: jsonBool(json['is_online']) ?? false,
      regStartDate: DateTime.tryParse(jsonString(json['reg_startdate']) ?? '') ??
          DateTime.now(),
      // Optional on the server. Read as "now" when missing, it closed
      // registration for every event without a deadline.
      regEndDate: DateTime.tryParse(jsonString(json['reg_enddate']) ?? ''),
      club: Club.fromJson(jsonObject(json['club']) ?? const <String, dynamic>{}),
      category:
          Category.fromJson(jsonObject(json['category']) ?? const <String, dynamic>{}),
      interests: jsonObjects(json['interests']).map(Interest.fromJson).toList(),
      topics: TopicModel.declaredIn(json),
      additionalDetails: jsonObjects(json['additional_details'])
          .map(AdditionalDetail.fromJson)
          .toList(),
      // The server sends a float (app/api/events/schemas.py). Reading it
      // as an int silently truncated 4.5 to 4, so half a star went missing
      // before anything got as far as drawing it.
      rating: jsonDouble(json['rating']) ?? 0,
      totalRating: jsonInt(json['total_rating']) ?? 0,
      about: jsonString(json['about']) ?? '',
      contactPhone: jsonString(json['contact_phone']) ?? '',
      contactEmail: jsonString(json['contact_email']) ?? '',
      url: jsonString(json['url']) ?? '',
      // New registration/attendance fields
      isRegistered: jsonBool(json['is_registered']) ?? false,
      isAttended: jsonBool(json['is_attended']) ?? false,
      ticketUrl: jsonString(json['ticket_url']),
      certificateUrl: jsonString(json['certificate_url']),
      userRating: jsonDouble(json['user_rating']),
      userPosition: jsonInt(json['user_position']),
      positionLabel: jsonString(json['position_label']),
      downloads:
          jsonObjects(json['downloads']).map(EventDownload.fromJson).toList(),
      isPaid: jsonBool(json['is_paid']),
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
      name: jsonString(json['name']) ?? '',
      url: jsonString(json['url']) ?? '',
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
      id: jsonInt(json['id']) ?? 0,
      name: jsonText(json['name']),
      slug: jsonText(json['slug']),
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
      id: jsonInt(json['id']) ?? 0,
      name: jsonText(json['name']),
      icon: jsonText(json['icon']),
      iconType: jsonText(json['icon_type']),
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
      id: jsonInt(json['id']) ?? 0,
      name: jsonString(json['name']) ?? '',
      icon: jsonString(json['icon']) ?? '',
      iconType: jsonString(json['icon_type']) ?? '',
      categoryId: jsonInt(json['category_id']),
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
      key: jsonText(json['key']),
      label: jsonText(json['label']),
      fieldType: jsonText(json['field_type']),
      requiredField: jsonBool(json['required']) ?? false,
      options: json['options'] is List
          ? [for (final option in json['options'] as List) '$option']
          : const <String>[],
    );
  }
}
