import 'package:finnet/common/models/events/event_model.dart';

// Which of an event's questions are shown, for the answers given so far:
// the one algorithm every repo runs (conditional-questions-contract.md §3).
//
//   visible(q) = q.show_if is null
//                OR ( visible(parent(q))
//                     AND matches(answer(parent(q)), q.show_if.any_of) )
//
// A parent always comes before its children (rule R1, refused by the server
// otherwise), so one pass in list order decides every question. A condition
// naming a question that isn't earlier in the list is never met: the
// question stays hidden rather than guessing.

/// Whether [answer], a parent question's answer, is one of [anyOf]: the
/// answer as text, compared exactly (no trimming, case counts). A list (a
/// checkbox's ticks -- one tick may also come as a plain string) matches
/// when any one of its values does. A blank answer never matches. The same
/// as `matches` in moa_web `packages/questions/src/visibility.ts`.
bool conditionMatches(Object? answer, List<String> anyOf) {
  if (_blank(answer)) return false;
  final picked = answer is List ? answer : [answer];
  return picked.any((value) => value != null && anyOf.contains('$value'));
}

/// Each question's visibility for [answers] (by question key), in one pass
/// in list order. A parent not seen yet -- missing, or after its child --
/// counts as hidden, so the child is too.
Map<String, bool> questionVisibility(
  List<AdditionalDetail> questions,
  Map<String, Object?> answers,
) {
  final seen = <String, bool>{};
  for (final question in questions) {
    final condition = question.showIf;
    seen[question.key] = condition == null ||
        (seen[condition.key] == true &&
            conditionMatches(answers[condition.key], condition.anyOf));
  }
  return seen;
}

/// The keys of the [questions] shown for [answers].
Set<String> visibleQuestionKeys(
  List<AdditionalDetail> questions,
  Map<String, Object?> answers,
) =>
    {
      for (final entry in questionVisibility(questions, answers).entries)
        if (entry.value) entry.key,
    };

/// The [questions] shown for [answers], in the form's order.
List<AdditionalDetail> visibleQuestions(
  List<AdditionalDetail> questions,
  Map<String, Object?> answers,
) {
  final shown = visibleQuestionKeys(questions, answers);
  return [
    for (final question in questions)
      if (shown.contains(question.key)) question,
  ];
}

/// [answers] without any answer to a question they hide: what is sent. An
/// answer to something the form doesn't ask is left as it is.
Map<String, V> withoutHiddenAnswers<V>(
  List<AdditionalDetail> questions,
  Map<String, V> answers,
) {
  final shown = questionVisibility(questions, answers);
  return {
    for (final entry in answers.entries)
      if (shown[entry.key] != false) entry.key: entry.value,
  };
}

/// Whether any question shown for [answers] must be answered and isn't.
/// With no answers at all, a conditional question is hidden, so for an
/// empty form this is "does the form ask anything required".
bool anyRequiredUnanswered(
  List<AdditionalDetail> questions,
  Map<String, Object?> answers,
) =>
    visibleQuestions(questions, answers)
        .any((q) => q.requiredIfShown && _blank(answers[q.key]));

bool _blank(Object? value) =>
    value == null ||
    (value is String && value.trim().isEmpty) ||
    (value is List && value.every(_blank));

/// What a screen reader says when an answer changes which questions are
/// shown: the questions that appeared, by name, and how many went. Null
/// when nothing changed.
String? visibilityChangeAnnouncement(
  List<AdditionalDetail> before,
  List<AdditionalDetail> after,
) {
  final had = {for (final q in before) q.key};
  final has = {for (final q in after) q.key};
  final added = [
    for (final q in after)
      if (!had.contains(q.key)) q.label.trim(),
  ];
  final removed = before.where((q) => !has.contains(q.key)).length;
  final parts = <String>[
    if (added.length == 1) 'New question: ${added.single}.',
    if (added.length > 1) '${added.length} new questions: ${added.join(', ')}.',
    if (removed == 1) '1 question removed.',
    if (removed > 1) '$removed questions removed.',
  ];
  return parts.isEmpty ? null : parts.join(' ');
}
