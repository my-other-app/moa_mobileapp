import 'package:myotherapp/features/profile/domain/entities/profile_entity.dart';

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

  const UserProfileModel({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.username,
    this.userType,
    this.profile,
    this.interests,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as int? ?? 0,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      username: json['username'] as String?,
      userType: json['user_type'] as String?,
      profile: json['profile'] != null
          ? ProfileDetailsModel.fromJson(
              json['profile'] as Map<String, dynamic>)
          : null,
      interests: (json['interests'] as List<dynamic>?)
          ?.map((e) => InterestModel.fromJson(e as Map<String, dynamic>))
          .toList(),
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
      interests: interests?.map((e) => e.toEntity()).toList() ?? [],
      isProfileComplete: _isProfileComplete(),
      createdAt: null,
    );
  }

  bool _isProfileComplete() {
    return fullName != null &&
        fullName!.isNotEmpty &&
        profile?.org != null &&
        profile?.avatar != null;
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
      fullName: json['full_name'] as String?,
      whatsapp: json['whatsapp'] as String?,
      org: json['org'] != null
          ? OrganizationModel.fromJson(json['org'] as Map<String, dynamic>)
          : null,
      avatar: json['avatar'] != null
          ? AvatarModel.fromJson(json['avatar'] as Map<String, dynamic>)
          : null,
      profilePic: json['profile_pic'] as Map<String, dynamic>?,
    );
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
      id: json['id'] as int?,
      name: json['name'] as String?,
      type: json['type'] as String?,
      logo: json['logo'] != null
          ? ImageUrlsModel.fromJson(json['logo'] as Map<String, dynamic>)
          : null,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
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
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      image:
          ImageUrlsModel.fromJson(json['image'] as Map<String, dynamic>? ?? {}),
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
      thumbnail: json['thumbnail'] as String?,
      medium: json['medium'] as String?,
      large: json['large'] as String?,
      original: json['original'] as String?,
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
class InterestModel {
  final int? id;
  final String? name;
  final String? icon;
  final String? iconType;

  const InterestModel({
    this.id,
    this.name,
    this.icon,
    this.iconType,
  });

  factory InterestModel.fromJson(Map<String, dynamic> json) {
    return InterestModel(
      id: json['id'] as int?,
      name: json['name'] as String?,
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

  Interest toEntity() {
    return Interest(
      id: id ?? 0,
      name: name ?? '',
      icon: icon,
      iconType: iconType,
    );
  }
}

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
