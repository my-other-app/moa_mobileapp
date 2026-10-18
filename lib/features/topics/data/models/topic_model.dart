import 'package:finnet/features/profile/data/models/profile_models.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _string(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// A topic as the server sends it, in any of its three shapes:
///
/// * `/interests/list` -- with `interests` (icons, `category_id`, order);
/// * `/interests/topics` -- with `upcoming_events`, `clubs`, and interests
///   carrying their own `upcoming_events`;
/// * inside an event or club payload -- just `{id, slug, name, color}`.
///
/// Only `id` and `name` are certain. A server from before topics sends no
/// slug, colour or order, and has no `/interests/topics` at all.
class TopicModel {
  final int? id;
  final String? slug;
  final String? name;
  final String? icon;
  final String? iconType;
  final String? color;
  final String? description;
  final int? sortOrder;
  final int? upcomingEvents;
  final int? clubs;
  final List<InterestModel> interests;

  const TopicModel({
    this.id,
    this.slug,
    this.name,
    this.icon,
    this.iconType,
    this.color,
    this.description,
    this.sortOrder,
    this.upcomingEvents,
    this.clubs,
    this.interests = const [],
  });

  factory TopicModel.fromJson(Map<String, dynamic> json) {
    final id = _int(json['id']);
    final interests = json['interests'];
    return TopicModel(
      id: id,
      slug: _string(json['slug']),
      name: json['name'] is String ? json['name'] as String : null,
      icon: _string(json['icon']),
      iconType: _string(json['icon_type']),
      color: _string(json['color']),
      description: _string(json['description']),
      sortOrder: _int(json['sort_order']),
      upcomingEvents: _int(json['upcoming_events']),
      clubs: _int(json['clubs']),
      // An interest listed under a topic belongs to it, whether or not it
      // repeats the topic's id as its own `category_id`.
      interests: interests is List
          ? [
              for (final e in interests)
                if (e is Map<String, dynamic>)
                  InterestModel.fromJson(e, categoryId: id),
            ]
          : const [],
    );
  }

  Topic toEntity() {
    final name = this.name ?? '';
    return Topic(
      id: id ?? 0,
      slug: slug ?? slugify(name),
      name: name,
      icon: icon,
      iconType: iconType,
      color: color,
      description: description,
      sortOrder: sortOrder,
      interests: sortedByOrder(
        [
          for (final i in interests)
            if (i.id != null) i.toEntity(),
        ],
        (i) => i.sortOrder,
      ),
      upcomingEvents: upcomingEvents,
      clubs: clubs,
    );
  }

  /// A list of topics from a response body: a bare array, or one under
  /// `items`. Anything without an id is dropped. In `sort_order`, the
  /// server's order kept where it gives none.
  static List<Topic> listFromJson(Object? body) {
    final list = body is List
        ? body
        : body is Map<String, dynamic> && body['items'] is List
            ? body['items'] as List
            : const [];
    return sortedByOrder(
      [
        for (final e in list)
          if (e is Map<String, dynamic> && _int(e['id']) != null)
            TopicModel.fromJson(e).toEntity(),
      ],
      (t) => t.sortOrder,
    );
  }

  /// An event's or club's `topics`, or null when the payload has none -- a
  /// server from before topics -- so the caller works them out instead.
  static List<Topic>? declaredIn(Map<String, dynamic> json) {
    final value = json['topics'];
    return value is List ? listFromJson(value) : null;
  }
}

/// A topic as an event or club payload names it: `{id, slug, name, color}`.
Map<String, dynamic> topicRefJson(Topic topic) => {
      'id': topic.id,
      'slug': topic.slug,
      'name': topic.name,
      if (topic.color != null) 'color': topic.color,
    };
