
class Profile {
  final String? fullName;
  final String? email;
  final String? phone;
  final String? username;
  final int id;
  final String? userType;
  final ProfileDetails? profile;

  Profile({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    this.username,
    this.userType,
    this.profile,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] ?? 0,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      username: json['username'] as String?,
      userType: json['user_type'] as String?,
      profile: json['profile'] != null
          ? ProfileDetails.fromJson(json['profile'])
          : null,
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
    };
  }

  @override
  String toString() {
    return 'Profile(id: $id, fullName: $fullName, email: $email, phone: $phone, username: $username, userType: $userType, profile: $profile)';
  }
}

class ProfileDetails {
  final String? interest;
  final String? whatsapp;
  final Org? org;
  final Avatar? avatar;
  final Map<String, dynamic>? profilePic;

  ProfileDetails({
    this.interest,
    this.whatsapp,
    this.org,
    this.avatar,
    this.profilePic,
  });

  factory ProfileDetails.fromJson(Map<String, dynamic> json) {
    return ProfileDetails(
      interest: json['interest'] as String?,
      whatsapp: json['whatsapp'] as String?,
      org: json['org'] != null ? Org.fromJson(json['org']) : null,
      avatar: json['avatar'] != null ? Avatar.fromJson(json['avatar']) : null,
      profilePic: json['profile_pic'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interest': interest,
      'whatsapp': whatsapp,
      'org': org?.toJson(),
      'avatar': avatar?.toJson(),
      'profile_pic': profilePic,
    };
  }

  @override
  String toString() {
    return 'ProfileDetails(interest: $interest, whatsapp: $whatsapp, org: $org, avatar: $avatar, profilePic: $profilePic)';
  }
}

class Org {
  final String? name;
  final String? type;
  final Logo? logo;
  final int? id;

  Org({
    this.name,
    this.type,
    this.logo,
    this.id,
  });

  factory Org.fromJson(Map<String, dynamic> json) {
    return Org(
      name: json['name'] as String?,
      type: json['type'] as String?,
      logo: json['logo'] != null
          ? Logo.fromJson(json['logo'] as Map<String, dynamic>)
          : null,
      id: json['id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'logo': logo?.toJson(),
      'id': id,
    };
  }

  @override
  String toString() {
    return 'Org(name: $name, type: $type, logo: $logo, id: $id)';
  }
}

class Logo {
  final String? thumbnail;
  final String? medium;
  final String? large;
  final String? original;

  Logo({
    this.thumbnail,
    this.medium,
    this.large,
    this.original,
  });

  factory Logo.fromJson(Map<String, dynamic> json) {
    return Logo(
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

  @override
  String toString() {
    return 'Logo(thumbnail: $thumbnail, medium: $medium, large: $large, original: $original)';
  }
}

class Avatar {
  final int? id;
  final String? iconType;
  final String? content;

  Avatar({
    this.id,
    this.iconType,
    this.content,
  });

  factory Avatar.fromJson(Map<String, dynamic> json) {
    return Avatar(
      id: json['id'] as int?,
      iconType: json['icon_type'] as String?,
      content: json['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'icon_type': iconType,
      'content': content,
    };
  }

  @override
  String toString() {
    return 'Avatar(id: $id, iconType: $iconType, content: $content)';
  }
}
