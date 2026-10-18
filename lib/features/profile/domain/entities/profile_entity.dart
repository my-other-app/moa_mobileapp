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
  final List<Interest> interests;
  final bool isProfileComplete;
  final DateTime? createdAt;

  /// Whether the account has shown it owns [email]. Google and Apple accounts
  /// always have; an email/password account once its owner typed back the
  /// code sent there. Null when the server did not say (an older server, or
  /// a response that is not the full profile): then nobody is asked to verify.
  final bool? emailVerified;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.phone,
    this.whatsapp,
    this.organization,
    this.avatar,
    this.interests = const [],
    this.isProfileComplete = false,
    this.createdAt,
    this.emailVerified,
  });

  /// An email/password account that has not verified its address yet.
  bool get needsEmailVerification => emailVerified == false;

  UserProfile copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phone,
    String? whatsapp,
    Organization? organization,
    Avatar? avatar,
    List<Interest>? interests,
    bool? isProfileComplete,
    DateTime? createdAt,
    bool? emailVerified,
  }) {
    return UserProfile(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      organization: organization ?? this.organization,
      avatar: avatar ?? this.avatar,
      interests: interests ?? this.interests,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      emailVerified: emailVerified ?? this.emailVerified,
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
        interests,
        isProfileComplete,
        createdAt,
        emailVerified,
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
