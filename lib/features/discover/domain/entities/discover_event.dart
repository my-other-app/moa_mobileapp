import 'package:equatable/equatable.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';

/// Where an event stands, as the discover API says.
enum DiscoverEventStatus { upcoming, closingSoon, full, live, ended }

/// The club an event card names.
class DiscoverClubRef extends Equatable {
  const DiscoverClubRef({
    required this.id,
    required this.name,
    this.slug,
    this.logo,
  });

  /// 0 when the server sent none.
  final int id;
  final String name;
  final String? slug;

  /// The S3 dict or a bare URL, as sent; read with `imageUrlFrom`.
  final Object? logo;

  @override
  List<Object?> get props => [id, name, slug, logo];
}

/// An event's category ("Workshop", "Talk"): the API calls it a category,
/// the screens its type.
class DiscoverCategoryRef extends Equatable {
  const DiscoverCategoryRef({required this.id, required this.name});

  final int id;
  final String name;

  @override
  List<Object?> get props => [id, name];
}

/// An event as the discover lists show it (`EventCard`).
class DiscoverEvent extends Equatable {
  const DiscoverEvent({
    required this.id,
    required this.name,
    this.slug,
    this.poster,
    this.startsAt,
    this.endsAt,
    this.locationName,
    this.isOnline = false,
    this.distanceKm,
    this.hasFee = false,
    this.fee,
    this.category,
    this.club,
    this.cohosts = const [],
    this.going = 0,
    this.appliedCount,
    this.capacity,
    this.status = DiscoverEventStatus.upcoming,
    this.summary,
    this.topics = const [],
    this.requiresApproval = false,
    this.highDemand = false,
  });

  final int id;
  final String name;
  final String? slug;

  /// The poster map (`{thumbnail, medium, large, original}`) or a URL.
  final Object? poster;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String? locationName;
  final bool isOnline;
  final double? distanceKm;
  final bool hasFee;
  final double? fee;
  final DiscoverCategoryRef? category;
  final DiscoverClubRef? club;

  /// The clubs co-hosting the event with [club], its host, in the order
  /// they accepted (`cohosts`); empty when it has none, and from a server
  /// older than co-hosting.
  final List<DiscoverClubRef> cohosts;
  final int going;

  /// On an event whose club reviews every registration, how many applied:
  /// every registration ever made for it, whatever became of it, so it
  /// never drops (`applied_count`). Null on any other event, and from a
  /// server older than it: the card then says how many are going, as
  /// before.
  final int? appliedCount;
  final int? capacity;
  final DiscoverEventStatus status;
  final String? summary;
  final List<Topic> topics;

  /// The club reviews every registration (`requires_approval`; false when
  /// not said).
  final bool requiresApproval;

  /// The club has its "High demand" label on (`high_demand`; false when not
  /// said). No number comes with it.
  final bool highDemand;

  bool get isEnded => status == DiscoverEventStatus.ended;

  @override
  List<Object?> get props => [
        id,
        name,
        slug,
        poster,
        startsAt,
        endsAt,
        locationName,
        isOnline,
        distanceKm,
        hasFee,
        fee,
        category,
        club,
        cohosts,
        going,
        appliedCount,
        capacity,
        status,
        summary,
        topics,
        requiresApproval,
        highDemand,
      ];
}
