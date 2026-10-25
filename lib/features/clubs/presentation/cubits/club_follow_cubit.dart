import 'package:finnet/features/clubs/data/club_follow_service.dart';

/// Following one club, as the club page shows it.
class ClubFollowState {
  /// Whether the person follows the club, as tapped until the server's
  /// copy of the club says otherwise.
  final bool following;

  /// How the followers count moved with this person's own taps.
  final int delta;

  /// Their yes to "Get updates from `<club>` on WhatsApp", while following.
  final bool updates;

  /// The box ticked before following: it goes with the next follow.
  final bool tickedBeforeFollow;

  /// A follow or unfollow is on its way.
  final bool busy;

  /// Turning the updates on or off is on its way.
  final bool updatesBusy;

  const ClubFollowState({
    this.following = false,
    this.delta = 0,
    this.updates = false,
    this.tickedBeforeFollow = false,
    this.busy = false,
    this.updatesBusy = false,
  });

  /// What the box shows: the follower's yes, or the tick waiting for the
  /// follow.
  bool get boxTicked => following ? updates : tickedBeforeFollow;

  ClubFollowState copyWith({
    bool? following,
    int? delta,
    bool? updates,
    bool? tickedBeforeFollow,
    bool? busy,
    bool? updatesBusy,
  }) {
    return ClubFollowState(
      following: following ?? this.following,
      delta: delta ?? this.delta,
      updates: updates ?? this.updates,
      tickedBeforeFollow: tickedBeforeFollow ?? this.tickedBeforeFollow,
      busy: busy ?? this.busy,
      updatesBusy: updatesBusy ?? this.updatesBusy,
    );
  }
}

/// Follows and unfollows a club, and holds a follower's yes to the club's
/// updates on WhatsApp. Callback-based like the auth cubits: the page
/// listens through [onStateChanged] and calls [dispose] when it goes.
///
/// Each tap shows at once and is put back if the server says no; the
/// failing call returns its error for the page to say.
class ClubFollowCubit {
  final ClubFollowService service;
  int _clubId;

  ClubFollowState _state;
  ClubFollowState get state => _state;

  void Function(ClubFollowState)? onStateChanged;
  bool _disposed = false;

  ClubFollowCubit({
    required this.service,
    required int clubId,
    bool following = false,
    bool updates = false,
  })  : _clubId = clubId,
        _state = ClubFollowState(
            following: following, updates: following && updates);

  void _emit(ClubFollowState next) {
    if (_disposed) return;
    _state = next;
    onStateChanged?.call(_state);
  }

  /// A fresh copy of the club from the server: the truth again. A tick
  /// waiting for the follow is kept.
  void sync(
      {required int clubId, required bool following, required bool updates}) {
    if (clubId > 0) _clubId = clubId;
    _emit(ClubFollowState(
      following: following,
      updates: following && updates,
      tickedBeforeFollow: _state.tickedBeforeFollow,
    ));
  }

  /// The box, ticked or not, before following.
  void tickBeforeFollow(bool on) {
    if (_state.following) return;
    _emit(_state.copyWith(tickedBeforeFollow: on));
  }

  /// Follows -- with the club's updates when the box was ticked -- or
  /// unfollows. Null when done; the server's error when it said no, with
  /// everything put back as it was.
  Future<Object?> toggleFollow() async {
    if (_state.busy || _clubId <= 0) return null;
    final before = _state;
    final want = !before.following;
    final withUpdates = want && before.tickedBeforeFollow;
    _emit(before.copyWith(
      following: want,
      delta: before.delta + (want ? 1 : -1),
      updates: withUpdates,
      tickedBeforeFollow: false,
      busy: true,
    ));
    try {
      if (want) {
        await service.follow(_clubId, clubUpdates: withUpdates);
      } else {
        await service.unfollow(_clubId);
      }
      _emit(_state.copyWith(busy: false));
      return null;
    } catch (e) {
      _emit(before.copyWith(busy: false));
      return e;
    }
  }

  /// A follower turning the club's updates on WhatsApp on or off. Null when
  /// done; the server's error when it said no, and the switch put back.
  Future<Object?> setUpdates(bool on) async {
    if (!_state.following || _state.busy || _state.updatesBusy) return null;
    final was = _state.updates;
    _emit(_state.copyWith(updates: on, updatesBusy: true));
    try {
      await service.setClubUpdates(_clubId, on);
      _emit(_state.copyWith(updatesBusy: false));
      return null;
    } catch (e) {
      _emit(_state.copyWith(updates: was, updatesBusy: false));
      return e;
    }
  }

  void dispose() {
    _disposed = true;
    onStateChanged = null;
  }
}
