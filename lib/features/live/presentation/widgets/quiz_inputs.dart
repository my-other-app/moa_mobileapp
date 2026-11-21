import 'dart:async';

import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/domain/live_theme.dart';
import 'package:finnet/features/live/presentation/widgets/live_order_list.dart';
import 'package:finnet/features/live/presentation/widgets/live_widgets.dart';
import 'package:flutter/material.dart';

/// What a phone shows for a question kind it cannot answer.
const quizNeedsUpdate =
    'This kind of question needs an update: update the app to answer it.';

// ─── An answer tile ─────────────────────────────────────────────────────

/// The measures of an answer tile: [roomy] one under the other, [tight]
/// two to a row (less padding, a smaller mark and tick, so a label keeps
/// as much of the tile as it can).
@immutable
class QuizTileMetrics {
  const QuizTileMetrics._({
    required this.padH,
    required this.padV,
    required this.mark,
    required this.markFont,
    required this.markGap,
    required this.icon,
    required this.iconGap,
    required this.fontSize,
    required this.minHeight,
  });

  static const roomy = QuizTileMetrics._(
    padH: 14,
    padV: 14,
    mark: 34,
    markFont: 18,
    markGap: 12,
    icon: 26,
    iconGap: 8,
    fontSize: 17.5,
    minHeight: 70,
  );

  static const tight = QuizTileMetrics._(
    padH: 10,
    padV: 12,
    mark: 28,
    markFont: 15,
    markGap: 8,
    icon: 22,
    iconGap: 6,
    fontSize: 16,
    minHeight: 64,
  );

  final double padH;
  final double padV;
  final double mark;
  final double markFont;
  final double markGap;
  final double icon;
  final double iconGap;
  final double fontSize;
  final double minHeight;

  /// The room a label has in a tile [width] wide: beside its mark (when
  /// [marked]) and the tick, kept for whenever a tick shows (picked, right,
  /// wrong), so a reveal never leaves a word too wide for its line.
  double labelWidth(double width, {required bool marked}) =>
      width - 2 * padH - (marked ? mark + markGap : 0) - (icon + iconGap);

  /// The label's style as the tile draws it: the theme's body text (what a
  /// tile's Material sets under it) in the tile's size and weight.
  TextStyle label(BuildContext context, Color ink) =>
      (Theme.of(context).textTheme.bodyMedium ?? const TextStyle()).merge(
          TextStyle(
              fontSize: fontSize,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: ink));
}

/// One answer of the question: its colour, its shape or letter (none in a
/// plain list), its label, and how it stands: picked, the right answer, a
/// wrong pick.
class QuizAnswerTile extends StatelessWidget {
  const QuizAnswerTile({
    super.key,
    required this.option,
    required this.index,
    required this.mine,
    required this.right,
    required this.wrong,
    required this.enabled,
    required this.onTap,
    this.checkbox = false,
    this.compact = false,
    this.rightLabel = 'the right answer',
  });

  final QuizOption option;

  /// Its place, A (0) to F: its colour and its mark.
  final int index;

  /// Picked on this phone.
  final bool mine;

  /// Shown as right, once the answer is out.
  final bool right;

  /// Picked, and not right.
  final bool wrong;
  final bool enabled;
  final VoidCallback onTap;

  /// One of several picks: a box to tick rather than a button.
  final bool checkbox;

