import 'package:equatable/equatable.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';

/// Club entity representing a club/organization.
class Club extends Equatable {
  final int id;
  final String name;
  final String slug;
  final ImageUrls? logo;
  final String? locationName;
  final String? locationLink;
  final String? description;
  final double rating;
  final int totalRatings;
  final SocialLinks? socials;
  final List<Interest> interests;

  /// The payload's `topics`; null from a server that does not send them --
  /// see [topicsIn].
  final List<Topic>? topics;
  final int followersCount;
  final String? contactPhone;
  final String? contactEmail;
  final Organization? organization;
  final ClubUserData? userData;

  const Club({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
    this.locationName,
    this.locationLink,
    this.description,
    this.rating = 0,
    this.totalRatings = 0,
    this.socials,
    this.interests = const [],
    this.topics,
    this.followersCount = 0,
    this.contactPhone,
    this.contactEmail,
    this.organization,
    this.userData,
  });

  /// Check if the current user is following this club.
  bool get isFollowing => userData?.isFollowing ?? false;

  /// Check if the current user has pinned this club.
  bool get isPinned => userData?.isPinned ?? false;

  /// Its topics: the server's, else worked out from its interests against
  /// [catalogue] (`/interests/list`).
  List<Topic> topicsIn(List<Topic> catalogue) => resolveTopics(
      declared: topics, interests: interests, catalogue: catalogue);

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        logo,
        locationName,
        locationLink,
        description,
        rating,
        totalRatings,
        socials,
        interests,
        topics,
        followersCount,
        contactPhone,
        contactEmail,
        organization,
        userData,
      ];
}

/// Social media links for a club.
class SocialLinks extends Equatable {
  final String? instagram;
  final String? linkedin;
  final String? youtube;
  final String? twitter;
  final String? facebook;
  final String? website;

  const SocialLinks({
    this.instagram,
    this.linkedin,
    this.youtube,
    this.twitter,
    this.facebook,
    this.website,
  });

  /// Check if any social links are available.
  bool get hasAnySocialLinks =>
      instagram != null ||
      linkedin != null ||
      youtube != null ||
      twitter != null ||
      facebook != null ||
      website != null;

  @override
  List<Object?> get props => [
        instagram,
        linkedin,
        youtube,
        twitter,
        facebook,
        website,
      ];
}

/// User-specific data for a club (following, pinned status).
class ClubUserData extends Equatable {
  final bool isFollowing;
  final bool isPinned;
  final bool isMember;

  const ClubUserData({
    this.isFollowing = false,
    this.isPinned = false,
    this.isMember = false,
  });

  @override
  List<Object?> get props => [isFollowing, isPinned, isMember];
}

/// Club list item for displaying in lists.
class ClubListItem extends Equatable {
  final int id;
  final String name;
  final String slug;
  final ImageUrls? logo;
  final int followersCount;
  final List<Interest> interests;

  /// The payload's `topics`; null from a server that does not send them.
  final List<Topic>? topics;
  final bool isFollowing;
  final bool isPinned;

  const ClubListItem({
    required this.id,
    required this.name,
    required this.slug,
    this.logo,
    this.followersCount = 0,
    this.interests = const [],
    this.topics,
    this.isFollowing = false,
    this.isPinned = false,
  });

  /// Its topics: the server's, else worked out from its interests against
  /// [catalogue] (`/interests/list`).
  List<Topic> topicsIn(List<Topic> catalogue) => resolveTopics(
      declared: topics, interests: interests, catalogue: catalogue);

  ClubListItem copyWith({
    int? id,
    String? name,
    String? slug,
    ImageUrls? logo,
    int? followersCount,
    List<Interest>? interests,
    List<Topic>? topics,
    bool? isFollowing,
    bool? isPinned,
  }) {
    return ClubListItem(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      logo: logo ?? this.logo,
      followersCount: followersCount ?? this.followersCount,
      interests: interests ?? this.interests,
      topics: topics ?? this.topics,
      isFollowing: isFollowing ?? this.isFollowing,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        logo,
        followersCount,
        interests,
        topics,
        isFollowing,
        isPinned,
      ];
}
