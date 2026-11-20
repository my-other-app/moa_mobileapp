/// An event's quest as its guest sees it: the tasks, how far they have got,
/// the milestones and the rewards they unlock (feature-register
/// `quests/CONTRACT.md` §8, `GET /events/{id}/quest`).
///
/// Pure Dart: the card, the scanner's progress line and the tests read it
/// without Flutter. Every reader is forgiving -- a field the server leaves
/// out, or sends in another shape, falls back rather than throwing.
library;

import 'package:finnet/core/utils/json_read.dart';

String? _text(Object? value) {
  final s = jsonString(value)?.trim();
  return s == null || s.isEmpty ? null : s;
}

/// How the quest counts: one per task done, or each task's points.
enum QuestMode { checkmarks, points }

QuestMode questModeFrom(Object? value) =>
    _text(value)?.toLowerCase() == 'points'
        ? QuestMode.points
        : QuestMode.checkmarks;

/// What a task's "do it" button opens (§3.2).
enum QuestAction {
  /// The guest's ticket (checking in).
  ticket,

  /// The Network scanner, at this event.
  networkScan,

  /// The live room: the quiz, the polls, Q&A.
  liveRoom,

  /// The feedback survey, when it is open.
  feedback,

  /// The guest's "I'm attending" poster page.
  poster,

  /// The host club's page, to follow it.
  follow,

  /// The guest's own public profile, to finish it.
  profile,

  /// Nothing to open: staff scan the ticket at a station.
  station,

  /// The card's code box.
  code,

  /// Nothing (the organiser marks it done, or an action this build does
  /// not know).
  none,
}

QuestAction questActionFrom(Object? value) =>
    switch (_text(value)?.toLowerCase()) {
      'ticket' => QuestAction.ticket,
      'network_scan' => QuestAction.networkScan,
      'live_room' => QuestAction.liveRoom,
      'feedback' => QuestAction.feedback,
      'poster' => QuestAction.poster,
      'follow' => QuestAction.follow,
      'profile' => QuestAction.profile,
      'station' => QuestAction.station,
      'code' => QuestAction.code,
      _ => QuestAction.none,
    };

/// The task kinds (§3.1) the app treats specially. Any other kind is shown
/// by its title and action alone.
abstract final class QuestKinds {
  static const checkedIn = 'checked_in';
  static const network = 'network';
  static const quizPlayed = 'quiz_played';
  static const quizScore = 'quiz_score';
  static const quizTop = 'quiz_top';
  static const polls = 'polls';
  static const qaQuestion = 'qa_question';
  static const feedback = 'feedback';
  static const posterMade = 'poster_made';
  static const posterLink = 'poster_link';
  static const followClub = 'follow_club';
  static const profileComplete = 'profile_complete';
  static const station = 'station';
  static const code = 'code';
  static const manual = 'manual';

  static const quiz = {quizPlayed, quizScore, quizTop};
}

/// Where a task stands for an instant [now], by its own window.
enum QuestTaskWindow { open, notYet, over }

/// The guest's progress on one task (`me`).
class QuestTaskProgress {
  const QuestTaskProgress({
    this.count = 0,
    this.done = false,
    this.doneAt,
    this.source,
    this.revoked = false,
  });

  final int count;
  final bool done;
  final DateTime? doneAt;

  /// How it was ticked (`grant` when the organiser did); informational.
  final String? source;

  /// The organisers took the tick back: it counts again only when they
  /// give it.
  final bool revoked;

  static QuestTaskProgress? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null) return null;
    return QuestTaskProgress(
      count: jsonInt(json['count']) ?? 0,
      done: jsonBool(json['done']) ?? false,
      doneAt: jsonDate(json['done_at']),
      source: _text(json['source']),
      revoked: jsonBool(json['revoked']) ?? false,
    );
  }
}

class QuestTask {
  const QuestTask({
    required this.id,
    required this.kind,
    required this.title,
    this.description,
    this.points = 0,
    this.required = false,
    this.startsAt,
    this.endsAt,
    this.target = 1,
    this.action = QuestAction.none,
    this.stationName,
    this.me,
  });

  final String id;
  final String kind;
  final String title;
  final String? description;
  final int points;

  /// Every required task must be done before any milestone unlocks.
  final bool required;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// What [count] must reach: 1 for a yes-or-no task.
  final int target;
  final QuestAction action;

  /// A station task's station ("Google Cloud booth").
  final String? stationName;