  /// Two to a row: [QuizTileMetrics.tight].
  final bool compact;
  final String rightLabel;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    final m = compact ? QuizTileMetrics.tight : QuizTileMetrics.roomy;
    final plain = look.answerStyle == LiveAnswerStyle.plain;
    final fill = right
        ? LiveColors.right
        : wrong
            ? LiveColors.wrong
            : plain
                ? Colors.white
                : look.answerColour(index);
    final ink = right || wrong
        ? Colors.white
        : plain
            ? LiveColors.ink
            : look.onAnswer(index);
    final mark = look.mark(index);
    final label = [
      if (look.answerStyle == LiveAnswerStyle.letters)
        liveLetters[index % liveLetters.length],
      option.label,
      if (mine) checkbox ? 'picked' : 'your answer',
      if (right) rightLabel,
      if (wrong) 'wrong',
    ].join(', ');
    final dim = !enabled && !mine && !right;
    final IconData? trailing = right
        ? Icons.check_circle_rounded
        : wrong
            ? Icons.cancel_rounded
            : mine
                ? (checkbox ? Icons.check_box_rounded : Icons.check_circle)
                : checkbox && enabled
                    ? Icons.check_box_outline_blank_rounded
                    : null;
    // A tile's own edge: a themed colour can sit close to the card's white.
    final ShapeBorder? shape = plain || look.custom
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: plain
                  ? (mine ? look.accent : LiveColors.line)
                  : Color.lerp(fill, Colors.black, 0.18)!,
              width: plain && mine ? 2 : 1,
            ),
          )
        : null;
    return Semantics(
      button: !checkbox,
      checked: checkbox ? mine : null,
      enabled: enabled,
      selected: checkbox ? null : mine,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: dim ? 0.55 : 1,
        child: Material(
          color: fill,
          shape: shape,
          borderRadius: shape == null ? BorderRadius.circular(12) : null,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('answer-${option.key}'),
            onTap: enabled ? onTap : null,
            child: Container(
              constraints: BoxConstraints(minHeight: m.minHeight),
              padding:
                  EdgeInsets.symmetric(horizontal: m.padH, vertical: m.padV),
              // The picked ring is drawn over the tile, not inside its
              // padding: picking never narrows the label (or rewraps it).
              foregroundDecoration: mine && !plain
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: ink, width: 3),
                    )
                  : null,
              child: Row(
                children: [
                  if (mark != null) ...[
                    Container(
                      width: m.mark,
                      height: m.mark,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ink.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(m.mark * 0.26),
                      ),
                      child: Text(mark,
                          style: TextStyle(
                              fontSize: m.markFont,
                              fontWeight: look.answerStyle ==
                                      LiveAnswerStyle.letters
                                  ? FontWeight.w800
                                  : null,
                              color: ink)),
                    ),
                    SizedBox(width: m.markGap),
                  ],
                  Expanded(
                    child: Text(
                      option.label,
                      key: ValueKey('answer-label-${option.key}'),
                      style: m.label(context, ink),
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: EdgeInsets.only(left: m.iconGap),
                      child: Icon(trailing,
                          color: plain && !right && !wrong ? look.accent : ink,
                          size: m.icon),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Whether answers may go two to a row: the theme asks for a grid (or the
/// question is true or false) and the phone's text is not set large (past
/// 1.3 times, one under the other reads better). Whether the labels fit
/// two to a row is [quizGridFits], at the width the tiles get.
bool quizUsesGrid(BuildContext context, {required bool asked}) {
  if (!asked) return false;
  final media = MediaQuery.maybeOf(context);
  if (media == null) return true;
  final scale = media.textScaler.scale(16) / 16;
  return scale <= 1.3;
}

/// The gap between two tiles of a row.
const quizTileGap = 10.0;

/// Whether every one of [labels] fits a tile two to a row in [width]: its
/// longest run that may not break (a word, or one part of a hyphenated
/// word) fits the label's line beside the mark and the tick, measured in
/// the tile's own type at the phone's text size. A word is never split
/// inside: when one would be, the answers go one under the other.
bool quizGridFits(
  BuildContext context, {
  required List<String> labels,
  required double width,
  required bool marked,
}) {
  const m = QuizTileMetrics.tight;
  final room = m.labelWidth((width - quizTileGap) / 2, marked: marked);
  if (!room.isFinite || room <= 0) return false;
  final style = m.label(context, const Color(0xFF000000));
  final scaler = MediaQuery.maybeTextScalerOf(context) ?? TextScaler.noScaling;
  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  for (final label in labels) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: direction,
      textScaler: scaler,
    )..layout();
    // The widest piece that cannot wrap; a hair of margin for rounding.
    final widest = painter.minIntrinsicWidth;
    painter.dispose();
    if (widest > room - 0.5) return false;
  }
  return true;
}

/// The question's answers as tiles, one under the other or two to a row.
/// Two to a row only when [grid] asks for it and every label fits
/// ([quizGridFits]) at the width the tiles get; their rows are as tall as
/// their taller tile.
class QuizTiles extends StatelessWidget {
  const QuizTiles({
    super.key,
    required this.labels,
    required this.tile,
    required this.grid,
  });

  /// The answers' labels, in order: one tile each.
  final List<String> labels;
  final Widget Function(int i, bool compact) tile;
  final bool grid;

  int get count => labels.length;

  Widget _column() => Column(
        key: const ValueKey('quiz-tiles-column'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: tile(i, false),
            ),
        ],
      );

  Widget _grid() => Column(
        key: const ValueKey('quiz-tiles-grid'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < count; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tile(i, true)),
                    const SizedBox(width: quizTileGap),
                    Expanded(
                        child: i + 1 < count
                            ? tile(i + 1, true)
                            : const SizedBox.shrink()),
                  ],
                ),
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (!grid || count < 2) return _column();
    final marked = LiveLook.of(context).mark(0) != null;
    return LayoutBuilder(
      builder: (context, constraints) => quizGridFits(context,
              labels: labels, width: constraints.maxWidth, marked: marked)
          ? _grid()
          : _column(),
    );
  }
}

