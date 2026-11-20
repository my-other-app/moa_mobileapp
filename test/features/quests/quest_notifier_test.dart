import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/features/quests/data/quest_api.dart';
import 'package:finnet/features/quests/domain/quest.dart';
import 'package:finnet/features/quests/presentation/providers/quest_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quest_fixtures.dart';

Quest _quest(Map<String, dynamic> json) => Quest.fromJson(json, eventId: 1);

/// The server, as the notifier sees it: answers queued in order, the last
/// one kept; a queued error is thrown.
class FakeQuestApi implements QuestApi {
  Quest? savedCopy;
  final cards = <Object>[];
  int reads = 0;
  final codes = <String>[];
  CodeOutcome codeOutcome = const CodeDone();
  Object? sizeAnswer;

  @override
  Future<Quest?> saved(int eventId) async => savedCopy;

  @override
  Future<QuestRead> card(int eventId) async {
    reads++;
    final next = cards.length > 1 ? cards.removeAt(0) : cards.first;
    if (next is QuestRead) return next;
    if (next is Quest) return (quest: next, offline: false);
    throw next;
  }

  @override
  Future<CodeOutcome> enterCode(int eventId, String code) async {
    codes.add(code);
    return codeOutcome;
  }

  @override
  Future<QuestClaim> chooseSize(
      int eventId, String claimId, String label) async {
    final answer = sizeAnswer;
    if (answer is QuestClaim) return answer;
    throw answer ?? StateError('no size answer');
  }

  @override
  Future<QuestLeaderboard?> leaderboard(int eventId, {int limit = 20}) async =>
      null;
}

const _notFound = ApiException(
    message: 'Not found', statusCode: 404, type: ApiExceptionType.notFound);
const _down =
    ApiException(message: 'No internet', type: ApiExceptionType.network);

