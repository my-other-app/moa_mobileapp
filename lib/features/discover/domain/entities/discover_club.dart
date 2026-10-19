import 'package:equatable/equatable.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

/// A club as the discover lists show it (`ClubCard`).
class DiscoverClub extends Equatable {
  const DiscoverClub({
    required this.id,
    required this.name,
    this.slug,
    this.logo,
    this.cover,
    this.tagline,
    this.locationName,
    this.followers = 0,
    this.upcomingEvents = 0,
    this.interests = const [],
    this.topics = const [],
    this.distanceKm,
  });

  final int id;
  final String name;
  final String? slug;

  /// The S3 dicts or URLs, as sent; read with `imageUrlFrom`.
  final Object? logo;
  final Object? cover;
  final String? tagline;
  final String? locationName;
  final int followers;
  final int upcomingEvents;

  /// Interest names.
  final List<String> interests;
  final List<Topic> topics;
  final double? distanceKm;

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        logo,
        cover,
        tagline,
        locationName,
        followers,
        upcomingEvents,
        interests,
        topics,
        distanceKm,
      ];
}
