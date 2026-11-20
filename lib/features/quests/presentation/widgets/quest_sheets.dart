import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/quests/data/quest_api.dart';
import 'package:finnet/features/quests/domain/quest.dart';
import 'package:finnet/features/quests/presentation/providers/quest_provider.dart';

/// The fewest letters a quest's code has (the server's rule): anything
/// shorter can't be one, and isn't sent -- wrong tries are counted.
const questCodeMinLength = 3;

/// [code] as the server matches it: no spaces, any case.
String questCodeKey(String code) =>
    code.replaceAll(RegExp(r'\s+'), '').toLowerCase();

/// What to say for a code that did not tick anything; null for one that
/// did.
String? codeOutcomeMessage(CodeOutcome outcome, {DateTime? now}) {
  final at = now ?? DateTime.now();
  switch (outcome) {
    case CodeDone():
    case CodeAlreadyDone():
      return null;
    case CodeWrong(:final left):
      if (left == null) return "That's not one of this quest's codes.";
      if (left <= 0) {
        return "That's not one of this quest's codes, and that was the "
            'last try for now. Try again in an hour.';
      }
      return "That's not one of this quest's codes. "
          '${left == 1 ? '1 try' : '$left tries'} left this hour.';
    case CodeNotOpen(:final opensAt, :final closesAt):
      if (opensAt != null && opensAt.isAfter(at)) {
        return 'Right code, but it opens at ${questWhen(opensAt, at)}.';
      }
      if (closesAt != null && !closesAt.isAfter(at)) {
        return 'Right code, but it closed at ${questWhen(closesAt, at)}.';
      }
      return "Right code, but it isn't open just now.";
    case CodeLocked(:final retryAfter):
      final minutes = retryAfter == null
          ? null
          : (retryAfter.inSeconds / 60).ceil().clamp(1, 60);
      return minutes == null
          ? 'Too many tries. Wait a little, then try again.'
          : 'Too many tries. Try again in '
              '${minutes == 1 ? 'a minute' : '$minutes minutes'}.';
    case CodeQuestClosed():
      return "The quest isn't open just now.";
    case CodeNotRegistered():
      return 'Codes count for guests with a ticket to this event.';
    case CodeTaskRevoked():
      return 'The organisers took that task back, so the code no longer '
          'counts for you. Ask them if that looks wrong.';
    case CodeNoSignal():
      return 'No signal. Codes need the internet: try again once you are '
          'back online.';
    case CodeFailed(:final message):
      return message;
  }
}

/// The code box: type a code from the stage or the venue. Answers what the
/// code ticked when it ticked something, else null.
Future<CodeOutcome?> showQuestCodeSheet(BuildContext context, int eventId) {
  return showModalBottomSheet<CodeOutcome>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => QuestCodeSheet(eventId: eventId),
  );
}

class QuestCodeSheet extends ConsumerStatefulWidget {
  const QuestCodeSheet({super.key, required this.eventId});

  final int eventId;

  static const fieldKey = ValueKey('quest-code-field');
  static const sendKey = ValueKey('quest-code-send');
  static const errorKey = ValueKey('quest-code-error');

  @override
  ConsumerState<QuestCodeSheet> createState() => _QuestCodeSheetState();
}

class _QuestCodeSheetState extends ConsumerState<QuestCodeSheet> {
  final _text = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final code = _text.text.trim();
    if (questCodeKey(code).length < questCodeMinLength) {
      setState(() => _error = 'Codes are at least $questCodeMinLength '
          'letters or numbers.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final outcome =
        await ref.read(questProvider(widget.eventId).notifier).enterCode(code);
    if (!mounted) return;
    final message = codeOutcomeMessage(outcome);
    if (message == null) {
      Navigator.of(context).pop(outcome);
      return;
    }
    setState(() {
      _sending = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Enter a code',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Codes are shown on stage, on the slides or around the venue.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          TextField(
            key: QuestCodeSheet.fieldKey,
            controller: _text,
            autofocus: true,
            enabled: !_sending,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 40,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            decoration: InputDecoration(
              hintText: 'e.g. CLOUD24',
              counterText: '',
              errorText: null,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                key: QuestCodeSheet.errorKey,
                style: const TextStyle(
                    fontSize: 13.5, color: Color(0xFFB91C1C), height: 1.3)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: QuestCodeSheet.sendKey,
            onPressed: _sending ? null : _send,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(48),
            ),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Check code'),
          ),
        ],
      ),
    );
  }
}

/// The sizes of a reward: pick one (or change it) while it is held.
Future<void> showQuestSizeSheet(
  BuildContext context, {
  required int eventId,
  required QuestReward reward,
  required QuestClaim claim,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) =>
        QuestSizeSheet(eventId: eventId, reward: reward, claim: claim),
  );
}

class QuestSizeSheet extends ConsumerStatefulWidget {
  const QuestSizeSheet({
    super.key,
    required this.eventId,
    required this.reward,
    required this.claim,
  });

  final int eventId;
  final QuestReward reward;
  final QuestClaim claim;

  static Key sizeKey(String label) => ValueKey('quest-size-$label');
  static const errorKey = ValueKey('quest-size-error');

  @override
  ConsumerState<QuestSizeSheet> createState() => _QuestSizeSheetState();
}

class _QuestSizeSheetState extends ConsumerState<QuestSizeSheet> {
  late List<QuestSizeChoice> _choices = widget.claim.choices;
  String? _saving;
  String? _error;

  Future<void> _pick(String label) async {
    if (_saving != null) return;
    setState(() {
      _saving = label;
      _error = null;
    });
    final outcome = await ref
        .read(questProvider(widget.eventId).notifier)
        .chooseSize(widget.claim, label);
    if (!mounted) return;
    if (outcome == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = null;
      _error = outcome.message;
      if (outcome.sizesLeft.isNotEmpty) _choices = outcome.sizesLeft;
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.claim.variantLabel;
    final choices = [
      for (final c in _choices)
        if ((c.free ?? 1) > 0 || c.label == current) c,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(current == null ? 'Pick your size' : 'Change your size',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            current == null
                ? '${widget.reward.name}: one is held for you in the size '
                    'you pick.'
                : '${widget.reward.name}: held for you in $current.',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          if (choices.isEmpty)
            const Text(
              'No sizes are left to pick from here. The swag desk can help.',
              style: TextStyle(fontSize: 14),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in choices)
                  ChoiceChip(
                    key: QuestSizeSheet.sizeKey(c.label),
                    label: _saving == c.label
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(c.label),
                    selected: c.label == current,
                    onSelected: c.label == current || _saving != null
                        ? null
                        : (_) => _pick(c.label),
                  ),
              ],
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                key: QuestSizeSheet.errorKey,
                style:
                    const TextStyle(fontSize: 13.5, color: Color(0xFFB91C1C))),
          ],
        ],
      ),
    );
  }
}