// ─── The inputs, per kind ───────────────────────────────────────────────

/// Single answer, true or false, a poll question: one tap is the answer.
class QuizOneTapInput extends StatelessWidget {
  const QuizOneTapInput({
    super.key,
    required this.question,
    required this.revealed,
    required this.enabled,
    required this.onAnswer,
  });

  final QuizQuestion question;
  final bool revealed;
  final bool enabled;
  final ValueChanged<String> onAnswer;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final look = LiveLook.of(context);
    final grid = quizUsesGrid(context,
        asked: look.grid || q.kind == QuizKind.trueFalse);
    final rights = q.rightKeys;
    final show = revealed || q.correctKey != null;
    return QuizTiles(
      labels: [for (final o in q.options) o.label],
      grid: grid,
      tile: (i, compact) {
        final o = q.options[i];
        final mine = q.myAnswer == o.key;
        final right = show && rights.contains(o.key);
        return QuizAnswerTile(
          option: o,
          index: i,
          mine: mine,
          right: right,
          wrong: show && rights.isNotEmpty && mine && !right,
          enabled: enabled,
          compact: compact,
          onTap: () => onAnswer(o.key),
        );
      },
    );
  }
}

/// A multiple-answer question: tick every answer thought right, then lock
/// them in.
class QuizMultiInput extends StatefulWidget {
  const QuizMultiInput({
    super.key,
    required this.question,
    required this.revealed,
    required this.enabled,
    required this.onAnswer,
  });

  final QuizQuestion question;
  final bool revealed;
  final bool enabled;
  final ValueChanged<List<String>> onAnswer;

  @override
  State<QuizMultiInput> createState() => _QuizMultiInputState();
}

