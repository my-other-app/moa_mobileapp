import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

// Rules about topics that hold whatever the server sends: ordering, finding
// an interest's topic, the topics of an event or club, and search.

/// [items] in `sort_order`, keeping the server's order among equals and for
/// anything without one (a server from before topics orders them itself).
List<T> sortedByOrder<T>(List<T> items, int? Function(T) orderOf) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final oa = orderOf(a.$2);
    final ob = orderOf(b.$2);
    if (oa != null && ob != null && oa != ob) return oa.compareTo(ob);
    if (oa != null && ob == null) return -1;
    if (oa == null && ob != null) return 1;
    return a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}

/// Whether a set of topics is worth showing as a choice.
///
/// The server before the topics migration filed every interest under one
/// category, "arts" -- Web Development and Cybersecurity included. Offering
/// that one topic as a filter, or labelling every event "Arts", would tell
/// nobody anything; so with fewer than two, screens show interests alone.
bool topicsWorthShowing(List<Topic> topics) => topics.length >= 2;

/// The topic [catalogue] files interest [interestId] under, if any.
Topic? topicOfInterest(int interestId, List<Topic> catalogue) {
  for (final topic in catalogue) {
    for (final interest in topic.interests) {
      if (interest.id == interestId) return topic;
    }
  }
  return null;
}

/// The topic named by [ref] -- a slug or an id -- if [topics] has it.
Topic? topicNamed(String? ref, List<Topic> topics) {
  if (ref == null || ref.trim().isEmpty) return null;
  for (final topic in topics) {
    if (topic.isNamedBy(ref)) return topic;
  }
  return null;
}

/// The topics an event or a club belongs to.
///
/// [declared] is the payload's own `topics`. When the server sent it -- even
/// empty -- it is the answer. A server from before topics sends none, so
/// they are worked out from the item's [interests]: each one's
/// `category_id`, or for a payload without that, the topic the [catalogue]
/// (`/interests/list`) lists it under. A topic the catalogue does not know
/// is left out, having nothing to show it by. In the catalogue's order,
/// each once.
List<Topic> resolveTopics({
  List<Topic>? declared,
  Iterable<Interest> interests = const [],
  List<Topic> catalogue = const [],
}) {
  if (declared != null) return declared;
  if (catalogue.isEmpty) return const [];
  final ids = <int>{};
  for (final interest in interests) {
    final topicId =
        interest.categoryId ?? topicOfInterest(interest.id, catalogue)?.id;
    if (topicId != null) ids.add(topicId);
  }
  return [
    for (final topic in catalogue)
      if (ids.contains(topic.id)) topic,
  ];
}

/// Every interest in [topics], each once, in topic order.
List<Interest> interestsOf(List<Topic> topics) {
  final seen = <int>{};
  return [
    for (final topic in topics)
      for (final interest in topic.interests)
        if (seen.add(interest.id)) interest,
  ];
}

/// [topics] narrowed to what matches [query].
///
/// A topic whose name matches keeps all its interests; otherwise it keeps
/// the interests whose names match, and drops out when none do. Case and
/// surrounding space are ignored; an empty query matches everything.
List<Topic> searchTopics(List<Topic> topics, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return topics;
  final result = <Topic>[];
  for (final topic in topics) {
    if (topic.name.toLowerCase().contains(q)) {
      result.add(topic);
      continue;
    }
    final matching = [
      for (final interest in topic.interests)
        if (interest.name.toLowerCase().contains(q)) interest,
    ];
    if (matching.isNotEmpty) {
      result.add(Topic(
        id: topic.id,
        slug: topic.slug,
        name: topic.name,
        icon: topic.icon,
        iconType: topic.iconType,
        color: topic.color,
        description: topic.description,
        sortOrder: topic.sortOrder,
        interests: matching,
        upcomingEvents: topic.upcomingEvents,
        clubs: topic.clubs,
      ));
    }
  }
  return result;
}
