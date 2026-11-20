import 'package:finnet/features/quests/domain/quest.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quest_fixtures.dart';

void main() {
  group('the card', () {
    test('off, or no quest: nothing to show', () {
      expect(Quest.fromJson({'enabled': false}, eventId: 1).enabled, isFalse);
      expect(Quest.fromJson(null, eventId: 1).enabled, isFalse);
      expect(Quest.fromJson('nonsense', eventId: 1).enabled, isFalse);
    });

    test('reads the contract shape', () {
      final q = Quest.fromJson(questJson(feedback: null), eventId: 1);
      expect(q.enabled, isTrue);
      expect(q.eventId, 1);
      expect(q.name, 'DevFest Quest');
      expect(q.mode, QuestMode.points);
      expect(q.tasks, hasLength(7));
      expect(q.milestones.map((m) => m.title), ['Tier 1', 'Tier 2']);
      expect(q.me?.points, 20);
      expect(q.me?.next?.left, 10);
      expect(q.collectAt.single.name, 'Swag desk');
      expect(q.links.poster, 'https://myotherapp.in/posters/MOA-1?s=k');
      expect(q.links.feedback, isNull);
      expect(q.takingPart, isTrue);
      expect(q.doneCount, 2);
    });

    test('a task: its action, count and station', () {
      final q = Quest.fromJson(questJson(networkCount: 3), eventId: 1);
      final net = q.networkTask!;
      expect(net.action, QuestAction.networkScan);
      expect(net.counted, isTrue);
      expect(net.count, 3);
      expect(net.countLabel, '3 of 5 met');
      final booth = q.tasks.firstWhere((t) => t.kind == QuestKinds.station);
      expect(booth.action, QuestAction.station);
      expect(booth.stationName, 'Google Cloud booth');
      expect(booth.countLabel, isNull);
      final quiz = q.tasks.firstWhere((t) => t.kind == QuestKinds.quizPlayed);
      expect(quiz.action, QuestAction.liveRoom);
    });

    test('a count stays within its target, and is the target once done', () {
      final over = QuestTask.fromJson(
          taskJson('t', kind: 'polls', title: 'Polls', target: 3, count: 7))!;
      expect(over.count, 3);
      final done = QuestTask.fromJson(taskJson('t',
          kind: 'polls', title: 'Polls', target: 3, count: 1, done: true))!;
      expect(done.count, 3);
      expect(done.countLabel, '3 / 3');
    });

    test('odd fields fall back rather than throw', () {
      final task = QuestTask.fromJson({
        'id': 7,
        'kind': 'SOMETHING_NEW',
        'points': '15',
        'target': 0,
        'action': 'teleport',
        'me': 'yes',
      })!;
      expect(task.id, '7');
      expect(task.title, 'A task');
      expect(task.points, 15);
      expect(task.target, 1);
      expect(task.action, QuestAction.none);
      expect(task.me, isNull);
      expect(QuestTask.fromJson({'title': 'no id'}), isNull);
      expect(
          QuestTask.listFrom([null, 3, taskJson('a', kind: 'x', title: 'A')]),
          hasLength(1));
    });

    test('without an account (or a ticket): the overview only', () {
      final q = Quest.fromJson(questJson(me: false), eventId: 1);
      expect(q.takingPart, isFalse);
      expect(q.tasks.every((t) => t.me == null && !t.done), isTrue);
      expect(q.nextLine, isNull);
      expect(q.score, 0);
    });
  });

  group('progress to the next milestone', () {
    test('points: what is left, and the bar from the tier below', () {
      final q = Quest.fromJson(questJson(), eventId: 1);
      expect(q.nextLine, '10 more points to unlock Tier 1');
      expect(q.progressToNext, closeTo(20 / 30, 0.001));
      // Past Tier 1, on to Tier 2: the bar starts again at Tier 1's 30.
      final second = Quest.fromJson(
          questJson(points: 45, tier1Unlocked: true, next: {
            'milestone_id': 'm-2',
            'title': 'Tier 2',
            'threshold': 60,
            'left': 15,
          }),
          eventId: 1);
      expect(second.progressToNext, closeTo(15 / 30, 0.001));
      expect(second.nextLine, '15 more points to unlock Tier 2');
    });

    test('checkmarks count tasks', () {
      final q = Quest.fromJson(
          questJson(mode: 'checkmarks', next: {
            'milestone_id': 'm-1',
            'title': 'Tier 1',
            'threshold': 3,
            'left': 1,
          }),
          eventId: 1);
      expect(q.mode, QuestMode.checkmarks);
      expect(q.nextLine, '1 more task to unlock Tier 1');
      expect(q.units(2), '2 tasks');
    });

    test('a required task left: said, even with the score there', () {
      final q = Quest.fromJson(
          questJson(requiredLeft: 1, next: {
            'milestone_id': 'm-1',
            'title': 'Tier 1',
            'threshold': 30,
            'left': 0,
          }),
          eventId: 1);
      expect(q.nextLine, 'Finish the required task to unlock Tier 1');
    });

    test('every milestone reached', () {
      final q = Quest.fromJson(questJson(tier1Unlocked: true, next: null),
          eventId: 1);
      expect(q.nextLine, 'Every reward unlocked. Well done!');
      expect(q.progressToNext, 1);
    });
  });

  group('rewards', () {
    test('an unlocked tier gives its claim, collected where the desk is', () {
      final q = Quest.fromJson(questJson(tier1Unlocked: true), eventId: 1);
      final unlocked = q.unlockedRewards.single;
      expect(unlocked.milestone.title, 'Tier 1');
      expect(unlocked.reward.name, 'DevFest T-shirt');
      expect(unlocked.reward.claim?.status, QuestClaimStatus.reserved);
      expect(unlocked.reward.claim?.variantLabel, 'M');
      expect(q.deskLine, 'Swag desk');
      expect(q.unlockedIds, {'m-1'});
    });

    test('claim statuses, sizes and the waiting list', () {
      QuestClaim claim(Map<String, dynamic> json) => QuestClaim.fromJson(json)!;
      final needs = claim(claimJson(needsSize: true, choices: [
        {'label': 'S', 'free': 4},
        {'label': 'M', 'free': 0},
      ]));
      expect(needs.canPickSize, isTrue);
      expect(needs.choices.map((c) => c.label), ['S', 'M']);
      expect(needs.choices.last.free, 0);
      final waiting =
          claim(claimJson(status: 'waitlisted', waitlistPosition: 3));
      expect(waiting.status, QuestClaimStatus.waitlisted);
      expect(waiting.waitlistPosition, 3);
      expect(waiting.canPickSize, isFalse);
      expect(claim(claimJson(status: 'sold_out')).status,
          QuestClaimStatus.soldOut);
      expect(
          claim(claimJson(
                  status: 'collected', collectedAt: '2026-11-28T05:32:00Z'))
              .collectedAt,
          isNotNull);
      expect(QuestClaim.fromJson(claimJson(status: 'mystery')), isNull);
    });

    test('a released claim is not shown', () {
      final q = Quest.fromJson(
          questJson(
              tier1Unlocked: true, tier1Claim: claimJson(status: 'released')),
          eventId: 1);
      expect(q.unlockedRewards, isEmpty);
    });

    test('one handed over stays, even if its milestone was withdrawn', () {
      final json = questJson(
          tier1Unlocked: true, tier1Claim: claimJson(status: 'collected'));
      final tier1 = (json['milestones'] as List).first as Map<String, dynamic>;
      tier1['unlocked'] = false;
      final q = Quest.fromJson(json, eventId: 1);
      expect(q.unlockedRewards.single.reward.claim?.status,
          QuestClaimStatus.collected);
    });

    test('a tick taken back by the organisers is said', () {
      final task = QuestTask.fromJson({
        ...taskJson('t', kind: 'manual', title: 'Hackathon'),
        'me': {'count': 0, 'done': false, 'revoked': true},
      })!;
      expect(task.done, isFalse);
      expect(task.me?.revoked, isTrue);
    });

    test('several desks, or none named', () {
      final two = Quest.fromJson(
          questJson(collectAt: [
            {'door_id': 'a', 'name': 'Swag desk'},
            {'door_id': 'b', 'name': 'Hall B'},
          ]),
          eventId: 1);
      expect(two.deskLine, 'Swag desk or Hall B');
      final none = Quest.fromJson(questJson(collectAt: []), eventId: 1);
      expect(none.deskLine, 'the swag desk');
    });

    test('a new claim replaces the old one of the same id', () {
      final q = Quest.fromJson(questJson(tier1Unlocked: true), eventId: 1);
      final changed =
          q.withClaim(QuestClaim.fromJson(claimJson(variant: 'L'))!);
      expect(changed.unlockedRewards.single.reward.claim?.variantLabel, 'L');
    });
  });

  group('the leaderboard', () {
    test('rows, and the viewer below them', () {
      final board = QuestLeaderboard.fromJson({
        'mode': 'points',
        'rows': [
          {'rank': 1, 'name': 'Asha K.', 'score': 120, 'me': false},
          {'rank': 2, 'name': 'Ben T.', 'score': 90, 'me': false},
        ],
        'me': {'rank': 14, 'score': 40},
      });
      expect(board.rows.first.name, 'Asha K.');
      expect(board.meBelow, isTrue);
      expect(board.myScore, 40);
    });

    test('the viewer among the rows is not shown twice', () {
      final board = QuestLeaderboard.fromJson({
        'rows': [
          {'rank': 1, 'name': 'Asha K.', 'score': 120, 'me': true},
        ],
        'me': {'rank': 1, 'score': 120},
      });
      expect(board.meBelow, isFalse);
    });
  });

  group('times', () {
    test('today by the clock, another day with its date', () {
      final now = DateTime(2026, 11, 28, 10);
      expect(questWhen(DateTime(2026, 11, 28, 15, 5), now), '3:05 PM');
      expect(questWhen(DateTime(2026, 11, 29, 9, 0), now), '29 Nov, 9:00 AM');
      expect(questWhen(DateTime(2026, 11, 28, 0, 30), now), '12:30 AM');
    });

    test("a task's own window", () {
      final task = QuestTask.fromJson(taskJson('t',
          kind: 'code',
          title: 'Code',
          startsAt: '2026-11-28T09:00:00Z',
          endsAt: '2026-11-28T10:00:00Z'))!;
      expect(task.windowAt(DateTime.utc(2026, 11, 28, 8, 59)),
          QuestTaskWindow.notYet);
      expect(task.windowAt(DateTime.utc(2026, 11, 28, 9, 30)),
          QuestTaskWindow.open);
      expect(
          task.windowAt(DateTime.utc(2026, 11, 28, 10)), QuestTaskWindow.over);
    });
  });
}