class _QuizMultiInputState extends State<QuizMultiInput> {
  final Set<String> _picks = {};

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final look = LiveLook.of(context);
    final grid = quizUsesGrid(context, asked: look.grid);
    final sent = q.pickedKeys;
    final picks = q.answered ? sent : _picks;
    final rights = q.rightKeys;
    final show = widget.revealed && rights.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!q.answered && widget.enabled)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Pick every answer you think is right, then lock them in.',
                style: TextStyle(fontSize: 13.5, color: LiveColors.muted)),
          ),
        QuizTiles(
          labels: [for (final o in q.options) o.label],
          grid: grid,
          tile: (i, compact) {
            final o = q.options[i];
            final mine = picks.contains(o.key);
            final right = show && rights.contains(o.key);
            return QuizAnswerTile(
              option: o,
              index: i,
              mine: mine,
              right: right,
              wrong: show && mine && !right,
              checkbox: true,
              compact: compact,
              rightLabel: 'a right answer',
              enabled: widget.enabled,
              onTap: () => setState(() {
                if (!_picks.remove(o.key)) _picks.add(o.key);
              }),
            );
          },
        ),
        if (!q.answered && widget.enabled)
          FilledButton(
            key: const ValueKey('quiz-lock-in'),
            onPressed: _picks.isEmpty
                ? null
                : () => widget.onAnswer([
                      for (final o in q.options)
                        if (_picks.contains(o.key)) o.key,
                    ]),
            style: liveButtonStyle(look,
                minimumSize: const Size.fromHeight(56),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            child: Text(_picks.isEmpty
                ? 'Pick at least one'
                : _picks.length == 1
                    ? 'Lock in 1 answer'
                    : 'Lock in ${_picks.length} answers'),
          ),
      ],
    );
  }
}

/// Type the answer.
class QuizTypeInput extends StatefulWidget {
  const QuizTypeInput({
    super.key,
    required this.question,
    required this.enabled,
    required this.onAnswer,
  });

  final QuizQuestion question;
  final bool enabled;
  final ValueChanged<String> onAnswer;

  @override
  State<QuizTypeInput> createState() => _QuizTypeInputState();
}

class _QuizTypeInputState extends State<QuizTypeInput> {
  final _text = TextEditingController();

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty || !widget.enabled) return;
    widget.onAnswer(t);
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final look = LiveLook.of(context);
    final sent = q.sent is TextAnswer ? (q.sent as TextAnswer).text : null;
    if (q.answered && sent != null) {
      return Semantics(
        container: true,
        label: 'Your answer: $sent',
        excludeSemantics: true,
        child: Container(
          key: const ValueKey('quiz-typed'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: look.accent, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: look.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(sent,
                    style: const TextStyle(
                        fontSize: 17.5,
                        fontWeight: FontWeight.w700,
                        color: LiveColors.ink)),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('quiz-type'),
          controller: _text,
          enabled: widget.enabled,
          maxLength: quizTextMax,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.send,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (_) => _send(),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Your answer',
            helperText: 'Spelling close enough may still count.',
          ),
        ),
        const SizedBox(height: 4),
        ListenableBuilder(
          listenable: _text,
          builder: (context, _) => FilledButton(
            key: const ValueKey('quiz-lock-in'),
            onPressed: widget.enabled && _text.text.trim().isNotEmpty
                ? _send
                : null,
            style: liveButtonStyle(look,
                minimumSize: const Size.fromHeight(56),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            child: const Text('Lock in my answer'),
          ),
        ),
      ],
    );
  }
}

/// Put in order: drag the rows (or move them with the arrows), then lock
/// the order in. The rows start in the order the screen shows, which is
/// never the answer.
class QuizOrderInput extends StatefulWidget {
  const QuizOrderInput({
    super.key,
    required this.question,
    required this.revealed,
    required this.enabled,
    required this.onAnswer,
  });

  final QuizQuestion question;
  final bool revealed;
  final bool enabled;
  final ValueChanged<List<String>> onAnswer;

  @override
  State<QuizOrderInput> createState() => _QuizOrderInputState();
}

