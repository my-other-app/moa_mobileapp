import 'package:equatable/equatable.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';

/// A topic: the main category interests sit under -- Development, Deep Tech,
/// Arts and so on.
///
/// The server calls it an interest category (`interest_categories`). People,
/// clubs and events are still tagged with interests; a topic is derived from
/// them. Not to be confused with an event's *type* (Workshop, Talk...), which
/// the server also calls a category.
///
/// Everything beyond id and name is optional: a server from before topics
/// sends neither slug, colour nor order, and only `/interests/topics` counts.
class Topic extends Equatable {
  final int id;

  /// Always set: the server's, or one made from the name when it sent none.
  final String slug;
  final String name;
  final String? icon;
  final String? iconType;

  /// `#RRGGBB` as the server sent it; null when it sent none.
  final String? color;
  final String? description;
  final int? sortOrder;

  /// Its interests, in order. Empty for a topic named inside an event or
  /// club payload, which carries only id, slug, name and colour.
  final List<Interest> interests;

  /// Upcoming events under it -- from `/interests/topics` only.
  final int? upcomingEvents;

  /// Clubs under it -- from `/interests/topics` only.
  final int? clubs;

  const Topic({
    required this.id,
    required this.slug,
    required this.name,
    this.icon,
    this.iconType,
    this.color,
    this.description,
    this.sortOrder,
    this.interests = const [],
    this.upcomingEvents,
    this.clubs,
  });

  /// The name to show. The server before topics named its one category
  /// "arts", in lower case; a name with no capitals gets them.
  String get label {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed != trimmed.toLowerCase()) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  List<int> get interestIds => [for (final i in interests) i.id];

  /// Whether [ref] names this topic: its slug, or its id as text.
  bool isNamedBy(String ref) {
    final r = ref.trim().toLowerCase();
    return r.isNotEmpty && (r == slug.toLowerCase() || r == '$id');
  }

  @override
  List<Object?> get props => [
        id,
        slug,
        name,
        icon,
        iconType,
        color,
        description,
        sortOrder,
        interests,
        upcomingEvents,
        clubs,
      ];
}

/// A slug the way the server makes one: "Gaming & Media" is `gaming-media`.
String slugify(String name) => name
    .trim()
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');
