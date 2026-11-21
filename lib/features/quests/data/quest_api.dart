import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/cache/api_cache.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/core/utils/json_read.dart';
import 'package:finnet/features/quests/domain/quest.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart' show gotNoAnswer;

final questApiProvider = Provider<QuestApi>((ref) => QuestApi());

/// A card as read: fresh from the server, or the copy kept on the phone
/// because there was no signal.
typedef QuestRead = ({Quest quest, bool offline});

/// The guest's side of an event's quest on the server (feature-register
/// `quests/CONTRACT.md` §8).
class QuestApi {
  QuestApi({APIService? api}) : _api = api;

  final APIService? _api;
  APIService get _client => _api ?? APIService.instance;

  static String _card(int eventId) => '/events/$eventId/quest';

  /// The copy of the card kept on the phone, or null. Disk only. It is the
  /// person's own progress, so it is kept encrypted and goes at sign-out.
  Future<Quest?> saved(int eventId) async {
    final data =
        await _client.savedCopy(_card(eventId), policy: CachePolicy.personal);
    return data == null ? null : Quest.fromJson(data, eventId: eventId);
  }

  /// `GET /events/{id}/quest`: the card, kept on the phone for the venue's
  /// dead spots. With no signal (or the server down), the kept copy
  /// (`offline: true`).
  ///
  /// Kept only for an event whose quest is on (or paused with a reward
  /// still held for the guest) -- not for every event page opened, whose
  /// "no quest here" would crowd the person's few kept answers (the
  /// events' own pages among them) for nothing. A quest switched off since
  /// replaces its copy, so it doesn't come back offline.
  Future<QuestRead> card(int eventId) async {
    final path = _card(eventId);
    try {
      final res = await _client.request(path, DioMethod.get);
      final quest = Quest.fromJson(res.data, eventId: eventId);
      final data = res.data;
      if (data != null && (quest.shows || await saved(eventId) != null)) {
        await ApiCache.instance.saveAnswer(_client.dio, path, data as Object,
            scope: CacheScope.personal);
      }
      return (quest: quest, offline: false);
    } catch (e) {
      final status = statusCodeOf(e);
      if (gotNoAnswer(e) || (status != null && status >= 500)) {
        final copy = await saved(eventId);
        if (copy != null) return (quest: copy, offline: true);
      }
      rethrow;
    }
  }

  /// `POST /events/{id}/quest/code`: a code from the stage or the venue.
  /// Never throws: every answer, refusal and failure is a [CodeOutcome].
  Future<CodeOutcome> enterCode(int eventId, String code) async {
    try {
      final res = await _client.request(
          '${_card(eventId)}/code', DioMethod.post,
          param: {'code': code});
      final json = jsonObject(res.data) ?? const {};
      final card = json['card'] == null
          ? null
          : Quest.fromJson(json['card'], eventId: eventId);
      final task = QuestTask.fromJson(json['task']);
      return jsonString(json['result'])?.toUpperCase() == 'ALREADY_DONE'
          ? CodeAlreadyDone(task: task, card: card)
          : CodeDone(task: task, card: card);
    } catch (e) {
      return codeRefusalOf(e);
    }
  }

  /// `POST /events/{id}/quest/claims/{claim}/size`: the guest's size for a
  /// reward with sizes.
  Future<QuestClaim> chooseSize(
      int eventId, String claimId, String label) async {
    final res = await _client.request(
        '${_card(eventId)}/claims/${Uri.encodeComponent(claimId)}/size',
        DioMethod.post,
        param: {'variant_label': label});
    final claim = QuestClaim.fromJson(res.data);
    if (claim == null) throw const FormatException('No claim in the answer');
    return claim;
  }

  /// `GET /events/{id}/quest/leaderboard`; null while it is off (404).
  Future<QuestLeaderboard?> leaderboard(int eventId, {int limit = 20}) async {
    try {
      final res = await _client.request(
          '${_card(eventId)}/leaderboard', DioMethod.get,
          param: {'limit': limit}, cache: CachePolicy.personal);
      return QuestLeaderboard.fromJson(res.data);
    } catch (e) {
      if (statusCodeOf(e) == 404) return null;
      rethrow;
    }
  }
}

/// How entering a code went.
sealed class CodeOutcome {
  const CodeOutcome();
}

/// Ticked now. [card] is the card as it is after it.
class CodeDone extends CodeOutcome {
  const CodeDone({this.task, this.card});
  final QuestTask? task;
  final Quest? card;
}

/// The right code, for a task already done.
class CodeAlreadyDone extends CodeOutcome {
  const CodeAlreadyDone({this.task, this.card});
  final QuestTask? task;
  final Quest? card;
}

/// Not a code of this quest. [left] wrong tries are left this hour.
class CodeWrong extends CodeOutcome {
  const CodeWrong({this.left});
  final int? left;
}

/// The right code at the wrong time.
class CodeNotOpen extends CodeOutcome {
  const CodeNotOpen({this.opensAt, this.closesAt});
  final DateTime? opensAt;
  final DateTime? closesAt;
}

/// Too many wrong codes this hour; [retryAfter] until the next try.
class CodeLocked extends CodeOutcome {
  const CodeLocked({this.retryAfter});
  final Duration? retryAfter;
}

/// The quest is off, or outside its window.
class CodeQuestClosed extends CodeOutcome {
  const CodeQuestClosed();
}

/// The account has no ticket to the event.
class CodeNotRegistered extends CodeOutcome {
  const CodeNotRegistered();
}

/// The right code, for a task the organisers took back from this guest.
class CodeTaskRevoked extends CodeOutcome {
  const CodeTaskRevoked();
}

/// No signal: a code is never kept to send later (tries are counted).
class CodeNoSignal extends CodeOutcome {
  const CodeNoSignal();
}

/// Anything else, in words to show.
class CodeFailed extends CodeOutcome {
  const CodeFailed(this.message);
  final String message;
}

/// What the server's refusal of a code (or no answer at all) means.
CodeOutcome codeRefusalOf(Object error) {
  if (gotNoAnswer(error)) return const CodeNoSignal();
  final api = apiExceptionOf(error);
  final errors = api?.errors ?? const <String, dynamic>{};
  switch (api?.errorCode) {
    case 'QUEST_CODE_WRONG':
      return CodeWrong(left: jsonInt(errors['left']));
    case 'QUEST_CODE_NOT_OPEN':
      return CodeNotOpen(
        opensAt: jsonDate(errors['opens_at']),
        closesAt: jsonDate(errors['closes_at']),
      );
    case 'QUEST_CODE_LOCKED':
      final seconds = jsonInt(errors['retry_after']);
      return CodeLocked(
          retryAfter: seconds == null ? null : Duration(seconds: seconds));
    case 'QUEST_CLOSED':
      return const CodeQuestClosed();
    case 'QUEST_NOT_REGISTERED':
      return const CodeNotRegistered();
    case 'QUEST_TASK_REVOKED':
      return const CodeTaskRevoked();
  }
  // The per-minute limit on every request, without the quest's own code.
  if (statusCodeOf(error) == 429) return const CodeLocked();
  return CodeFailed(extractErrorMessage(error,
      defaultMessage: "That didn't go through. Try again."));
}

/// The sizes still free, from a `QUEST_SIZE_GONE` refusal; empty otherwise.
List<QuestSizeChoice> sizesLeftIn(Object error) {
  final api = apiExceptionOf(error);
  if (api?.errorCode != 'QUEST_SIZE_GONE') return const [];
  return QuestSizeChoice.listFrom(api?.errors?['choices']);
}