  /// Null when the viewer is not signed in or not registered.
  final QuestTaskProgress? me;

  bool get done => me?.done ?? false;

  /// The guest's count, never past [target]; [target] once done.
  int get count {
    if (done) return target;
    final c = me?.count ?? 0;
    return c < 0 ? 0 : (c > target ? target : c);
  }

  /// A task counted towards a number ("3 / 5"), not just done or not.
  bool get counted => target > 1;

  bool get isNetwork => kind == QuestKinds.network;

  /// "3 of 5 met" for the Network task, "3 / 5" for any other counted
  /// task; null for a yes-or-no one.
  String? get countLabel {
    if (!counted) return null;
    return isNetwork ? '$count of $target met' : '$count / $target';
  }

  QuestTaskWindow windowAt(DateTime now) {
    final start = startsAt;
    final end = endsAt;
    if (start != null && now.isBefore(start)) return QuestTaskWindow.notYet;
    if (end != null && !now.isBefore(end)) return QuestTaskWindow.over;
    return QuestTaskWindow.open;
  }

  static QuestTask? fromJson(Object? value) {
    final json = jsonObject(value);
    final id = _text(json?['id']);
    if (json == null || id == null) return null;
    final target = jsonInt(json['target']) ?? 1;
    return QuestTask(
      id: id,
      kind: _text(json['kind'])?.toLowerCase() ?? '',
      title: _text(json['title']) ?? 'A task',
      description: _text(json['description']),
      points: jsonInt(json['points']) ?? 0,
      required: jsonBool(json['required']) ?? false,
      startsAt: jsonDate(json['starts_at']),
      endsAt: jsonDate(json['ends_at']),
      target: target < 1 ? 1 : target,
      action: questActionFrom(json['action']),
      stationName: _text(jsonObject(json['station'])?['name']),
      me: QuestTaskProgress.fromJson(json['me']),
    );
  }

  static List<QuestTask> listFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (fromJson(json) case final task?) task,
      ];
}

/// A claim's status (§4.1).
enum QuestClaimStatus { reserved, waitlisted, soldOut, collected, released }

QuestClaimStatus? questClaimStatusFrom(Object? value) =>
    switch (_text(value)?.toLowerCase()) {
      'reserved' => QuestClaimStatus.reserved,
      'waitlisted' => QuestClaimStatus.waitlisted,
      'sold_out' => QuestClaimStatus.soldOut,
      'collected' => QuestClaimStatus.collected,
      'released' => QuestClaimStatus.released,
      _ => null,
    };

/// A size with units left to pick from.
class QuestSizeChoice {
  const QuestSizeChoice({required this.label, this.free});

  final String label;

  /// Units left in it, when the server says.
  final int? free;

  static List<QuestSizeChoice> listFrom(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (item is String && item.trim().isNotEmpty)
          QuestSizeChoice(label: item.trim())
        else if (_text(jsonObject(item)?['label']) case final label?)
          QuestSizeChoice(
              label: label, free: jsonInt(jsonObject(item)?['free'])),
    ];
  }
}

/// The guest's own claim on one reward of an unlocked milestone.
class QuestClaim {
  const QuestClaim({
    required this.id,
    required this.status,
    this.needsSize = false,
    this.variantLabel,
    this.choices = const [],
    this.waitlistPosition,
    this.collectedAt,
  });

  final String id;
  final QuestClaimStatus status;

  /// Reserved, and the item has sizes but none is chosen yet.
  final bool needsSize;

  /// Their size ("M").
  final String? variantLabel;

  /// The sizes with a unit free: to pick one, or to change it.
  final List<QuestSizeChoice> choices;
  final int? waitlistPosition;
  final DateTime? collectedAt;

  /// The guest can pick (or change) a size here.
  bool get canPickSize =>
      status == QuestClaimStatus.reserved && (needsSize || choices.isNotEmpty);

  static QuestClaim? fromJson(Object? value) {
    final json = jsonObject(value);
    final id = _text(json?['claim_id']) ?? _text(json?['id']);
    final status = questClaimStatusFrom(json?['status']);
    if (json == null || id == null || status == null) return null;
    return QuestClaim(
      id: id,
      status: status,
      needsSize: jsonBool(json['needs_size']) ?? false,
      variantLabel: _text(json['variant_label']),
      choices: QuestSizeChoice.listFrom(json['choices']),
      waitlistPosition: jsonInt(json['waitlist_position']),
      collectedAt: jsonDate(json['collected_at']),
    );
  }
}