void main() {
  group('reading the card', () {
    test('the copy on the phone at once, then the server', () async {
      final api = FakeQuestApi()
        ..savedCopy = _quest(questJson(networkCount: 1))
        ..cards.add(_quest(questJson(networkCount: 3)));
      final n = QuestNotifier(api, 1);
      final seen = <int?>[];
      n.addListener((s) => seen.add(s.quest?.networkTask?.count),
          fireImmediately: false);
      await n.load();
      expect(seen, [1, 3]);
      expect(n.state.loading, isFalse);
      expect(n.state.offline, isFalse);
      expect(n.state.visible, isTrue);
      n.dispose();
    });

    test('switched off: not visible', () async {
      final api = FakeQuestApi()..cards.add(_quest(questJson(enabled: false)));
      final n = QuestNotifier(api, 1);
      await n.load();
      expect(n.state.visible, isFalse);
      n.dispose();
    });

    test('a server from before quests (404): hidden, and stays so', () async {
      final api = FakeQuestApi()..cards.add(_notFound);
      final n = QuestNotifier(api, 1);
      await n.load();
      expect(n.state.quest, isNull);
      expect(n.state.loading, isFalse);
      expect(n.state.visible, isFalse);
      n.dispose();
    });

    test('no signal: the copy stays, said to be the phone\'s', () async {
      final api = FakeQuestApi()
        ..savedCopy = _quest(questJson())
        ..cards.add(_down);
      final n = QuestNotifier(api, 1);
      await n.load();
      expect(n.state.visible, isTrue);
      expect(n.state.offline, isTrue);
      // Back online: the server's again.
      api.cards
        ..clear()
        ..add(_quest(questJson(networkCount: 4)));
      await n.refresh();
      expect(n.state.offline, isFalse);
      expect(n.state.quest?.networkTask?.count, 4);
      n.dispose();
    });

    test('the interceptor\'s offline copy is marked as one', () async {
      final api = FakeQuestApi()
        ..cards.add((quest: _quest(questJson()), offline: true));
      final n = QuestNotifier(api, 1);
      await n.load();
      expect(n.state.offline, isTrue);
      n.dispose();
    });

    test('no copy and no signal: nothing shown', () async {
      final api = FakeQuestApi()..cards.add(_down);
      final n = QuestNotifier(api, 1);
      await n.load();
      expect(n.state.quest, isNull);
      expect(n.state.visible, isFalse);
      n.dispose();
    });

    test('reads at the same time are one read', () async {
      final api = FakeQuestApi()..cards.add(_quest(questJson()));
      final n = QuestNotifier(api, 1);
      await Future.wait([n.refresh(), n.refresh(), n.refresh()]);
      expect(api.reads, 1);
      n.dispose();
    });

    test('a milestone unlocked while open is marked new', () async {
      final api = FakeQuestApi()
        ..cards.addAll([
          _quest(questJson()),
          _quest(questJson(points: 30, tier1Unlocked: true)),
        ]);
      final n = QuestNotifier(api, 1);
      await n.load();
      expect(n.state.newlyUnlocked, isEmpty);
      await n.refresh();
      expect(n.state.newlyUnlocked, {'m-1'});
      n.dispose();
    });

    test('one unlocked before it opened is not new', () async {
      final api = FakeQuestApi()
        ..cards.add(_quest(questJson(points: 30, tier1Unlocked: true)));
      final n = QuestNotifier(api, 1);
      await n.load();
      await n.refresh();
      expect(n.state.newlyUnlocked, isEmpty);
      n.dispose();
    });
  });

  group('after a Network save', () {
    test('read again until the count moves, then stops', () {
      fakeAsync((clock) {
        final api = FakeQuestApi()
          ..cards.addAll([
            _quest(questJson(networkCount: 2)),
            // The first recheck: not counted yet.
            _quest(questJson(networkCount: 2)),
            // The second: counted.
            _quest(questJson(networkCount: 3)),
          ]);
        final n = QuestNotifier(api, 1);
        n.load();
        clock.flushMicrotasks();
        n.afterNetworkSave();
        expect(n.state.counting, isTrue);
        clock.elapse(const Duration(seconds: 3));
        expect(api.reads, 2);
        expect(n.state.counting, isTrue);
        clock.elapse(const Duration(seconds: 5));
        expect(api.reads, 3);
        expect(n.state.counting, isFalse);
        expect(n.state.notCounted, isFalse);
        expect(n.state.quest?.networkTask?.countLabel, '3 of 5 met');
        // Nothing more is read.
        clock.elapse(const Duration(minutes: 1));
        expect(api.reads, 3);
        n.dispose();
      });
    });

    test('two saves: waits for both', () {
      fakeAsync((clock) {
        final api = FakeQuestApi()
          ..cards.addAll([
            _quest(questJson(networkCount: 1)),
            _quest(questJson(networkCount: 2)),
            _quest(questJson(networkCount: 3)),
          ]);
        final n = QuestNotifier(api, 1, recheckAfterSave: const [
          Duration(seconds: 2),
          Duration(seconds: 4),
          Duration(seconds: 6),
        ]);
        n.load();
        clock.flushMicrotasks();
        n.afterNetworkSave();
        n.afterNetworkSave();
        clock.elapse(const Duration(seconds: 2));
        expect(n.state.quest?.networkTask?.count, 2);
        expect(n.state.counting, isTrue);
        clock.elapse(const Duration(seconds: 2));
        expect(n.state.quest?.networkTask?.count, 3);
        expect(n.state.counting, isFalse);
        n.dispose();
      });
    });

    test("a save that never counts: stops, and says it didn't", () {
      fakeAsync((clock) {
        final api = FakeQuestApi()..cards.add(_quest(questJson()));
        final n = QuestNotifier(api, 1);
        n.load();
        clock.flushMicrotasks();
        n.afterNetworkSave();
        clock.elapse(const Duration(seconds: 31));
        expect(api.reads, 1 + QuestNotifier.defaultRechecks.length);
        expect(n.state.counting, isFalse);
        expect(n.state.notCounted, isTrue);
        n.dispose();
      });
    });

    test('the task done: nothing to wait for', () {
      fakeAsync((clock) {
        final api = FakeQuestApi()
          ..cards.add(_quest(questJson(networkCount: 5, networkDone: true)));
        final n = QuestNotifier(api, 1);
        n.load();
        clock.flushMicrotasks();
        n.afterNetworkSave();
        expect(n.state.counting, isFalse);
        clock.elapse(const Duration(minutes: 1));
        expect(api.reads, 1);
        n.dispose();
      });
    });

    test('no "meet people" task, or not taking part: nothing', () {
      fakeAsync((clock) {
        final api = FakeQuestApi()..cards.add(_quest(questJson(me: false)));
        final n = QuestNotifier(api, 1);
        n.load();
        clock.flushMicrotasks();
        n.afterNetworkSave();
        expect(n.state.counting, isFalse);
        n.dispose();
      });
    });

    test('closing the screen stops the rechecks', () {
      fakeAsync((clock) {
        final api = FakeQuestApi()..cards.add(_quest(questJson()));
        final n = QuestNotifier(api, 1);
        n.load();
        clock.flushMicrotasks();
        n.afterNetworkSave();
        n.dispose();
        clock.elapse(const Duration(minutes: 1));
        expect(api.reads, 1);
      });
    });
  });

  group('a code', () {
    test('ticked: the card is the answer\'s', () async {
      final api = FakeQuestApi()
        ..cards.add(_quest(questJson()))
        ..codeOutcome = CodeDone(card: _quest(questJson(points: 30)));
      final n = QuestNotifier(api, 1);
      await n.load();
      final outcome = await n.enterCode('  cloud 24 ');
      expect(outcome, isA<CodeDone>());
      expect(api.codes, ['cloud 24']);
      expect(n.state.quest?.me?.points, 30);
      expect(api.reads, 1);
      n.dispose();
    });

    test('wrong: the card is read again (tries left)', () async {
      final api = FakeQuestApi()
        ..cards.add(_quest(questJson()))
        ..codeOutcome = const CodeWrong(left: 3);
      final n = QuestNotifier(api, 1);
      await n.load();
      await n.enterCode('nope');
      await Future<void>.delayed(Duration.zero);
      expect(api.reads, 2);
      n.dispose();
    });
  });

  group('a size', () {
    test('picked: the claim in place, then read again', () async {
      final api = FakeQuestApi()
        ..cards.add(_quest(questJson(
            tier1Unlocked: true, tier1Claim: claimJson(needsSize: true))))
        ..sizeAnswer = QuestClaim.fromJson(claimJson(variant: 'L'));
      final n = QuestNotifier(api, 1);
      await n.load();
      final claim = n.state.quest!.unlockedRewards.single.reward.claim!;
      expect(await n.chooseSize(claim, 'L'), isNull);
      expect(n.state.quest!.unlockedRewards.single.reward.claim?.variantLabel,
          'L');
      n.dispose();
    });

    test('gone: said, with the sizes left', () async {
      final api = FakeQuestApi()
        ..cards.add(_quest(questJson(tier1Unlocked: true)))
        ..sizeAnswer = const ApiException(
          message: 'Gone',
          statusCode: 409,
          errorCode: 'QUEST_SIZE_GONE',
          errors: {
            'choices': [
              {'label': 'S', 'free': 2}
            ],
          },
        );
      final n = QuestNotifier(api, 1);
      await n.load();
      final claim = n.state.quest!.unlockedRewards.single.reward.claim!;
      final outcome = await n.chooseSize(claim, 'L');
      expect(outcome?.message, 'Size L just went. Pick another.');
      expect(outcome?.sizesLeft.single.label, 'S');
      n.dispose();
    });
  });

  test('a read that ends after the screen closed changes nothing', () async {
    final gate = Completer<void>();
    final api = _SlowApi(gate);
    final n = QuestNotifier(api, 1);
    final reading = n.refresh();
    n.dispose();
    gate.complete();
    await reading;
  });
}

class _SlowApi extends FakeQuestApi {
  _SlowApi(this.gate);
  final Completer<void> gate;

  @override
  Future<QuestRead> card(int eventId) async {
    await gate.future;
    return (quest: _quest(questJson()), offline: false);
  }
}
