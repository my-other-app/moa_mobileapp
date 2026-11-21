/// The quest's addresses in the app and the pushes that open it. Pure Dart:
/// the router, the push table and the tests read it without Flutter.
library;

/// The guest's quest at an event: `/events/{ref}/quest` (the card in full,
/// with the code box and the leaderboard). What an unlock push opens.
String questLocation(Object eventRef) =>
    '/events/${Uri.encodeComponent('$eventRef')}/quest';

/// "🎁 You unlocked Tier 1" (`{type, event_id, milestone_id, open:
/// quest}`), and "Your T-shirt is waiting at the swag desk" once a unit is
/// held for a guest on the waiting list.
const questUnlockedType = 'quest_unlocked';
const questRewardHeldType = 'quest_reward_held';
const questTypes = {questUnlockedType, questRewardHeldType};

/// Where a quest push (or its line in the inbox) opens: the quest, for a
/// quest type or any push that says `open: quest`; null otherwise, or
/// without an event.
String? questPushRoute(String? type, int? eventId, Object? open) {
  if (eventId == null) return null;
  if (questTypes.contains(type) || open?.toString() == 'quest') {
    return questLocation(eventId);
  }
  return null;
}