class _QuizOrderInputState extends State<QuizOrderInput> {
  late List<String> _order = [for (final o in widget.question.options) o.key];

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final look = LiveLook.of(context);
    final sent = q.sent is OrderAnswer ? (q.sent as OrderAnswer).keys : null;
    final order = sent ?? _order;
    final right = widget.revealed ? q.correctOrder : null;
    final marks = <String, bool>{
      if (right != null && sent != null)
        for (var i = 0; i < sent.length; i++)
          sent[i]: i < right.length && right[i] == sent[i],
    };
    final open = widget.enabled && !q.answered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (open)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Drag the handles, or use the arrows, to put them in order.',
                style: TextStyle(fontSize: 13.5, color: LiveColors.muted)),
          ),
        LiveOrderList(
          items: [
            for (final o in q.options) LiveOrderItem(id: o.key, label: o.label),
          ],
          order: order,
          enabled: open,
          marks: marks,
          onChanged: (next) => setState(() => _order = next),
        ),
        if (open)
          FilledButton(
            key: const ValueKey('quiz-lock-in'),
            onPressed: () => widget.onAnswer(_order),
            style: liveButtonStyle(look,
                minimumSize: const Size.fromHeight(56),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            child: const Text('Lock in this order'),
          ),
      ],
    );
  }
}

/// A poll question's tally, once the server sends it.
class QuizTally extends StatelessWidget {
  const QuizTally({super.key, required this.question});
  final QuizQuestion question;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    final counts = question.counts;
    final total = counts.fold<int>(0, (a, c) => a + c.count);
    return Semantics(
      container: true,
      label: 'The room said: '
          '${counts.map((c) => '${c.label.isEmpty ? question.labelOf(c.key) : c.label}, ${c.count}').join('; ')}',
      excludeSemantics: true,
      child: Column(
        children: [
          for (final c in counts)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                        c.label.isEmpty ? question.labelOf(c.key) : c.label,
                        style: const TextStyle(fontSize: 14)),
                  ),
                  Expanded(
                    flex: 3,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : c.count / total,
                        minHeight: 10,
                        backgroundColor: LiveColors.offTint,
                        valueColor: AlwaysStoppedAnimation(look.dot),
                      ),
                    ),
                  ),
                  SizedBox(
                      width: 36,
                      child: Text('${c.count}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── The clock, in the theme's style ────────────────────────────────────

/// The question's clock as the theme draws it: a ring (the room's own), a
/// bar, a big number, or nothing (the time still runs; the verdict still
/// says when it is up).
class QuizTimer extends StatelessWidget {
  const QuizTimer({
    super.key,
    required this.left,
    required this.seconds,
    this.paused = false,
  });

  final int left;
  final int seconds;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    switch (look.timer) {
      case LiveTimerStyle.hidden:
        return const SizedBox.shrink();
      case LiveTimerStyle.ring:
        return QuizClock(left: left, seconds: seconds);
      case LiveTimerStyle.number:
        return _NumberClock(left: left, paused: paused);
      case LiveTimerStyle.bar:
        return _BarClock(left: left, seconds: seconds, paused: paused);
    }
  }
}

Color _clockTone(BuildContext context, int left) => left <= 0
    ? LiveColors.wrong
    : left <= 5
        ? LiveColors.warn
        : LiveLook.of(context).accent;

class _NumberClock extends StatelessWidget {
  const _NumberClock({required this.left, required this.paused});
  final int left;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    final tone = _clockTone(context, left);
    return Semantics(
      label: paused
          ? 'Paused, $left seconds left'
          : left <= 0
              ? 'Time is up'
              : '$left seconds left',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64, minHeight: 58),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: tone, width: 2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          left <= 0 ? 'Time' : '$left',
          key: const ValueKey('quiz-clock'),
          style: look.display(TextStyle(
              fontSize: left <= 0 ? 16 : 30,
              fontWeight: FontWeight.w800,
              color: tone)),
        ),
      ),
    );
  }
}

