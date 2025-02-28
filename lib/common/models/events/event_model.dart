class EventInfo {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic> poster;
  final DateTime eventDateTime;
  final int duration;
  final String locationName;
  final String locationLink;
  final bool hasFee;
  final int regFee;
  final bool hasPrize;
  final int prizeAmount;
  final bool isOnline;
  final DateTime regStartDate;
  final DateTime regEndDate;
  final Club club;
  final Category category;
  final List<Interest> interests;
  final List<AdditionalDetail> additionalDetails;
  final int rating;
  final int totalRating;
  final String about;
  final String contactPhone;
  final String contactEmail;
  final String url;

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
    required this.regEndDate,
    required this.club,
    required this.category,
    required this.interests,
    required this.additionalDetails,
    required this.rating,
    required this.totalRating,
    required this.about,
    required this.contactPhone,
    required this.contactEmail,
    required this.url,
  });

  factory EventInfo.fromJson(Map<String, dynamic> json) {
    return EventInfo(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      poster: json['poster'] ?? {},
      eventDateTime: DateTime.parse(json['event_datetime']),
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      locationName: json['location_name'] ?? '',
      locationLink: json['location_link'] ?? '',
      hasFee: json['has_fee'] ?? false,
      regFee: (json['reg_fee'] as num?)?.toInt() ?? 0,
      hasPrize: json['has_prize'] ?? false,
      prizeAmount: (json['prize_amount'] as num?)?.toInt() ?? 0,
      isOnline: json['is_online'] ?? false,
      regStartDate: DateTime.parse(json['reg_startdate']),
      regEndDate: DateTime.parse(json['reg_enddate']),
      club: Club.fromJson(json['club']),
      category: Category.fromJson(json['category']),
      interests: (json['interests'] as List<dynamic>?)
              ?.map((e) => Interest.fromJson(e))
              .toList() ??
          [],
      additionalDetails: (json['additional_details'] as List<dynamic>?)
              ?.map((e) => AdditionalDetail.fromJson(e))
              .toList() ??
          [],
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      totalRating: (json['total_rating'] as num?)?.toInt() ?? 0,
      about: json['about'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      contactEmail: json['contact_email'] ?? '',
      url: json['url'] ?? '',
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
    return Club(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      logo: json['logo'] ?? {},
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

  Interest({
    required this.id,
    required this.name,
    required this.icon,
    required this.iconType,
  });

  factory Interest.fromJson(Map<String, dynamic> json) {
    return Interest(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      iconType: json['icon_type'] ?? '',
    );
  }
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
