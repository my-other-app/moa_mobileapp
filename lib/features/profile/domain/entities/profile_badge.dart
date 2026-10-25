import 'package:finnet/core/utils/json_read.dart';

/// A badge a person can earn, and when they earned it.
///
/// The server's `BadgeDefinitionResponse` (`app/api/badges/schemas.py`):
/// every badge, for a person (`badge_type: user`) or for a club. The
/// person's own come from `GET /badges/me`, each with `awarded_at`.
/// [description] says what earns it ("Attended 5 events"), which is what a
/// locked badge shows.
class ProfileBadge {
  const ProfileBadge({
    required this.id,
    required this.slug,
    required this.name,
    required this.description,
    required this.emoji,
    this.badgeType = 'user',
    this.triggerMetric = '',
    this.threshold = 1,
    this.awardedAt,
  });

  final int id;
  final String slug;
  final String name;
  final String description;
  final String emoji;

  /// `user` or `club`.
  final String badgeType;
  final String triggerMetric;
  final double threshold;

  /// When it was awarded; null for one not earned yet.
  final DateTime? awardedAt;

  bool get earned => awardedAt != null;

  /// A badge a person can earn (not a club's).
  bool get isForPeople => badgeType == 'user';

  /// One of `GET /badges/definitions`, or the `badge` of an award. Null
  /// without an id or a name: nothing to show.
  static ProfileBadge? fromJson(Object? json, {DateTime? awardedAt}) {
    final o = jsonObject(json);
    if (o == null) return null;
    final id = jsonInt(o['id']);
    final name = jsonText(o['name']).trim();
    if (id == null || name.isEmpty) return null;
    final emoji = jsonText(o['emoji']).trim();
    return ProfileBadge(
      id: id,
      slug: jsonText(o['slug']),
      name: name,
      description: jsonText(o['description']).trim(),
      emoji: emoji.isEmpty ? '🏅' : emoji,
      badgeType: jsonText(o['badge_type'], 'user'),
      triggerMetric: jsonText(o['trigger_metric']),
      threshold: jsonDouble(o['threshold']) ?? 1,
      awardedAt: awardedAt,
    );
  }

  /// One award of `GET /badges/me`: `{id, badge: {...}, awarded_at}`.
  static ProfileBadge? fromAward(Object? json) {
    final o = jsonObject(json);
    if (o == null) return null;
    return fromJson(o['badge'],
        awardedAt: jsonDate(o['awarded_at']) ?? DateTime.now());
  }
}

/// The person's badges: the ones earned, newest first, and the ones still
/// to earn, in the server's order.
class BadgeShelf {
  const BadgeShelf({required this.earned, required this.locked});

  /// From `GET /badges/me` ([awards]) and `GET /badges/definitions`
  /// ([definitions]; empty when it could not be read: then only the earned
  /// ones show). Only the badges people earn are listed, not clubs'.
  factory BadgeShelf.from({
    required List<ProfileBadge> awards,
    required List<ProfileBadge> definitions,
  }) {
    final earned = [
      for (final b in awards)
        if (b.isForPeople) b,
    ]..sort((a, b) => b.awardedAt!.compareTo(a.awardedAt!));
    final have = {for (final b in earned) b.id};
    final locked = [
      for (final b in definitions)
        if (b.isForPeople && !have.contains(b.id)) b,
    ];
    return BadgeShelf(earned: earned, locked: locked);
  }

  final List<ProfileBadge> earned;
  final List<ProfileBadge> locked;

  int get total => earned.length + locked.length;
}
