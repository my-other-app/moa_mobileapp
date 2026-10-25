import 'dart:async';

import 'package:finnet/features/clubs/data/club_follow_service.dart';
import 'package:finnet/features/clubs/domain/club_updates.dart';
import 'package:finnet/features/clubs/presentation/cubits/club_follow_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records each call; [fail] makes the next ones throw, [gate] holds them.
class FakeClubFollowService implements ClubFollowService {
  final calls = <String>[];
  Object? fail;
  Completer<void>? gate;

  Future<void> _answer(String call) async {
    calls.add(call);
    if (gate != null) await gate!.future;
    if (fail != null) throw fail!;
  }

  @override
  Future<void> follow(int clubId, {bool clubUpdates = false}) =>
      _answer('follow $clubId${clubUpdates ? ' +updates' : ''}');

  @override
  Future<void> unfollow(int clubId) => _answer('unfollow $clubId');

  @override
  Future<void> setClubUpdates(int clubId, bool on) =>
      _answer('updates $clubId $on');
}

void main() {
  late FakeClubFollowService service;
  late List<ClubFollowState> states;

  ClubFollowCubit cubit({bool following = false, bool updates = false}) {
    final c = ClubFollowCubit(
        service: service, clubId: 12, following: following, updates: updates);
    c.onStateChanged = states.add;
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    service = FakeClubFollowService();
    states = [];
  });

  test('the box names the club, exactly as the server keeps it', () {
    expect(clubUpdatesText('Robotics Club'),
        'Get updates from Robotics Club on WhatsApp');
    expect(clubUpdatesText('  '), 'Get updates from this club on WhatsApp');
  });

  group('before following', () {
    test('unticked, the follow goes as it always did', () async {
      final c = cubit();
      expect(c.state.boxTicked, isFalse);

      expect(await c.toggleFollow(), isNull);

      expect(service.calls, ['follow 12']);
      expect(c.state.following, isTrue);
      expect(c.state.delta, 1);
      expect(c.state.updates, isFalse);
    });

    test('ticked, the yes goes with the follow and is then theirs', () async {
      final c = cubit();
      c.tickBeforeFollow(true);
      expect(c.state.boxTicked, isTrue);

      await c.toggleFollow();

      expect(service.calls, ['follow 12 +updates']);
      expect(c.state.following, isTrue);
      expect(c.state.updates, isTrue);
      expect(c.state.tickedBeforeFollow, isFalse);
      expect(c.state.boxTicked, isTrue);
    });

    test('shows at once, busy, until the server answers', () async {
      final c = cubit();
      service.gate = Completer();
      final done = c.toggleFollow();

      expect(c.state.following, isTrue);
      expect(c.state.busy, isTrue);
      // A second tap meanwhile does nothing.
      expect(await c.toggleFollow(), isNull);
      expect(service.calls, hasLength(1));

      service.gate!.complete();
      await done;
      expect(c.state.busy, isFalse);
    });

    test('a follow the server refuses puts everything back, tick and all',
        () async {
      final c = cubit();
      c.tickBeforeFollow(true);
      service.fail = Exception('down');

      expect(await c.toggleFollow(), isA<Exception>());

      expect(c.state.following, isFalse);
      expect(c.state.delta, 0);
      expect(c.state.updates, isFalse);
      expect(c.state.tickedBeforeFollow, isTrue);
      expect(c.state.busy, isFalse);
    });

    test('the switch itself waits for the follow: nothing is sent', () async {
      final c = cubit();
      expect(await c.setUpdates(true), isNull);
      expect(service.calls, isEmpty);
      expect(c.state.updates, isFalse);
    });
  });

  group('following', () {
    test('a follower turns the updates off and on, the follow untouched',
        () async {
      final c = cubit(following: true, updates: true);
      expect(c.state.boxTicked, isTrue);

      await c.setUpdates(false);
      expect(c.state.updates, isFalse);
      await c.setUpdates(true);

      expect(service.calls, ['updates 12 false', 'updates 12 true']);
      expect(c.state.updates, isTrue);
      expect(c.state.following, isTrue);
      expect(c.state.delta, 0);
    });

    test('a change the server refuses is put back, and says why', () async {
      final c = cubit(following: true);
      service.fail = Exception('down');

      expect(await c.setUpdates(true), isA<Exception>());

      expect(c.state.updates, isFalse);
      expect(c.state.updatesBusy, isFalse);
      expect(states.map((s) => s.updates), [true, false]);
    });

    test('unfollowing takes the yes with it', () async {
      final c = cubit(following: true, updates: true);

      await c.toggleFollow();

      expect(service.calls, ['unfollow 12']);
      expect(c.state.following, isFalse);
      expect(c.state.updates, isFalse);
      expect(c.state.boxTicked, isFalse);
      expect(c.state.delta, -1);
    });

    test('an unfollow the server refuses keeps the yes', () async {
      final c = cubit(following: true, updates: true);
      service.fail = Exception('down');

      await c.toggleFollow();

      expect(c.state.following, isTrue);
      expect(c.state.updates, isTrue);
      expect(c.state.delta, 0);
    });
  });

  test('a fresh copy of the club is the truth again', () async {
    final c = cubit();
    await c.toggleFollow();
    expect(c.state.delta, 1);

    c.sync(clubId: 12, following: true, updates: true);

    expect(c.state.following, isTrue);
    expect(c.state.updates, isTrue);
    expect(c.state.delta, 0);
    // Not following, a yes on the server is not the follower's switch.
    c.sync(clubId: 12, following: false, updates: true);
    expect(c.state.updates, isFalse);
  });

  test('nothing is said after dispose', () async {
    final c = cubit();
    c.dispose();
    c.tickBeforeFollow(true);
    expect(states, isEmpty);
  });
}