class _BarClock extends StatelessWidget {
  const _BarClock(
      {required this.left, required this.seconds, required this.paused});
  final int left;
  final int seconds;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final tone = _clockTone(context, left);
    final span = seconds <= 0 ? 1 : seconds;
    final fraction = (left / span).clamp(0.0, 1.0);
    final still = liveStill(context);
    return Semantics(
      label: paused
          ? 'Paused, $left seconds left'
          : left <= 0
              ? 'Time is up'
              : '$left seconds left',
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(end: fraction),
                duration: Duration(milliseconds: still || paused ? 0 : 950),
                curve: Curves.linear,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  backgroundColor: LiveColors.offTint,
                  valueColor: AlwaysStoppedAnimation(tone),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 44,
            child: Text(
              left <= 0 ? 'Time' : '${left}s',
              key: const ValueKey('quiz-clock'),
              textAlign: TextAlign.right,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: tone),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Next question in 6 s": an auto-advancing round's next question, from
/// when the server says it opens.
class QuizNextIn extends StatefulWidget {
  const QuizNextIn({super.key, required this.at, this.now});
  final DateTime at;
  final DateTime Function()? now;

  @override
  State<QuizNextIn> createState() => _QuizNextInState();
}

class _QuizNextInState extends State<QuizNextIn> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left =
        widget.at.difference((widget.now ?? DateTime.now)()).inSeconds;
    final text = left > 0 && left <= 90
        ? 'Next question in $left s'
        : 'Next question in a moment';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.skip_next_rounded, size: 18, color: LiveColors.muted),
          const SizedBox(width: 4),
          Text(text,
              key: const ValueKey('quiz-next-in'),
              style: const TextStyle(fontSize: 13.5, color: LiveColors.muted)),
        ],
      ),
    );
  }
}

// ─── Teams ──────────────────────────────────────────────────────────────

Color? _teamColour(QuizTeam team) => liveHex(team.color);

/// "Red Rockets": the player's team, with its colour.
class QuizTeamChip extends StatelessWidget {
  const QuizTeamChip({super.key, required this.team, this.prefix = 'Team'});
  final QuizTeam team;
  final String prefix;

  /// What a screen reader says: "Team Red Rockets", but a name that already
  /// starts with "Team" (any case) as it is, never "Team Team Flutter".
  /// The website's `teamLabel` follows the same rule.
  static String spokenLabel(String prefix, String name) {
    final n = name.trim();
    if (prefix == 'Team' &&
        RegExp(r'^team(?![a-z])', caseSensitive: false).hasMatch(n)) {
      return n;
    }
    return '$prefix $n';
  }

  @override
  Widget build(BuildContext context) {
    final colour = _teamColour(team) ?? LiveColors.muted;
    return Semantics(
      container: true,
      label: spokenLabel(prefix, team.name),
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('quiz-team'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: colour, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(team.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: LiveColors.ink)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The teams' board: each team's place, colour, score and players, the
/// player's own team marked.
class QuizTeamBoard extends StatelessWidget {
  const QuizTeamBoard({super.key, required this.teams, this.mine});
  final List<TeamStanding> teams;
  final String? mine;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    return LiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LiveHeading('Teams'),
          for (final t in teams)
            Semantics(
              container: true,
              label: '${ordinal(t.rank)}, ${t.team.name}, ${t.score} points, '
                  '${t.players} ${t.players == 1 ? 'player' : 'players'}'
                  '${t.team.key == mine ? ', your team' : ''}',
              excludeSemantics: true,
              child: Container(
                key: ValueKey('team-${t.team.key}'),
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: t.team.key == mine ? look.liveCard : Colors.white,
                  border: Border.all(
                      color: t.team.key == mine ? look.accent : LiveColors.line,
                      width: t.team.key == mine ? 2 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text('${t.rank}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: _teamColour(t.team) ?? LiveColors.muted,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              t.team.key == mine
                                  ? '${t.team.name} · yours'
                                  : t.team.name,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                          Text(
                              '${t.players} ${t.players == 1 ? 'player' : 'players'}',
                              style: const TextStyle(
                                  fontSize: 12, color: LiveColors.muted)),
                        ],
                      ),
                    ),
                    LiveScore(t.score,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
