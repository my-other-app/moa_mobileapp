import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/common/models/events/event_model.dart';
import 'package:finnet/core/network/network_status.dart';
import 'package:finnet/features/events/presentation/widgets/question_fields.dart';
import 'package:finnet/features/events/presentation/widgets/revealed_question.dart';
import 'package:finnet/features/volunteer/data/gate_api.dart';
import 'package:finnet/features/volunteer/data/gate_models.dart';
import 'package:finnet/features/volunteer/domain/door_answers.dart';

/// The sign-up answers a guest is missing, filled in at the door with them
/// (`POST /gate/answers/{reg}`, missing-answers-contract.md §2.5) -- as the
/// club dashboard's door console does. The same fields as the registration
/// form; the types are checked, "required" is not, and it never holds up a
/// check-in.
///
/// It needs a connection: unlike a scan, answers are not saved on the phone
/// to send later, and with no signal the sheet says so.
class DoorAnswers extends ConsumerStatefulWidget {
  const DoorAnswers({
    super.key,
    required this.eventId,
    required this.guest,
    required this.form,
    this.onSaved,
  });

  static const saveKey = ValueKey('door-answers-save');
  static const offlineKey = ValueKey('door-answers-offline');
  static const doneKey = ValueKey('door-answers-done');

  static const offlineNote = "No signal: answers can't be saved offline. "
      'Check them in now and add these when you are back online.';

  final int eventId;
  final GateAttendee guest;

  /// The event's sign-up questions (the console's `guest_fields`).
  final List<AdditionalDetail> form;

  /// What is still missing once the server took the answers.
  final ValueChanged<List<MissingAnswer>>? onSaved;

  @override
  ConsumerState<DoorAnswers> createState() => _DoorAnswersState();
}

class _DoorAnswersState extends ConsumerState<DoorAnswers> {
  final _formKey = GlobalKey<FormState>();
  late List<MissingAnswer> _missing = widget.guest.missingAnswers;
  late QuestionAnswers _fields = _fieldsFor(_missing);
  bool _saving = false;

  /// A fresh set of fields for [missing].
  QuestionAnswers _fieldsFor(List<MissingAnswer> missing) => QuestionAnswers()
    ..setQuestions(doorQuestions(widget.form, missing))
    ..addListener(_changed);

  void _drop(QuestionAnswers fields) => fields
    ..removeListener(_changed)
    ..dispose();

  @override
  void dispose() {
    _drop(_fields);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _say(String text) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final answers = _fields.collect();
    if (answers.isEmpty) {
      _say('Fill in at least one of them.');
      return;
    }
    if (ref.read(networkStatusProvider).isOffline) {
      _say(DoorAnswers.offlineNote);
      return;
    }
    setState(() => _saving = true);
    try {
      final still = await ref
          .read(gateApiProvider)
          .saveAnswers(widget.eventId, widget.guest.id, answers);
      if (!mounted) return;
      widget.onSaved?.call(still);
      _say(still.isEmpty
          ? 'Saved. Nothing is missing now.'
          : 'Saved. Still missing: ${missingLabels(still)}.');
      final old = _fields;
      setState(() {
        _missing = still;
        _fields = _fieldsFor(still);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _drop(old));
    } catch (e) {
      if (!mounted) return;
      final refused = _fieldErrors(e);
      if (refused != null) {
        _fields.showErrors(refused);
      } else {
        _say(gateErrorMessage(e, "The answers weren't saved. Try again."));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// What the server said is wrong with each answer, by key (a type check,
  /// 422 `errors`), or null.
  Map<String, String>? _fieldErrors(Object error) {
    final keys = {for (final q in _fields.questions) q.key};
    final said = gateFieldErrors(error) ?? const <String, dynamic>{};
    final found = <String, String>{
      for (final entry in said.entries)
        if (keys.contains(entry.key) &&
            entry.value is String &&
            (entry.value as String).trim().isNotEmpty)
          entry.key: (entry.value as String).trim(),
    };
    return found.isEmpty ? null : found;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guest;
    final network = ref.watch(networkStatusProvider);
    final shown = _fields.shownKeys;
    final roots = {for (final m in _missing) m.key};
    // Every field built: a form validates only the fields it has built.
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(g.name.isEmpty ? g.ticketId : g.name,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            Text(g.ticketId, style: const TextStyle(color: Color(0xFF6B7280))),
            const SizedBox(height: 12),
            if (_missing.isEmpty)
              const Padding(
                key: DoorAnswers.doneKey,
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nothing is missing. All their sign-up details are in.',
                  style: TextStyle(
                      color: Color(0xFF15803D), fontWeight: FontWeight.w700),
                ),
              )
            else ...[
              Text(
                '${missingCount(_missing.length)}. Ask them, and fill in '
                'what they tell you. None of it stops their check-in.',
                style: const TextStyle(color: Color(0xFF4B5563)),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: network.offline,
                builder: (_, offline, __) => offline
                    ? Container(
                        key: DoorAnswers.offlineKey,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7E0),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          DoorAnswers.offlineNote,
                          style:
                              TextStyle(color: Color(0xFF6B4E00), fontSize: 13),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              for (final detail in _fields.questions)
                if (shown.contains(detail.key))
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: roots.contains(detail.key)
                        ? QuestionField(detail: detail, answers: _fields)
                        : RevealedQuestion(
                            child: QuestionField(
                                detail: detail, answers: _fields)),
                  ),
              const SizedBox(height: 24),
              ValueListenableBuilder<bool>(
                valueListenable: network.offline,
                builder: (_, offline, __) => FilledButton(
                  key: DoorAnswers.saveKey,
                  onPressed: _saving || offline ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2C333D),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_saving ? 'Saving…' : 'Save answers'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