class QuestReward {
  const QuestReward({
    required this.id,
    required this.name,
    this.photoUrl,
    this.sizes = false,
    this.soldOut = false,
    this.claim,
  });

  final String id;
  final String name;
  final String? photoUrl;

  /// The item comes in sizes.
  final bool sizes;

  /// First come, first served, and nothing left right now.
  final bool soldOut;

  /// The guest's claim, once the milestone is unlocked; null before.
  final QuestClaim? claim;

  static QuestReward? fromJson(Object? value) {
    final json = jsonObject(value);
    final id = _text(json?['reward_id']) ?? _text(json?['id']);
    if (json == null || id == null) return null;
    return QuestReward(
      id: id,
      name: _text(json['name']) ?? 'A reward',
      photoUrl: _text(json['photo_url']),
      sizes: jsonBool(json['sizes']) ?? false,
      soldOut: jsonBool(json['sold_out']) ?? false,
      claim: QuestClaim.fromJson(json['claim']),
    );
  }

  QuestReward withClaim(QuestClaim claim) => QuestReward(
        id: id,
        name: name,
        photoUrl: photoUrl,
        sizes: sizes,
        soldOut: soldOut,
        claim: claim,
      );
}

class QuestMilestone {
  const QuestMilestone({
    required this.id,
    required this.title,
    required this.threshold,
    this.unlocked = false,
    this.unlockedAt,
    this.rewards = const [],
  });

  final String id;
  final String title;

  /// Tasks done (checkmarks) or points (points mode) it takes.
  final int threshold;
  final bool unlocked;
  final DateTime? unlockedAt;
  final List<QuestReward> rewards;

  /// Its rewards, without the ones withdrawn from the guest.
  List<QuestReward> get shownRewards => [
        for (final r in rewards)
          if (r.claim?.status != QuestClaimStatus.released) r,
      ];

  static QuestMilestone? fromJson(Object? value) {
    final json = jsonObject(value);
    final id = _text(json?['id']) ?? _text(json?['milestone_id']);
    if (json == null || id == null) return null;
    return QuestMilestone(
      id: id,
      title: _text(json['title']) ?? 'A milestone',
      threshold: jsonInt(json['threshold']) ?? 0,
      unlocked: jsonBool(json['unlocked']) ?? false,
      unlockedAt: jsonDate(json['unlocked_at']),
      rewards: [
        for (final r in jsonObjects(json['rewards']))
          if (QuestReward.fromJson(r) case final reward?) reward,
      ],
    );
  }
}

/// The next milestone, and how far off it is.
class QuestNext {
  const QuestNext({
    required this.milestoneId,
    required this.title,
    required this.threshold,
    required this.left,
  });

  final String milestoneId;
  final String title;
  final int threshold;

  /// Tasks or points still to go.
  final int left;

  static QuestNext? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null) return null;
    final threshold = jsonInt(json['threshold']) ?? 0;
    return QuestNext(
      milestoneId: _text(json['milestone_id']) ?? '',
      title: _text(json['title']) ?? 'the next reward',
      threshold: threshold,
      left: jsonInt(json['left']) ?? threshold,
    );
  }
}

/// The guest's totals (`me`).
class QuestMe {
  const QuestMe({
    this.registrationId,
    this.points = 0,
    this.tasksDone = 0,
    this.requiredLeft = 0,
    this.next,
    this.rank,
    this.codeAttemptsLeft,
  });

  final String? registrationId;
  final int points;
  final int tasksDone;

  /// Required tasks not done yet: no milestone unlocks before they are.
  final int requiredLeft;

  /// Null once every milestone is reached.
  final QuestNext? next;

  /// Their place, only while the leaderboard is on.
  final int? rank;
  final int? codeAttemptsLeft;

  static QuestMe? fromJson(Object? value) {
    final json = jsonObject(value);
    if (json == null) return null;
    return QuestMe(
      registrationId: _text(json['registration_id']),
      points: jsonInt(json['points']) ?? 0,
      tasksDone: jsonInt(json['tasks_done']) ?? 0,
      requiredLeft: jsonInt(json['required_left']) ?? 0,
      next: QuestNext.fromJson(json['next']),
      rank: jsonInt(json['rank']),
      codeAttemptsLeft: jsonInt(json['code_attempts_left']),
    );
  }
}

/// A swag desk, where rewards are collected.
class QuestDesk {
  const QuestDesk({required this.id, required this.name});

  final String id;
  final String name;

