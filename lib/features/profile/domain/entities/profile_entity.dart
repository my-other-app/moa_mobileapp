import 'package:equatable/equatable.dart';

/// User profile entity with detailed information.
class UserProfile extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String? phone;
  final String? whatsapp;
  final Organization? organization;
  final Avatar? avatar;

  /// A photo they uploaded (`profile.profile_pic`), or null. When there is
  /// one it is their picture -- the server, the website and the threads all
  /// show it before the avatar ([pictureUrl]).
  final ImageUrls? photo;
  final List<Interest> interests;
  final bool isProfileComplete;
  final DateTime? createdAt;

  /// Whether the account has shown it owns [email]. Google and Apple accounts
  /// always have; an email/password account once its owner typed back the
  /// code sent there. Null when the server did not say (an older server, or
  /// a response that is not the full profile): then nobody is asked to verify.
  final bool? emailVerified;

  /// "Show me in People Like You": whether others checked in at the same
  /// event see this person in its list. Null when the server did not say (an
  /// older server): then there is no switch to show.
  final bool? networkingVisible;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.whatsapp,
    this.organization,
    this.avatar,
    this.photo,
    this.interests = const [],
    this.isProfileComplete = false,
    this.createdAt,
    this.emailVerified,
    this.networkingVisible,
  });

  /// An email/password account that has not verified its address yet.
  bool get needsEmailVerification => emailVerified == false;

  /// Their picture as everyone sees it: the uploaded photo, else the
  /// avatar they picked, else null. [small] for a picture drawn at most
  /// ~50 points across (the 150 px thumbnail); otherwise the 500 px one.
  String? pictureUrl({bool small = false}) =>
      photo?.urlFor(small: small) ?? avatar?.image.urlFor(small: small);

  /// The same profile with this picture: [avatar] and [photo] exactly as
  /// given, null included -- picking an avatar replaces a photo.
  UserProfile withPicture({required Avatar? avatar, required ImageUrls? photo}) =>
      UserProfile(
        id: id,
        fullName: fullName,
        email: email,
        phone: phone,
        whatsapp: whatsapp,
        organization: organization,
        avatar: avatar,
        photo: photo,
        interests: interests,
        isProfileComplete: isProfileComplete,
        createdAt: createdAt,
        emailVerified: emailVerified,
        networkingVisible: networkingVisible,
      );

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? whatsapp,
    Organization? organization,
    Avatar? avatar,
    ImageUrls? photo,
    List<Interest>? interests,
    bool? isProfileComplete,
    DateTime? createdAt,
    bool? emailVerified,
    bool? networkingVisible,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      organization: organization ?? this.organization,
      avatar: avatar ?? this.avatar,
      photo: photo ?? this.photo,
      interests: interests ?? this.interests,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      emailVerified: emailVerified ?? this.emailVerified,
      networkingVisible: networkingVisible ?? this.networkingVisible,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fullName,
        email,
        phone,
        whatsapp,
        organization,
        avatar,
        photo,
        interests,
        isProfileComplete,
        createdAt,
        emailVerified,
        networkingVisible,
      ];
}

/// Organization/College entity.
class Organization extends Equatable {
  final int id;
  final String name;
  final String? type;
  final String? address;
  final String? phone;
  final String? email;

  const Organization({
    required this.id,
    required this.name,
    this.type,
    this.address,
    this.phone,
    this.email,
  });

  @override
  List<Object?> get props => [id, name, type, address, phone, email];
}

/// User avatar entity.
class Avatar extends Equatable {
  final int id;
  final String name;
  final ImageUrls image;

  const Avatar({
    required this.id,
    required this.name,
    required this.image,
  });

  @override
  List<Object?> get props => [id, name, image];
}

/// Image URLs with different resolutions.
class ImageUrls extends Equatable {
  final String original;
  final String? medium;
  final String? thumbnail;

  const ImageUrls({
    required this.original,
    this.medium,
    this.thumbnail,
  });

  /// Get the best available URL (prefer smaller sizes for thumbnails).
  String get thumbnailUrl => thumbnail ?? medium ?? original;

  /// Get medium resolution URL.
  String get mediumUrl => medium ?? original;

  /// The first non-blank of the sizes, smallest first when [small]; null
  /// when there is none.
  String? urlFor({bool small = false}) {
    final order = small
        ? [thumbnail, medium, original]
        : [medium, original, thumbnail];
    for (final url in order) {
      if (url != null && url.trim().isNotEmpty) return url;
    }
    return null;
  }

  /// Every size there is, for clearing them from the picture cache.
  List<String> get allUrls => [
        for (final url in {original, medium, thumbnail})
          if (url != null && url.trim().isNotEmpty) url,
      ];

  @override
  List<Object?> get props => [original, medium, thumbnail];
}

/// An interest: what people, clubs and events are tagged with.
///
/// Interests sit under a topic (the server's interest category, its
/// `category_id`). The topic fields are optional: a server from before
/// topics sends only id, name and icon.
class Interest extends Equatable {
  final int id;
  final String name;
  final String? icon;
  final String? iconType;

  /// URL-safe name; null from a server that does not send one.
  final String? slug;

  /// The topic this interest sits under; null when the payload did not say.
  final int? categoryId;

  /// Position within its topic; null when the server does not order them.
  final int? sortOrder;

  /// Upcoming events tagged with it -- only `/interests/topics` counts them.
  final int? upcomingEvents;

  const Interest({
    required this.id,
    required this.name,
    this.icon,
    this.iconType,
    this.slug,
    this.categoryId,
    this.sortOrder,
    this.upcomingEvents,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        icon,
        iconType,
        slug,
        categoryId,
        sortOrder,
        upcomingEvents,
      ];
}
