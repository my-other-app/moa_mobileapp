import 'package:finnet/features/clubs/domain/entities/club_entity.dart';
import 'package:finnet/features/profile/data/models/profile_models.dart';
import 'package:finnet/features/topics/data/models/topic_model.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/shared/utils/image_url.dart';

/// Data model for club from API.

/// A club's logo as the image dict the rest of the app reads.
Map<String, dynamic>? _logoMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  final url = imageUrlFrom(value);
  return url == null ? null : {'thumbnail': url, 'original': url};
}

/// Read a JSON number as an int, whatever shape it arrived in.
///
/// Dart's `as int?` throws on a double, and JSON gives no guarantee which
/// one a number will be: 4 deserialises as int, 4.5 as double. A cast that
/// works on the test fixture fails on the first club somebody rates.
int? _toInt(dynamic value) => (value as num?)?.toInt();

/// The same, for values that are genuinely fractional.
double? _toDouble(dynamic value) => (value as num?)?.toDouble();

class ClubModel {
  final int id;
  final String name;
  final String slug;
  final Map<String, dynamic>? logo;
  final String? locationName;
  final String? locationLink;
  final String? about;
  final double? rating;
  final int? totalRating;
  final SocialLinksModel? socials;
  final List<InterestModel>? interests;

  /// `topics` as sent; null from a server that sends none.
  final List<Topic>? topics;
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
    this.topics,
    this.followersCount,
    this.contactPhone,
    this.contactEmail,
    this.org,
    this.userData,
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: _toInt(json['id']) ?? 0,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      // A dict, null for a club with no logo, or a bare URL on older rows --
      // which a straight `as Map` cast threw on.
      logo: _logoMap(json['logo']),
      locationName: json['location_name'] as String?,
      locationLink: json['location_link'] as String?,
      about: json['about'] as String?,
      // JSON numbers arrive as int or double depending on the value, so a
      // bare `as int?` throws on 4.5 and takes the whole club with it. The
      // server sends `rating` as a float and the key is `total_ratings`, not
      // `total_rating` -- reading the singular silently yielded null.
      rating: _toDouble(json['rating']),
      totalRating: _toInt(json['total_ratings'] ?? json['total_rating']),
      socials: json['socials'] != null
          ? SocialLinksModel.fromJson(json['socials'] as Map<String, dynamic>)
          : null,
      interests: (json['interests'] as List<dynamic>?)
          ?.map((e) => InterestModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      topics: TopicModel.declaredIn(json),
      followersCount: _toInt(json['followers_count']),
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
      'total_ratings': totalRating,
      'socials': socials?.toJson(),
      'interests': interests?.map((e) => e.toJson()).toList(),
      if (topics != null) 'topics': topics!.map(topicRefJson).toList(),
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
      rating: rating ?? 0,
      totalRatings: totalRating ?? 0,
      socials: socials?.toEntity(),
      interests: interests?.map((e) => e.toEntity()).toList() ?? [],
      topics: topics,
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
      topics: topics,
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
