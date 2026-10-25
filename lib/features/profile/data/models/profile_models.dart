import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/core/utils/json_read.dart';

/// Data model for user profile from API.
class UserProfileModel {
  final int id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? username;
  final String? userType;
  final ProfileDetailsModel? profile;
  final List<InterestModel>? interests;

  /// Null when the response did not carry it.
  final bool? emailVerified;

  /// "Show me in People Like You"; null from a server without the switch.
  final bool? networkingVisible;

  /// How the account signs in: `email` (a password), `google` or `apple`.
  final String? provider;

  const UserProfileModel({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.username,
    this.userType,
    this.profile,
    this.interests,
    this.emailVerified,
    this.networkingVisible,
    this.provider,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: jsonInt(json['id']) ?? 0,
      fullName: jsonString(json['full_name']),
      email: jsonString(json['email']),
      phone: jsonString(json['phone']),
      username: jsonString(json['username']),
      userType: jsonString(json['user_type']),
      profile: jsonObject(json['profile']) == null
          ? null
          : ProfileDetailsModel.fromJson(jsonObject(json['profile'])!),
      interests: json['interests'] is List
          ? jsonObjects(json['interests']).map(InterestModel.fromJson).toList()
          : null,
      emailVerified: jsonBool(json['email_verified']),
      networkingVisible: jsonBool(json['networking_visible']),
      provider: jsonString(json['provider']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'username': username,
      'user_type': userType,
      'profile': profile?.toJson(),
      'interests': interests?.map((e) => e.toJson()).toList(),
      if (emailVerified != null) 'email_verified': emailVerified,
      if (networkingVisible != null) 'networking_visible': networkingVisible,
      if (provider != null) 'provider': provider,
    };
  }

  /// Convert to domain entity.
  UserProfile toEntity() {
    return UserProfile(
      id: id.toString(),
      fullName: fullName ?? profile?.fullName ?? '',
      email: email ?? '',
      phone: phone,
      whatsapp: profile?.whatsapp,
      organization: profile?.org?.toEntity(),
      avatar: profile?.avatar?.toEntity(),
      photo: profile?.photo,
      interests: interests?.map((e) => e.toEntity()).toList() ?? [],
      isProfileComplete: _isProfileComplete(),
      createdAt: null,
      emailVerified: emailVerified,
      networkingVisible: networkingVisible,
      provider: provider,
    );
  }

  bool _isProfileComplete() {
    return fullName != null &&
        fullName!.isNotEmpty &&
        profile?.org != null &&
        (profile?.avatar != null || profile?.photo != null);
  }
}

/// Data model for profile details.
class ProfileDetailsModel {
  final String? fullName;
  final String? whatsapp;
  final OrganizationModel? org;
  final AvatarModel? avatar;
  final Map<String, dynamic>? profilePic;

  const ProfileDetailsModel({
    this.fullName,
    this.whatsapp,
    this.org,
    this.avatar,
    this.profilePic,
  });

  factory ProfileDetailsModel.fromJson(Map<String, dynamic> json) {
    return ProfileDetailsModel(
      fullName: jsonString(json['full_name']),
      whatsapp: jsonString(json['whatsapp']),
      org: jsonObject(json['org']) == null
          ? null
          : OrganizationModel.fromJson(jsonObject(json['org'])!),
      avatar: jsonObject(json['avatar']) == null
          ? null
          : AvatarModel.fromJson(jsonObject(json['avatar'])!),
      profilePic: jsonObject(json['profile_pic']),
    );
  }

  /// The uploaded photo as sizes, or null when there is none (or none of
  /// its sizes is an address).
  ImageUrls? get photo {
    final pic = profilePic;
    if (pic == null) return null;
    final urls = ImageUrlsModel.fromJson(pic).toEntity();
    return urls.urlFor() == null ? null : urls;
  }

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'whatsapp': whatsapp,
      'org': org?.toJson(),
      'avatar': avatar?.toJson(),
      'profile_pic': profilePic,
    };
  }
}

/// Data model for organization.
class OrganizationModel {
  final int? id;
  final String? name;
  final String? type;
  final ImageUrlsModel? logo;
  final String? address;
  final String? phone;
  final String? email;

  const OrganizationModel({
    this.id,
    this.name,
    this.type,
    this.logo,
    this.address,
    this.phone,
    this.email,
  });

