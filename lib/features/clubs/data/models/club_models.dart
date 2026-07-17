import 'package:finnet/features/clubs/domain/entities/club_entity.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';

/// Data model for club from API.
class ClubModel {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic>? logo;
  final String? locationName;
  final String? locationLink;
  final String? about;
  final int? rating;
  final int? totalRating;
  final SocialLinksModel? socials;
  final List<InterestModel>? interests;
  final int? followersCount;
  final String? contactPhone;
  final String? contactEmail;
  final OrganizationModel? org;
  final ClubUserDataModel? userData;

  const ClubModel({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
    this.locationName,
    this.locationLink,
    this.about,
    this.rating,
    this.totalRating,
    this.socials,
    this.interests,
    this.followersCount,
    this.contactPhone,
    this.contactEmail,
    this.org,
    this.userData,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      logo: json['logo'] as Map<String, dynamic>?,
      locationName: json['location_name'] as String?,
      locationLink: json['location_link'] as String?,
      about: json['about'] as String?,
      rating: json['rating'] as int?,
      totalRating: json['total_rating'] as int?,
      socials: json['socials'] != null
          ? SocialLinksModel.fromJson(json['socials'] as Map<String, dynamic>)
          : null,
      interests: (json['interests'] as List<dynamic>?)
          ?.map((e) => InterestModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      followersCount: json['followers_count'] as int?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      org: json['org'] != null
          ? OrganizationModel.fromJson(json['org'] as Map<String, dynamic>)
          : null,
      userData: json['user_data'] != null
          ? ClubUserDataModel.fromJson(
              json['user_data'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'logo': logo,
      'location_name': locationName,
      'location_link': locationLink,
      'about': about,
      'rating': rating,
      'total_rating': totalRating,
      'socials': socials?.toJson(),
      'interests': interests?.map((e) => e.toJson()).toList(),
      'followers_count': followersCount,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'org': org?.toJson(),
      'user_data': userData?.toJson(),
    };
  }

  Club toEntity() {
    return Club(
      id: id,
      name: name,
      slug: slug,
      logo: logo != null ? ImageUrlsModel.fromJson(logo!).toEntity() : null,
      locationName: locationName,
      locationLink: locationLink,
      description: about,
      rating: (rating ?? 0).toDouble(),
      totalRatings: totalRating ?? 0,
      socials: socials?.toEntity(),
      interests: interests?.map((e) => e.toEntity()).toList() ?? [],
      followersCount: followersCount ?? 0,
      contactPhone: contactPhone,
      contactEmail: contactEmail,
      organization: org?.toEntity(),
      userData: userData?.toEntity(),
    );
  }

  ClubListItem toListItem() {
    return ClubListItem(
      id: id,
      name: name,
      slug: slug,
      logo: logo != null ? ImageUrlsModel.fromJson(logo!).toEntity() : null,
      followersCount: followersCount ?? 0,
      interests: interests?.map((e) => e.toEntity()).toList() ?? [],
      isFollowing: userData?.isFollowing ?? false,
      isPinned: userData?.isPinned ?? false,
    );
  }
}

/// Data model for social links.
class SocialLinksModel {
  final String? instagram;
  final String? linkedin;
  final String? youtube;
  final String? twitter;
  final String? facebook;
  final String? website;

  const SocialLinksModel({
    this.instagram,
    this.linkedin,
    this.youtube,
    this.twitter,
    this.facebook,
    this.website,
  });

  factory SocialLinksModel.fromJson(Map<String, dynamic> json) {
    return SocialLinksModel(
      instagram: json['instagram'] as String?,
      linkedin: json['linkedin'] as String?,
      youtube: json['youtube'] as String?,
      twitter: json['twitter'] as String?,
      facebook: json['facebook'] as String?,
      website: json['website'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'instagram': instagram,
      'linkedin': linkedin,
      'youtube': youtube,
      'twitter': twitter,
      'facebook': facebook,
      'website': website,
    };
  }

  SocialLinks toEntity() {
    return SocialLinks(
      instagram: instagram,
      linkedin: linkedin,
      youtube: youtube,
      twitter: twitter,
      facebook: facebook,
      website: website,
    );
  }
}

/// Data model for club user data.
class ClubUserDataModel {
  final bool? isFollowing;
  final bool? isPinned;
  final bool? isMember;

  const ClubUserDataModel({
    this.isFollowing,
    this.isPinned,
    this.isMember,
  });

  factory ClubUserDataModel.fromJson(Map<String, dynamic> json) {
    return ClubUserDataModel(
      isFollowing: json['is_following'] as bool?,
      isPinned: json['is_pinned'] as bool?,
      isMember: json['is_member'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_following': isFollowing,
      'is_pinned': isPinned,
      'is_member': isMember,
    };
  }

  ClubUserData toEntity() {
    return ClubUserData(
      isFollowing: isFollowing ?? false,
      isPinned: isPinned ?? false,
      isMember: isMember ?? false,
    );
  }
}
