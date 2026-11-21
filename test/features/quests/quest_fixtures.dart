/// The quest card's answers, as the contract shapes them (feature-register
/// `quests/CONTRACT.md` §8.1).
library;

Map<String, dynamic> taskJson(
  String id, {
  required String kind,
  required String title,
  String? action,
  int points = 10,
  int target = 1,
  bool required = false,
  String? description,
  String? startsAt,
  String? endsAt,
  Map<String, dynamic>? station,
  int count = 0,
  bool done = false,
  String? source,
  String? doneAt = '2026-11-28T04:00:00Z',
  bool me = true,
}) =>
    {
      'id': id,
      'kind': kind,
      'title': title,
      'description': description,
      'points': points,
      'required': required,
      'starts_at': startsAt,
      'ends_at': endsAt,
      'target': target,
      'action': action,
      'station': station,
      'me': me
          ? {
              'count': count,
              'done': done,
              'done_at': done ? doneAt : null,
              'source': source,
            }
          : null,
    };

Map<String, dynamic> claimJson({
  String id = 'c-1',
  String status = 'reserved',
  bool needsSize = false,
  String? variant,
  List<Map<String, dynamic>> choices = const [],
  int? waitlistPosition,
  String? collectedAt,
  String? door,
  String? collectedBy,
  String? name,
}) =>
    {
      'claim_id': id,
      'status': status,
      'needs_size': needsSize,
      'variant_label': variant,
      'choices': choices,
      'waitlist_position': waitlistPosition,
      'collected_at': collectedAt,
      'door': door,
      // The swag desk's rows (and a paused card's) also say who and what.
      if (collectedBy != null) 'collected_by': collectedBy,
      if (name != null) 'name': name,
    };

/// The card of a quest switched off while [rewards] are still kept for the
/// guest (contract v1.3 §8.1 `paused`).
Map<String, dynamic> pausedJson(
  List<Map<String, dynamic>> rewards, {
  String title = 'DevFest Quest',
  List<Map<String, dynamic>> collectAt = const [
    {'door_id': 'd-9', 'name': 'Swag desk'},
  ],
}) =>
    {
      'enabled': false,
      'paused': {
        'title': title,
        'rewards': rewards,
        'collect_at': collectAt,
      },
    };

/// DevFest's quest: points, a tier at 30 (a T-shirt) and one at 60 (a
/// sticker); the guest has 20 points from checking in and a code.
Map<String, dynamic> questJson({
  bool enabled = true,
  String mode = 'points',
  bool open = true,
  bool leaderboard = false,
  bool me = true,
  int networkCount = 2,
  bool networkDone = false,
  int points = 20,
  int tasksDone = 2,
  int requiredLeft = 0,
  Map<String, dynamic>? next = const {
    'milestone_id': 'm-1',
    'title': 'Tier 1',
    'threshold': 30,
    'left': 10,
  },
  bool tier1Unlocked = false,
  Map<String, dynamic>? tier1Claim,
  String? feedback,
  String? poster = 'https://myotherapp.in/posters/MOA-1?s=k',
  List<Map<String, dynamic>>? tasks,
  List<Map<String, dynamic>> collectAt = const [
    {'door_id': 'd-9', 'name': 'Swag desk'},
  ],
  String? startsAt,
  String? endsAt,
}) {
  if (!enabled) return {'enabled': false};
  return {
    'enabled': true,
    'id': 'q-1',
    'title': 'DevFest Quest',
    'intro': 'Do the tasks, win a T-shirt.',
    'mode': mode,
    'starts_at': startsAt,
    'ends_at': endsAt,
    'open': open,
    'leaderboard': leaderboard,
    'tasks': tasks ??
        [
          taskJson('t-in',
              kind: 'checked_in',
              title: 'Check in',
              action: 'ticket',
              done: true,
              me: me),
          taskJson('t-net',
              kind: 'network',
              title: 'Meet 5 people',
              action: 'network_scan',
              target: 5,
              count: networkCount,
              done: networkDone,
              description: 'Scan their QR in Network.',
              me: me),
          taskJson('t-quiz',
              kind: 'quiz_played',
              title: 'Play the quiz',
              action: 'live_room',
              me: me),
          taskJson('t-code',
              kind: 'code',
              title: 'Find the keynote code',
              action: 'code',
              done: true,
              me: me),
          taskJson('t-booth',
              kind: 'station',
              title: 'Visit the Google Cloud booth',
              action: 'station',
              station: {'door_id': 'd-2', 'name': 'Google Cloud booth'},
              me: me),
          taskJson('t-code2',
              kind: 'code', title: 'The closing code', action: 'code', me: me),
          taskJson('t-feedback',
              kind: 'feedback',
              title: 'Give feedback',
              action: 'feedback',
              me: me),
        ],
    'milestones': [
      {
        'id': 'm-1',
        'title': 'Tier 1',
        'threshold': 30,
        'unlocked': tier1Unlocked,
        'unlocked_at': tier1Unlocked ? '2026-11-28T05:00:00Z' : null,
        'rewards': [
          {
            'reward_id': 'r-shirt',
            'name': 'DevFest T-shirt',
            'photo_url': null,
            'sizes': true,
            'sold_out': false,
            'claim':
                tier1Unlocked ? (tier1Claim ?? claimJson(variant: 'M')) : null,
          },
        ],
      },
      {
        'id': 'm-2',
        'title': 'Tier 2',
        'threshold': 60,
        'unlocked': false,
        'unlocked_at': null,
        'rewards': [
          {
            'reward_id': 'r-sticker',
            'name': 'Sticker pack',
            'photo_url': null,
            'sizes': false,
            'sold_out': true,
            'claim': null,
          },
        ],
      },
    ],
    'me': me
        ? {
            'registration_id': 'reg-1',
            'points': points,
            'tasks_done': tasksDone,
            'required_left': requiredLeft,
            'next': next,
            'rank': leaderboard ? 14 : null,
            'code_attempts_left': 10,
          }
        : null,
    'collect_at': collectAt,
    'links': {
      'live_room': 'https://myotherapp.in/events/devfest-2026/live',
      'feedback': feedback,
      'poster': poster,
      'club': 'https://myotherapp.in/clubs/gdg-kochi',
    },
  };
}