  static List<QuestDesk> listFrom(Object? value) => [
        for (final json in jsonObjects(value))
          if (_text(json['name']) case final name?)
            QuestDesk(id: _text(json['door_id']) ?? name, name: name),
      ];
}

/// The addresses the server knows for the tasks' buttons.
class QuestLinks {
  const QuestLinks({this.liveRoom, this.feedback, this.poster, this.club});

  final String? liveRoom;

  /// The guest's own survey link, while the survey is open.
  final String? feedback;

  /// The guest's poster page.
  final String? poster;

  /// The host club's page.
  final String? club;

  static QuestLinks fromJson(Object? value) {
    final json = jsonObject(value) ?? const {};
    return QuestLinks(
      liveRoom: _text(json['live_room']),
      feedback: _text(json['feedback']),
      poster: _text(json['poster']),
      club: _text(json['club']),
    );
  }
}

/// A reward the guest has unlocked, with the milestone it came with.
typedef UnlockedReward = ({QuestMilestone milestone, QuestReward reward});

/// The card (`GET /events/{id}/quest`).
class Quest {
  const Quest({
    required this.eventId,
    this.enabled = false,
    this.id,
    this.title,
    this.intro,
    this.mode = QuestMode.checkmarks,
    this.startsAt,
    this.endsAt,
    this.open = true,
    this.leaderboard = false,
    this.tasks = const [],
    this.milestones = const [],
    this.me,
    this.collectAt = const [],
    this.links = const QuestLinks(),
  });

  final int eventId;

  /// False when the event has no quest, or it is switched off: then
  /// nothing about it shows anywhere.
  final bool enabled;
  final String? id;
  final String? title;
  final String? intro;
  final QuestMode mode;
  final DateTime? startsAt;
  final DateTime? endsAt;

  /// Inside the quest's window now, by the server's clock.
  final bool open;
  final bool leaderboard;
  final List<QuestTask> tasks;
  final List<QuestMilestone> milestones;

  /// Null when the viewer is not signed in or not registered: the overview
  /// only.
  final QuestMe? me;
  final List<QuestDesk> collectAt;
  final QuestLinks links;

  static const off = Quest(eventId: 0);

  bool get takingPart => me != null;

  /// The card's title: the organiser's, or "Quest".
  String get name => title ?? 'Quest';

  /// What the milestones count: tasks done, or points.
  int get score =>
      mode == QuestMode.points ? (me?.points ?? 0) : (me?.tasksDone ?? 0);

  /// "3 tasks" / "1 task" / "40 points".
  String units(int n) => mode == QuestMode.points
      ? (n == 1 ? '1 point' : '$n points')
      : (n == 1 ? '1 task' : '$n tasks');

  /// How far it is to the next milestone, 0 to 1; 1 once all are reached.
  double get progressToNext {
    final next = me?.next;
    if (next == null) return milestones.isEmpty ? 0 : 1;
    // From the milestone below it, so a second tier starts at nothing
    // rather than half full.
    final below = milestones
        .where((m) => m.threshold < next.threshold)
        .fold<int>(0, (top, m) => m.threshold > top ? m.threshold : top);
    final span = next.threshold - below;
    if (span <= 0) return 1;
    final done = (next.threshold - next.left) - below;
    return (done / span).clamp(0, 1).toDouble();
  }

  /// The line under the bar: what is left to the next milestone.
  String? get nextLine {
    final mine = me;
    if (mine == null) return null;
    final next = mine.next;
    if (next == null) {
      return milestones.any((m) => m.unlocked)
          ? 'Every reward unlocked. Well done!'
          : null;
    }
    if (next.left <= 0 && mine.requiredLeft > 0) {
      return mine.requiredLeft == 1
          ? 'Finish the required task to unlock ${next.title}'
          : 'Finish the ${mine.requiredLeft} required tasks to unlock '
              '${next.title}';
    }
    final n = next.left;
    final more = mode == QuestMode.points
        ? (n == 1 ? '1 more point' : '$n more points')
        : (n == 1 ? '1 more task' : '$n more tasks');
    return '$more to unlock ${next.title}';
  }

  /// The rewards the guest has, newest milestone last: those of the
  /// milestones unlocked, and any already handed over (kept, even if the
  /// milestone was later withdrawn).
  List<UnlockedReward> get unlockedRewards => [
        for (final m in milestones)
          for (final r in m.shownRewards)
            if (r.claim != null &&
                (m.unlocked || r.claim!.status == QuestClaimStatus.collected))
              (milestone: m, reward: r),
      ];

