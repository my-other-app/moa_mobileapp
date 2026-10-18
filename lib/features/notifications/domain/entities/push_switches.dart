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

  PushSwitches copyWith({bool? clubs, bool? topics, bool? platform}) =>
      PushSwitches(
        clubs: clubs ?? this.clubs,
        topics: topics ?? this.topics,
        platform: platform ?? this.platform,
      );

  @override
  List<Object?> get props => [clubs, topics, platform];
}
