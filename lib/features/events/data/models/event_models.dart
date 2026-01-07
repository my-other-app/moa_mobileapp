import 'package:myotherapp/features/events/domain/entities/event_entity.dart';
import 'package:myotherapp/features/profile/data/models/profile_models.dart';

/// Data model for event from API.
class EventModel {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic>? poster;
  final String? eventDatetime;
  final int? duration;
  final String? locationName;
  final String? locationLink;
  final bool? hasFee;
  final int? regFee;
  final bool? hasPrize;
  final int? prizeAmount;
  final bool? isOnline;
  final String? regStartdate;
  final String? regEnddate;
  final ClubSummaryModel? club;
  final CategoryModel? category;
  final List<InterestModel>? interests;
  final List<EventFieldModel>? additionalDetails;
  final int? rating;
  final int? totalRating;
  final String? about;
  final String? contactPhone;
  final String? contactEmail;
  final String? url;

  const EventModel({
    required this.id,
    required this.name,
    required this.slug,
    this.poster,
    this.eventDatetime,
    this.duration,
    this.locationName,
    this.locationLink,
    this.hasFee,
    this.regFee,
    this.hasPrize,
    this.prizeAmount,
    this.isOnline,
    this.regStartdate,
    this.regEnddate,
    this.club,
    this.category,
    this.interests,
    this.additionalDetails,
    this.rating,
    this.totalRating,
    this.about,
    this.contactPhone,
    this.contactEmail,
    this.url,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      poster: json['poster'] as Map<String, dynamic>?,
      eventDatetime: json['event_datetime'] as String?,
      duration: json['duration'] as int?,
      locationName: json['location_name'] as String?,
      locationLink: json['location_link'] as String?,
      hasFee: json['has_fee'] as bool?,
      regFee: json['reg_fee'] as int?,
      hasPrize: json['has_prize'] as bool?,
      prizeAmount: json['prize_amount'] as int?,
      isOnline: json['is_online'] as bool?,
      regStartdate: json['reg_startdate'] as String?,
      regEnddate: json['reg_enddate'] as String?,
      club: json['club'] != null
          ? ClubSummaryModel.fromJson(json['club'] as Map<String, dynamic>)
          : null,
      category: json['category'] != null
          ? CategoryModel.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      interests: (json['interests'] as List<dynamic>?)
          ?.map((e) => InterestModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      additionalDetails: (json['additional_details'] as List<dynamic>?)
          ?.map((e) => EventFieldModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      rating: json['rating'] as int?,
      totalRating: json['total_rating'] as int?,
      about: json['about'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      url: json['url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'poster': poster,
      'event_datetime': eventDatetime,
      'duration': duration,
      'location_name': locationName,
      'location_link': locationLink,
      'has_fee': hasFee,
      'reg_fee': regFee,
      'has_prize': hasPrize,
      'prize_amount': prizeAmount,
      'is_online': isOnline,
      'reg_startdate': regStartdate,
      'reg_enddate': regEnddate,
      'club': club?.toJson(),
      'category': category?.toJson(),
      'interests': interests?.map((e) => e.toJson()).toList(),
      'additional_details': additionalDetails?.map((e) => e.toJson()).toList(),
      'rating': rating,
      'total_rating': totalRating,
      'about': about,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'url': url,
    };
  }

  Event toEntity() {
    return Event(
      id: id,
      name: name,
      slug: slug,
      poster:
          poster != null ? ImageUrlsModel.fromJson(poster!).toEntity() : null,
      eventDateTime: DateTime.tryParse(eventDatetime ?? '') ?? DateTime.now(),
      durationHours: duration ?? 0,
      locationName: locationName ?? '',
      locationLink: locationLink,
      hasFee: hasFee ?? false,
      registrationFee: regFee ?? 0,
      hasPrize: hasPrize ?? false,
      prizeAmount: prizeAmount ?? 0,
      isOnline: isOnline ?? false,
      registrationStartDate: DateTime.tryParse(regStartdate ?? ''),
      registrationEndDate: DateTime.tryParse(regEnddate ?? ''),
      club: club?.toEntity() ?? const ClubSummary(id: 0, name: '', slug: ''),
      category: category?.toEntity() ?? const Category(id: 0, name: ''),
      interests: interests?.map((e) => e.toEntity()).toList() ?? [],
      additionalFields:
          additionalDetails?.map((e) => e.toEntity()).toList() ?? [],
      rating: (rating ?? 0).toDouble(),
      totalRatings: totalRating ?? 0,
      description: about,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      externalUrl: url,
    );
  }

  EventListItem toListItem() {
    return EventListItem(
      id: id,
      name: name,
      slug: slug,
      poster:
          poster != null ? ImageUrlsModel.fromJson(poster!).toEntity() : null,
      eventDateTime: DateTime.tryParse(eventDatetime ?? '') ?? DateTime.now(),
      locationName: locationName ?? '',
      isOnline: isOnline ?? false,
      hasFee: hasFee ?? false,
      registrationFee: regFee ?? 0,
      club: club?.toEntity() ?? const ClubSummary(id: 0, name: '', slug: ''),
      category: category?.toEntity() ?? const Category(id: 0, name: ''),
    );
  }
}

/// Data model for club summary in events.
class ClubSummaryModel {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic>? logo;

  const ClubSummaryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
  });

  factory ClubSummaryModel.fromJson(Map<String, dynamic> json) {
    return ClubSummaryModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      logo: json['logo'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'logo': logo,
    };
  }

  ClubSummary toEntity() {
    return ClubSummary(
      id: id,
      name: name,
      slug: slug,
      logo: logo != null ? ImageUrlsModel.fromJson(logo!).toEntity() : null,
    );
  }
}

/// Data model for event category.
class CategoryModel {
  final int id;
  final String name;
  final String? icon;
  final String? iconType;

  const CategoryModel({
    required this.id,
    required this.name,
    this.icon,
    this.iconType,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String?,
      iconType: json['icon_type'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'icon_type': iconType,
    };
  }

  Category toEntity() {
    return Category(
      id: id,
      name: name,
      icon: icon,
      iconType: iconType,
    );
  }
}

/// Data model for event additional field.
class EventFieldModel {
  final String key;
  final String label;
  final String fieldType;
  final bool required;
  final List<String>? options;

  const EventFieldModel({
    required this.key,
    required this.label,
    required this.fieldType,
    required this.required,
    this.options,
  });

  factory EventFieldModel.fromJson(Map<String, dynamic> json) {
    return EventFieldModel(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      fieldType: json['field_type'] as String? ?? 'text',
      required: json['required'] as bool? ?? false,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'label': label,
      'field_type': fieldType,
      'required': required,
      'options': options,
    };
  }

  EventField toEntity() {
    return EventField(
      key: key,
      label: label,
      fieldType: _parseFieldType(fieldType),
      isRequired: required,
      options: options ?? [],
    );
  }

  FieldType _parseFieldType(String type) {
    switch (type.toLowerCase()) {
      case 'text':
        return FieldType.text;
      case 'number':
        return FieldType.number;
      case 'email':
        return FieldType.email;
      case 'phone':
        return FieldType.phone;
      case 'dropdown':
      case 'select':
        return FieldType.dropdown;
      case 'radio':
        return FieldType.radio;
      case 'checkbox':
        return FieldType.checkbox;
      case 'date':
        return FieldType.date;
      case 'textarea':
        return FieldType.textarea;
      default:
        return FieldType.text;
    }
  }
}
