import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/features/events/domain/missing_answers.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';

/// The questions a volunteer fills in for a guest's [missing] answers, from
/// the event's form ([form], the console's `guest_fields`), in its order:
/// each missing question, and the follow-ups an answer to one brings.
///
/// The door is relaxed (missing-answers-contract.md §2.5): the types are
/// checked, "required" is not, so none is marked or held to it. A missing
/// question is always shown -- the server found it missing for this guest,
/// so it applies to them, though the door doesn't know the answers that
/// made it apply; its follow-ups show by what is chosen here. One the form
/// doesn't have (a console read before the club changed it) is a text box
/// with its label.
List<AdditionalDetail> doorQuestions(
  List<AdditionalDetail> form,
  List<MissingAnswer> missing,
) {
  final asked = {for (final m in missing) m.key};
  final shown = askedWithFollowUps(form, asked);
  final known = {for (final q in form) q.key};
  return [
    for (final q in form)
      if (shown.contains(q.key))
        AdditionalDetail(
          key: q.key,
          label: q.label,
          fieldType: q.fieldType,
          requiredField: false,
          requiredWhenShown: false,
          options: q.options,
          showIf: asked.contains(q.key) ? null : q.showIf,
        ),
    for (final m in missing)
      if (!known.contains(m.key))
        AdditionalDetail(
          key: m.key,
          label: m.label,
          fieldType: 'text',
          requiredField: false,
          options: const [],
        ),
  ];
}

/// "2 details missing", "1 detail missing".
String missingCount(int n) =>
    n == 1 ? '1 detail missing' : '$n details missing';
