import 'package:flutter/foundation.dart';

import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/shared/utils/image_url.dart';

/// A club as the club lists send it (`/clubs/list`, the club search), read
/// once with the forgiving JSON readers: a field of the wrong type is a
/// default, and a row without an id is no club at all.
///
/// The lists used to hand the raw maps to `build`, where
/// `ClubListTile(clubId: club['id'], ...)` threw on a string id: a red box
/// for that tile, and a fatal error report.
@immutable
class ClubSummary {
  const ClubSummary({
    required this.id,
    required this.name,
    this.slug = '',
    this.logoUrl,
    this.followersCount = 0,
    this.interests = const [],
    this.isFollowing = false,
    this.isPinned = false,
    this.isHidden = false,
  });

  final int id;
  final String name;
  final String slug;

  /// The logo's smallest copy, or null when the club has none.
  final String? logoUrl;
  final int followersCount;

  /// The names of the club's interests.
  final List<String> interests;
  final bool isFollowing;
  final bool isPinned;
  final bool isHidden;

  /// The club in [json], or null when it is not one (no id).
  static ClubSummary? fromJson(Object? json) {
    final club = jsonObject(json);
    final id = jsonInt(club?['id']);
    if (club == null || id == null || id <= 0) return null;
    return ClubSummary(
      id: id,
      name: jsonText(club['name']),
      slug: jsonText(club['slug']),
      logoUrl: imageUrlFrom(club['logo']),
      followersCount: jsonInt(club['followers_count']) ?? 0,
      interests: [
        for (final interest in jsonObjects(club['interests']))
          if (jsonString(interest['name']) case final name?
              when name.isNotEmpty)
            name,
      ],
      // `bool_or` over no rows is null, not false.
      isFollowing: jsonBool(club['is_following']) ?? false,
      isPinned: jsonBool(club['is_pinned']) ?? false,
      isHidden: jsonBool(club['is_hidden']) ?? false,
    );
  }

  /// The clubs in a list, skipping anything that is not one.
  static List<ClubSummary> listFrom(Object? items) => [
        if (items is List)
          for (final item in items)
            if (fromJson(item) case final club?) club,
      ];

  ClubSummary copyWith({bool? isPinned}) => ClubSummary(
        id: id,
        name: name,
        slug: slug,
        logoUrl: logoUrl,
        followersCount: followersCount,
        interests: interests,
        isFollowing: isFollowing,
        isPinned: isPinned ?? this.isPinned,
        isHidden: isHidden,
      );

  @override
  bool operator ==(Object other) =>
      other is ClubSummary &&
      other.id == id &&
      other.name == name &&
      other.slug == slug &&
      other.logoUrl == logoUrl &&
      other.followersCount == followersCount &&
      listEquals(other.interests, interests) &&
      other.isFollowing == isFollowing &&
      other.isPinned == isPinned &&
      other.isHidden == isHidden;

  @override
  int get hashCode => Object.hash(id, name, slug, logoUrl, followersCount,
      Object.hashAll(interests), isFollowing, isPinned, isHidden);
}
