import 'package:equatable/equatable.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';

/// What an explore list is narrowed to: a topic, and within it one interest.
///
/// The lists the app reads -- `/events/list` and `/clubs/list` -- filter by
/// `interest_ids`, any of them matching. That is exactly what a topic means
/// ("anything with at least one interest under it"), so a topic is sent as
/// its interests: it works the same on today's server and on one with
/// topics. (`topic=` is only defined on `/discover/*`, which the app does
/// not call.)
class TopicFilter extends Equatable {
  final Topic? topic;
  final Interest? interest;

  const TopicFilter({this.topic, this.interest});

  static const none = TopicFilter();

  bool get isActive => topic != null || interest != null;

  /// The ids to send as `interest_ids`: null for no filter; the interest
  /// when one is chosen; else every interest under the topic. Empty for a
  /// topic with no interests -- nothing can match, so nothing is asked.
  List<int>? get interestIds {
    if (interest != null) return [interest!.id];
    if (topic != null) return topic!.interestIds;
    return null;
  }

  /// [interestIds] as the query parameter: `{'interest_ids': '3,6,13'}`, or
  /// nothing when unfiltered.
  Map<String, dynamic> get queryParameters {
    final ids = interestIds;
    if (ids == null || ids.isEmpty) return const {};
    return {'interest_ids': ids.join(',')};
  }

  /// Whether asking would be pointless: a topic with no interests.
  bool get matchesNothing => interestIds?.isEmpty ?? false;

  /// What it reads as: "Coding", "Development", or "".
  String get label => interest?.name ?? topic?.label ?? '';

  /// The filter that [topicRef] (a slug or an id) and [interestId] name,
  /// in [topics]. Names that match nothing are ignored.
  ///
  /// An interest brings its own topic along, and wins when the two
  /// disagree, as on the server. With fewer than two topics there is no
  /// topic to choose -- the one there is holds everything -- so only the
  /// interest is kept.
  static TopicFilter resolve(
    List<Topic> topics, {
    String? topicRef,
    int? interestId,
  }) {
    if (!topicsWorthShowing(topics)) {
      final interest = interestId == null
          ? null
          : interestsOf(topics).where((i) => i.id == interestId).firstOrNull;
      return TopicFilter(interest: interest);
    }
    var topic = topicNamed(topicRef, topics);
    Interest? interest;
    if (interestId != null) {
      final owner = topicOfInterest(interestId, topics);
      if (owner != null) {
        interest = owner.interests.firstWhere((i) => i.id == interestId);
        topic = owner;
      }
    }
    return TopicFilter(topic: topic, interest: interest);
  }

  @override
  List<Object?> get props => [topic?.id, interest?.id];
}