  /// Where rewards are collected: "the Swag desk", "Swag desk or Hall B";
  /// "the swag desk" when the event names none yet.
  String get deskLine {
    final names = [for (final d in collectAt) d.name];
    if (names.isEmpty) return 'the swag desk';
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} or '
        '${names.last}';
  }

  /// The task for meeting people, if the quest has one.
  QuestTask? get networkTask => tasks.where((t) => t.isNetwork).firstOrNull;

  /// The quest takes codes the guest has still to enter.
  bool get takesCodes =>
      tasks.any((t) => t.action == QuestAction.code && !t.done);

  int get doneCount => tasks.where((t) => t.done).length;

  Set<String> get unlockedIds => {
        for (final m in milestones)
          if (m.unlocked) m.id,
      };

  /// The card with [claim] in place of the claim of the same id.
  Quest withClaim(QuestClaim claim) => copyWith(milestones: [
        for (final m in milestones)
          QuestMilestone(
            id: m.id,
            title: m.title,
            threshold: m.threshold,
            unlocked: m.unlocked,
            unlockedAt: m.unlockedAt,
            rewards: [
              for (final r in m.rewards)
                r.claim?.id == claim.id ? r.withClaim(claim) : r,
            ],
          ),
      ]);

  Quest copyWith({List<QuestMilestone>? milestones}) => Quest(
        eventId: eventId,
        enabled: enabled,
        id: id,
        title: title,
        intro: intro,
        mode: mode,
        startsAt: startsAt,
        endsAt: endsAt,
        open: open,
        leaderboard: leaderboard,
        tasks: tasks,
        milestones: milestones ?? this.milestones,
        me: me,
        collectAt: collectAt,
        links: links,
      );

  static Quest fromJson(Object? value, {required int eventId}) {
    final json = jsonObject(value);
    if (json == null || jsonBool(json['enabled']) != true) {
      return Quest(eventId: eventId);
    }
    return Quest(
      eventId: eventId,
      enabled: true,
      id: _text(json['id']),
      title: _text(json['title']),
      intro: _text(json['intro']),
      mode: questModeFrom(json['mode']),
      startsAt: jsonDate(json['starts_at']),
      endsAt: jsonDate(json['ends_at']),
      open: jsonBool(json['open']) ?? true,
      leaderboard: jsonBool(json['leaderboard']) ?? false,
      tasks: QuestTask.listFrom(json['tasks']),
      milestones: [
        for (final m in jsonObjects(json['milestones']))
          if (QuestMilestone.fromJson(m) case final milestone?) milestone,
      ],
      me: QuestMe.fromJson(json['me']),
      collectAt: QuestDesk.listFrom(json['collect_at']),
      links: QuestLinks.fromJson(json['links']),
    );
  }
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// [at] as the card says it: "3:00 PM" today, else "28 Nov, 3:00 PM".
String questWhen(DateTime at, DateTime now) {
  final t = at.toLocal();
  final n = now.toLocal();
  final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final time =
      '$hour:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  final today = t.year == n.year && t.month == n.month && t.day == n.day;
  return today ? time : '${t.day} ${_months[t.month - 1]}, $time';
}

/// One row of the leaderboard.
class QuestRank {
  const QuestRank({
    required this.rank,
    required this.name,
    required this.score,
    this.me = false,
  });

  final int rank;
  final String name;
  final int score;
  final bool me;
}

class QuestLeaderboard {
  const QuestLeaderboard({
    this.mode = QuestMode.points,
    this.rows = const [],
    this.myRank,
    this.myScore,
  });

  final QuestMode mode;
  final List<QuestRank> rows;
  final int? myRank;
  final int? myScore;

  /// The viewer is not among [rows] but has a place.
  bool get meBelow => myRank != null && !rows.any((r) => r.me);

  static QuestLeaderboard fromJson(Object? value) {
    final json = jsonObject(value) ?? const {};
    final me = jsonObject(json['me']);
    return QuestLeaderboard(
      mode: questModeFrom(json['mode']),
      rows: [
        for (final row in jsonObjects(json['rows']))
          QuestRank(
            rank: jsonInt(row['rank']) ?? 0,
            name: _text(row['name']) ?? 'Someone',
            score: jsonInt(row['score']) ?? 0,
            me: jsonBool(row['me']) ?? false,
          ),
      ],
      myRank: jsonInt(me?['rank']),
      myScore: jsonInt(me?['score']),
    );
  }
}
