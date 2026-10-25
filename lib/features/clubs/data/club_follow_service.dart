import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/app/router/tracking_ref.dart';
import 'package:finnet/core/api/api_helper.dart';

/// Following a club, and a follower's yes to "Get updates from `<club>` on
/// WhatsApp" (`POST /clubs/follow/{id}` with `club_updates_whatsapp`).
abstract class ClubFollowService {
  /// Follows the club. [clubUpdates] true is the box ticked as they
  /// follow; otherwise the follow is sent exactly as it always was, with no
  /// body.
  Future<void> follow(int clubId, {bool clubUpdates = false});

  /// Unfollows it; the server takes the yes back with it.
  Future<void> unfollow(int clubId);

  /// A follower turning the club's updates on WhatsApp on or off. The
  /// follow stays as it is (already following, the server answers with it).
  Future<void> setClubUpdates(int clubId, bool on);
}

class ApiClubFollowService implements ClubFollowService {
  const ApiClubFollowService();

  /// With the code of the club's tracking link that opened the app, when
  /// one is held ([TrackingRef]): the server credits the follow to it if
  /// it is this club's link.
  @override
  Future<void> follow(int clubId, {bool clubUpdates = false}) async {
    await APIService.instance.request(
      '/clubs/follow/$clubId',
      DioMethod.post,
      param: clubUpdates ? const {'club_updates_whatsapp': true} : null,
      query: trackingQuery(),
    );
  }

  @override
  Future<void> unfollow(int clubId) async {
    await APIService.instance
        .request('/clubs/unfollow/$clubId', DioMethod.post);
  }

  @override
  Future<void> setClubUpdates(int clubId, bool on) async {
    await APIService.instance.request(
      '/clubs/follow/$clubId',
      DioMethod.post,
      param: {'club_updates_whatsapp': on},
    );
  }
}

final clubFollowServiceProvider =
    Provider<ClubFollowService>((ref) => const ApiClubFollowService());

/// `{ref: code}` for a follow, while a tracking link's code is held
/// ([TrackingRef]); null otherwise, and the follow is sent as it always was.
Map<String, dynamic>? trackingQuery() {
  final ref = TrackingRef.instance.current;
  return ref == null ? null : {'ref': ref};
}
