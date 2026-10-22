import 'package:equatable/equatable.dart';

/// Which kinds of broadcast push a person gets. Each is on unless they
/// turned it off; off, its FCM topics leave the device and its lines leave
/// the inbox.
class PushSwitches extends Equatable {
  const PushSwitches({
    required this.clubs,
    required this.topics,
    required this.platform,
  });

  /// New posts and events from the clubs they follow.
  final bool clubs;

  /// New events under the topics of their interests.
  final bool topics;

  /// Announcements from MyOtherApp.
  final bool platform;

  /// What the server keeps for someone who never changed a switch: every
  /// kind on (`app/core/notifications/topics.py`, `switches`). Shown until
  /// the server's own answer, the first time Settings opens on a phone.
  static const defaults = PushSwitches(clubs: true, topics: true, platform: true);

  PushSwitches copyWith({bool? clubs, bool? topics, bool? platform}) =>
      PushSwitches(
        clubs: clubs ?? this.clubs,
        topics: topics ?? this.topics,
        platform: platform ?? this.platform,
      );

  @override
  List<Object?> get props => [clubs, topics, platform];
}