  factory OrganizationModel.fromJson(Map<String, dynamic> json) {
    return OrganizationModel(
      id: jsonInt(json['id']),
      name: jsonString(json['name']),
      type: jsonString(json['type']),
      logo: jsonObject(json['logo']) != null
          ? ImageUrlsModel.fromJson(jsonObject(json['logo'])!)
          : null,
      address: jsonString(json['address']),
      phone: jsonString(json['phone']),
      email: jsonString(json['email']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'logo': logo?.toJson(),
      'address': address,
      'phone': phone,
      'email': email,
    };
  }

  Organization toEntity() {
    return Organization(
      id: id ?? 0,
      name: name ?? '',
      type: type,
      address: address,
      phone: phone,
      email: email,
    );
  }
}

/// Data model for avatar.
class AvatarModel {
  final int id;
  final String name;
  final ImageUrlsModel image;

  const AvatarModel({
    required this.id,
    required this.name,
    required this.image,
  });

  factory AvatarModel.fromJson(Map<String, dynamic> json) {
    return AvatarModel(
      id: jsonInt(json['id']) ?? 0,
      name: jsonString(json['name']) ?? '',
      image:
          ImageUrlsModel.fromJson(jsonObject(json['image']) ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image': image.toJson(),
    };
  }

  Avatar toEntity() {
    return Avatar(
      id: id,
      name: name,
      image: image.toEntity(),
    );
  }
}

/// Data model for image URLs.
class ImageUrlsModel {
  final String? thumbnail;
  final String? medium;
  final String? large;
  final String? original;

  const ImageUrlsModel({
    this.thumbnail,
    this.medium,
    this.large,
    this.original,
  });

  factory ImageUrlsModel.fromJson(Map<String, dynamic> json) {
    return ImageUrlsModel(
      thumbnail: jsonString(json['thumbnail']),
      medium: jsonString(json['medium']),
      large: jsonString(json['large']),
      original: jsonString(json['original']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'thumbnail': thumbnail,
      'medium': medium,
      'large': large,
      'original': original,
    };
  }

  ImageUrls toEntity() {
    return ImageUrls(
      original: original ?? '',
      medium: medium,
      thumbnail: thumbnail,
    );
  }
}

/// Data model for interest.
///
/// `slug`, `category_id`, `sort_order` and `upcoming_events` came with
/// topics; each is optional, so a payload from before them still reads.
class InterestModel {
  final int? id;
  final String? name;
  final String? icon;
  final String? iconType;
  final String? slug;
  final int? categoryId;
  final int? sortOrder;
  final int? upcomingEvents;

  const InterestModel({
    this.id,
    this.name,
    this.icon,
    this.iconType,
    this.slug,
    this.categoryId,
    this.sortOrder,
    this.upcomingEvents,
  });

  /// [categoryId] is the topic the interest was listed under, for a payload
  /// that nests interests in their topic rather than naming it on each.
  factory InterestModel.fromJson(Map<String, dynamic> json,
      {int? categoryId}) {
    return InterestModel(
      // `as int?` throws on 3.0; JSON does not promise which one arrives.
      id: _jsonInt(json['id']),
      name: jsonString(json['name']),
      icon: _jsonString(json['icon']),
      iconType: _jsonString(json['icon_type']),
      slug: _jsonString(json['slug']),
      categoryId: _jsonInt(json['category_id']) ?? categoryId,
      sortOrder: _jsonInt(json['sort_order']),
      upcomingEvents: _jsonInt(json['upcoming_events']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'icon_type': iconType,
      if (slug != null) 'slug': slug,
      if (categoryId != null) 'category_id': categoryId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (upcomingEvents != null) 'upcoming_events': upcomingEvents,
    };
  }

  Interest toEntity() {
    return Interest(
      id: id ?? 0,
      name: name ?? '',
      icon: icon,
      iconType: iconType,
      slug: slug,
      categoryId: categoryId,
      sortOrder: sortOrder,
      upcomingEvents: upcomingEvents,
    );
  }
}

int? _jsonInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _jsonString(Object? value) => value is String ? value : null;

/// Request model for creating profile.
class CreateProfileRequest {
  final String fullName;
  final String whatsapp;
  final int organizationId;

  const CreateProfileRequest({
    required this.fullName,
    required this.whatsapp,
    required this.organizationId,
  });

  Map<String, dynamic> toJson() {
    return {
      'full_name': fullName,
      'whatsapp': whatsapp,
      'org_id': organizationId,
    };
  }
}

/// Request model for updating profile.
class UpdateProfileRequest {
  final String? fullName;
  final String? phone;
  final String? whatsapp;
  final int? organizationId;

  const UpdateProfileRequest({
    this.fullName,
    this.phone,
    this.whatsapp,
    this.organizationId,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {};
    if (fullName != null) data['full_name'] = fullName;
    if (phone != null) data['phone'] = phone;
    if (whatsapp != null) data['whatsapp'] = whatsapp;
    if (organizationId != null) data['org_id'] = organizationId;
    return data;
  }
}
