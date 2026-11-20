import 'dart:async';
import 'dart:math' as math;

import 'package:finnet/features/live/domain/live_room.dart';
import 'package:finnet/features/live/presentation/widgets/live_order_list.dart';
import 'package:finnet/features/live/presentation/widgets/live_widgets.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';

/// What a client shows for a poll kind it cannot answer (the server's own
/// words for old clients).
const pollNeedsUpdate =
    'This kind of poll needs an update: update the app to answer it.';

/// The poll that is up, in each of its kinds (CONTRACT 7): a choice (one,
/// or up to a number), a word or two, a rating (stars to 5, or 1 to 10), a
/// ranking, or an open-text answer; and the room's answers once this phone
/// has given one, drawn as the organiser chose (bars, columns or a donut;
/// percentages, counts or both), unless the results are kept from guests.
class PollCard extends StatefulWidget {
  const PollCard({
    super.key,
    required this.poll,
    required this.onAnswer,
    this.busy = false,
    this.error,
    this.closed = false,
    this.now,
  });

  final LivePoll poll;
  final Future<bool> Function(PollAnswer answer) onAnswer;
  final bool busy;
  final String? error;

  /// The room has closed: results only.
  final bool closed;

  /// The clock the poll's timer is read against (tests).
  final DateTime Function()? now;

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  final _word = TextEditingController();
  final _name = TextEditingController();

  /// A multiple choice's picks before they are sent.
  Set<String> _picks = {};

  /// A ranking's order before it is sent.
  List<String>? _order;
  Timer? _tick;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _startTick();
  }

  @override
  void didUpdateWidget(PollCard old) {
    super.didUpdateWidget(old);
    if (old.poll.closesAt != widget.poll.closesAt) _startTick();
  }

  void _startTick() {
    _tick?.cancel();
    _tick = null;
    if (widget.poll.closesAt == null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_left == Duration.zero) {
        _tick?.cancel();
        _tick = null;
      }
    });
  }

  Duration? get _left {
    final at = widget.poll.closesAt;
    if (at == null) return null;
    final left = at.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void dispose() {
    _tick?.cancel();
    _word.dispose();
    _name.dispose();
    super.dispose();
  }

  bool get _timeUp => _left == Duration.zero;

  /// Whether an answer can be given (or changed) now.
  bool get _canAnswer {
    final poll = widget.poll;
    if (widget.busy || widget.closed || !poll.isOpen || _timeUp) return false;
    if (!poll.isKnown) return false;
    return !(poll.answered && !poll.settings.changeVote);
  }

  bool get _showResults {
    final poll = widget.poll;
    return (poll.answered || widget.closed || !poll.isOpen) &&
        !poll.resultsHidden;
  }

  Future<void> _sendWord() async {
    final value = _word.text.trim();
    final poll = widget.poll;
    if (poll.isText ? value.isEmpty : value.length < 2) return;
    final sent = await widget.onAnswer(PollAnswer(
      value: value,
      name: poll.isText && !poll.settings.anonymous ? _name.text : null,
    ));
    if (sent && mounted) _word.clear();
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final count = poll.responses;
    final left = _left;
    return LiveCard(
      live: !widget.closed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LiveDot('Poll', beat: !widget.closed),
          const SizedBox(height: 8),
          LiveHeading(poll.prompt, size: 20),
          LiveSub('$count ${count == 1 ? 'answer' : 'answers'} so far'
              '${poll.answered ? ' · you answered' : ''}'),
          if (left != null && poll.isOpen && !widget.closed)
            _Countdown(left: left),
          if (poll.answered) _Voted(poll: poll),
          const SizedBox(height: 12),
          if (!poll.isKnown)
            const Text(pollNeedsUpdate,
                key: ValueKey('poll-needs-update'),
                style: TextStyle(fontSize: 14, color: LiveColors.muted))
          else if (poll.isMultiple)
            ..._multiple(poll)
          else if (poll.isChoice)
            ..._choices(poll)
          else if (poll.isWords)
            ..._words(poll)
          else if (poll.isRating)
            ..._rating(poll)
          else if (poll.isRanking)
            ..._ranking(poll)
          else if (poll.isText)
            ..._text(poll),
          if (poll.answered && !poll.settings.changeVote && poll.isOpen)
            const _Note('Your answer is in. This poll takes one answer.'),
          if (poll.resultsHidden && poll.isKnown)
            _Note(poll.settings.hideResults
                ? 'The results are on the big screen.'
                : 'The results show when the poll closes.'),
          if (widget.error != null) LiveErrorLine(widget.error!),
        ],
      ),
    );
  }

  // ─── Choice ───────────────────────────────────────────────────────────

  /// Bars in the buttons themselves (`bar`), or the buttons and a chart
  /// under them (`column`, `donut`).
  bool get _barsInButtons {
    final chart = widget.poll.settings.chart;
    return chart != 'column' && chart != 'donut';
  }

  List<Widget> _choices(LivePoll poll) {
    final results = _showResults;
    final choices = poll.choicesToShow;
    return [
      for (var i = 0; i < choices.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChoiceButton(
            choice: choices[i],
            image: poll.imageOf(_optionIndex(poll, choices[i].label))?.small,
            mine: poll.mine.contains(choices[i].label),
            showResults: results && _barsInButtons,
            settings: poll.settings,
            enabled: _canAnswer,
            onTap: () => widget.onAnswer(PollAnswer.value(choices[i].label)),
          ),
        ),
      if (results && !_barsInButtons) _Chart(poll: poll),
      if (!results && !widget.closed && poll.isOpen && !poll.resultsHidden)
        const Text(
          'Tap an answer — the room’s counts show as soon as you do.',
          style: TextStyle(fontSize: 12.5, color: LiveColors.muted),
        ),
    ];
  }

  static int _optionIndex(LivePoll poll, String label) =>
      poll.options.indexOf(label);

  List<Widget> _multiple(LivePoll poll) {
    final max = poll.settings.maxChoices;
    final results = _showResults;
    final choices = poll.choicesToShow;
    final picks = _picks.isEmpty && poll.answered ? poll.mine.toSet() : _picks;
    return [
      Text('Pick up to $max.',
          style: const TextStyle(fontSize: 13, color: LiveColors.muted)),
      const SizedBox(height: 8),
      for (var i = 0; i < choices.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ChoiceButton(
            key: ValueKey('poll-pick-${choices[i].label}'),
            choice: choices[i],
            image: poll.imageOf(_optionIndex(poll, choices[i].label))?.small,
            mine: picks.contains(choices[i].label),
            checkbox: true,
            showResults: results && _barsInButtons,
            settings: poll.settings,
            enabled: _canAnswer &&
                (picks.contains(choices[i].label) || picks.length < max),
            onTap: () => setState(() {
              final next = {...picks};
              if (!next.remove(choices[i].label)) next.add(choices[i].label);
              _picks = next;
            }),
          ),
        ),
      if (results && !_barsInButtons) _Chart(poll: poll),
      if (_canAnswer)
        FilledButton(
          key: const ValueKey('poll-send'),
          onPressed: picks.isEmpty || _sameAsSent(poll, picks)
              ? null
              : () async {
                  final labels = [
                    for (final c in choices)
                      if (picks.contains(c.label)) c.label,
                  ];
                  if (await widget.onAnswer(PollAnswer(values: labels)) &&
                      mounted) {
                    setState(() => _picks = {});
                  }
                },
          style: liveButtonStyle(LiveLook.of(context),
              minimumSize: const Size.fromHeight(liveTapTarget)),
          child: Text(picks.isEmpty
              ? 'Pick an answer'
              : poll.answered
                  ? 'Change my answer'
                  : 'Send ${picks.length == 1 ? 'my answer' : '${picks.length} answers'}'),
        ),
    ];
  }

  static bool _sameAsSent(LivePoll poll, Set<String> picks) =>
      poll.answered &&
      poll.mine.toSet().length == picks.length &&
      poll.mine.toSet().containsAll(picks);

  // ─── Words and open text ──────────────────────────────────────────────

  List<Widget> _words(LivePoll poll) {
    final words = poll.words;
    return [
      if (_showResults && words.isNotEmpty) ...[
        Semantics(
          label: 'What the room said: '
              '${words.map((w) => '${w.word}, ${w.count}').join('; ')}',
          child: ExcludeSemantics(child: _WordCloud(words: words)),
        ),
        const SizedBox(height: 12),
      ],
      if (_canAnswer || (!widget.closed && poll.isOpen && widget.busy))
        _wordField(
          poll,
          label: 'Your word',
          hint: poll.myResponse != null
              ? 'You said “${poll.myResponse}” — change it?'
              : 'A word or two',
          max: 40,
          min: 2,
          fieldKey: const ValueKey('poll-word'),
        ),
    ];
  }

  Widget _wordField(
    LivePoll poll, {
    required String label,
    required String hint,
    required int max,
    required int min,
    required Key fieldKey,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            key: fieldKey,
            controller: _word,
            maxLength: max,
            maxLines: maxLines,
            minLines: 1,
            enabled: !widget.busy,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _sendWord(),
            decoration: InputDecoration(
              counterText: '',
              isDense: true,
              border: const OutlineInputBorder(),
              labelText: label,
              hintText: hint,
            ),
          ),
        ),
        const SizedBox(width: 8),
        ListenableBuilder(
          listenable: _word,
          builder: (context, _) => FilledButton(
            key: const ValueKey('poll-send'),
            onPressed: widget.busy || _word.text.trim().length < min
                ? null
                : _sendWord,
            style: liveButtonStyle(LiveLook.of(context),
                minimumSize: const Size(72, liveTapTarget)),
            child: const Text('Send'),
          ),
        ),
      ],
    );
  }

  List<Widget> _text(LivePoll poll) {
    final named = !poll.settings.anonymous;
    return [
      if (_canAnswer) ...[
        if (named) ...[
          TextField(
            key: const ValueKey('poll-name'),
            controller: _name,
            maxLength: 60,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              counterText: '',
              isDense: true,
              border: OutlineInputBorder(),
              labelText: 'Your name (shown with your answer)',
            ),
          ),
          const SizedBox(height: 8),
        ],
        _wordField(
          poll,
          label: 'Your answer',
          hint: poll.answered ? 'Send another to change it' : 'Up to 120 characters',
          max: pollTextMax,
          min: 1,
          maxLines: 3,
          fieldKey: const ValueKey('poll-text'),
        ),
        if (poll.settings.moderate)
          const _Note('The organiser reads answers before they show.'),
      ],
      if (_showResults && poll.texts.isNotEmpty) ...[
        const SizedBox(height: 12),
        for (final t in poll.texts.take(20))
          Semantics(
            container: true,
            label: t.name == null ? t.text : '${t.name}: ${t.text}',
            excludeSemantics: true,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: LiveColors.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.text,
                      style: const TextStyle(fontSize: 14.5, height: 1.35)),
                  if (t.name != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(t.name!,
                          style: const TextStyle(
                              fontSize: 12, color: LiveColors.muted)),
                    ),
                ],
              ),
            ),
          ),
      ],
    ];
  }

  // ─── Rating ───────────────────────────────────────────────────────────

  List<Widget> _rating(LivePoll poll) {
    final mine = int.tryParse(poll.myResponse ?? '') ?? 0;
    final scale = poll.scale;
    final stars = poll.settings.style == 'stars' && scale == 5;
    final enabled = _canAnswer;
    return [
      Semantics(
        container: true,
        label: 'Rate from 1 to $scale',
        child: Wrap(
          spacing: stars ? 0 : 6,
          runSpacing: 6,
          children: [
            for (var n = 1; n <= scale; n++)
              Semantics(
                button: true,
                selected: mine == n,
                label: '$n of $scale',
                excludeSemantics: true,
                child: stars
                    ? SizedBox(
                        width: liveTapTarget + 8,
                        height: liveTapTarget + 8,
                        child: IconButton(
                          key: ValueKey('rate-$n'),
                          onPressed: enabled
                              ? () => widget.onAnswer(PollAnswer.value('$n'))
                              : null,
                          icon: Icon(
                            mine >= n
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 38,
                            color: mine >= n ? LiveColors.warn : LiveColors.muted,
                          ),
                        ),
                      )
                    : _NumberChip(
                        key: ValueKey('rate-$n'),
                        n: n,
                        chosen: mine == n,
                        onTap: enabled
                            ? () => widget.onAnswer(PollAnswer.value('$n'))
                            : null,
                      ),
              ),
          ],
        ),
      ),
      if (_showResults && poll.ratingAverage != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Room average ${_trim(poll.ratingAverage!)} of $scale',
            style: const TextStyle(fontSize: 13, color: LiveColors.muted),
          ),
        ),
      if (_showResults && poll.histogram.any((h) => h.count > 0))
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _Histogram(bars: poll.histogram, settings: poll.settings),
        ),
    ];
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ─── Ranking ──────────────────────────────────────────────────────────

  List<Widget> _ranking(LivePoll poll) {
    final sent = poll.answered && poll.mine.length == poll.options.length
        ? poll.mine
        : null;
    final order = _order ?? sent ?? poll.options;
    final enabled = _canAnswer;
    return [
      if (enabled)
        const Text('Drag the handles, or use the arrows, best first.',
            style: TextStyle(fontSize: 13, color: LiveColors.muted)),
      const SizedBox(height: 8),
      LiveOrderList(
        keyPrefix: 'rank',
        items: [
          for (var i = 0; i < poll.options.length; i++)
            LiveOrderItem(
                id: poll.options[i],
                label: poll.options[i],
                image: poll.imageOf(i)?.small),
        ],
        order: order,
        enabled: enabled,
        onChanged: (next) => setState(() => _order = next),
      ),
      if (enabled)
        FilledButton(
          key: const ValueKey('poll-send'),
          onPressed: sent != null && _order == null
              ? null
              : () async {
                  if (await widget.onAnswer(PollAnswer(order: order)) &&
                      mounted) {
                    setState(() => _order = null);
                  }
                },
          style: liveButtonStyle(LiveLook.of(context),
              minimumSize: const Size.fromHeight(liveTapTarget)),
          child: Text(sent != null ? 'Change my ranking' : 'Send my ranking'),
        ),
      if (_showResults && poll.ranking.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text('The room’s ranking',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: LiveLook.of(context).accent)),
        for (var i = 0; i < poll.ranking.length; i++)
          _RankRow(place: i + 1, rank: poll.ranking[i]),
      ],
    ];
  }
}

/// The poll's timer: "Closes in 0:42".
class _Countdown extends StatelessWidget {
  const _Countdown({required this.left});
  final Duration left;

  @override
  Widget build(BuildContext context) {
    final s = left.inSeconds;
    final text = s <= 0
        ? 'Closing…'
        : 'Closes in ${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(Icons.timer_outlined,
              size: 16, color: s <= 10 ? LiveColors.warn : LiveColors.muted),
          const SizedBox(width: 4),
          Text(text,
              key: const ValueKey('poll-countdown'),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: s <= 10 ? LiveColors.warnInk : LiveColors.muted)),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 12.5, color: LiveColors.muted)),
    );
  }
}

/// "You voted Pizza": the confirmation, right under the prompt.
class _Voted extends StatelessWidget {
  const _Voted({required this.poll});
  final LivePoll poll;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    final mine = poll.mine;
    final said = switch (poll.kind) {
      'rating' => 'You rated ${mine.firstOrNull ?? ''} of ${poll.scale}',
      'ranking' => 'Your ranking: ${mine.join(', ')}',
      'text' => poll.settings.moderate
          ? 'Sent — the organiser will put it up'
          : 'You said “${mine.firstOrNull ?? ''}”',
      _ => 'You voted ${mine.join(', ')}',
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: look.liveEdge),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_rounded, size: 18, color: look.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  said,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: look.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "73% · 30 votes", as the poll says to show them.
String _shown(PollChoice c, PollSettings settings) {
  final votes = '${c.count} ${c.count == 1 ? 'vote' : 'votes'}';
  return [
    if (settings.showsPercent) '${c.pct}%',
    if (settings.showsCount) votes,
  ].join(' · ');
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.choice,
    required this.mine,
    required this.showResults,
    required this.enabled,
    required this.onTap,
    this.settings = const PollSettings(),
    this.checkbox = false,
    this.image,
  });

  final PollChoice choice;
  final bool mine;
  final bool showResults;
  final bool enabled;
  final VoidCallback onTap;
  final PollSettings settings;

  /// One of several picks (a multiple choice): a box to tick.
  final bool checkbox;
  final String? image;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    final votes = '${choice.count} ${choice.count == 1 ? 'vote' : 'votes'}';
    final label = [
      choice.label,
      if (showResults && settings.showsPercent) '${choice.pct} percent',
      if (showResults && settings.showsCount) votes,
      if (mine) checkbox ? 'picked' : 'your answer',
    ].join(', ');
    final still = liveStill(context);
    return Semantics(
      button: !checkbox,
      checked: checkbox ? mine : null,
      selected: checkbox ? null : mine,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: mine ? look.accent : LiveColors.line,
            width: mine ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Stack(
              children: [
                if (showResults)
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: still ? choice.pct.clamp(0, 100) / 100 : 0,
                        end: choice.pct.clamp(0, 100) / 100,
                      ),
                      duration: Duration(milliseconds: still ? 0 : 450),
                      curve: Curves.easeOutCubic,
                      builder: (context, width, _) => FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: width,
                        child: Container(
                          color: mine ? look.liveEdge : look.liveCard,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      if (checkbox)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                              mine
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 22,
                              color: mine ? look.accent : LiveColors.muted),
                        )
                      else if (mine)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.check_circle,
                              size: 20, color: look.accent),
                        ),
                      if (image != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: AppNetworkImage(
                                url: image, width: 44, height: 44),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          choice.label,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.3,
                            fontWeight:
                                mine ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (showResults) ...[
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              settings.showsPercent ? '${choice.pct}%' : votes,
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            if (settings.showsPercent && settings.showsCount)
                              Text(
                                votes,
                                style: const TextStyle(
                                    fontSize: 11, color: LiveColors.muted),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rating of 1 to 10 as a row of numbers.
class _NumberChip extends StatelessWidget {
  const _NumberChip(
      {super.key, required this.n, required this.chosen, this.onTap});
  final int n;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    return SizedBox(
      width: liveTapTarget,
      height: liveTapTarget,
      child: Material(
        color: chosen ? look.button : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: chosen ? look.button : LiveColors.line),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: Text('$n',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: chosen
                        ? (look.custom ? look.onButton : Colors.white)
                        : onTap == null
                            ? LiveColors.muted
                            : LiveColors.ink)),
          ),
        ),
      ),
    );
  }
}

/// A rating's scores, as short bars.
class _Histogram extends StatelessWidget {
  const _Histogram({required this.bars, required this.settings});
  final List<PollChoice> bars;
  final PollSettings settings;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    final top = bars.map((b) => b.count).fold(0, math.max);
    return Semantics(
      container: true,
      label: 'Scores: ${bars.map((b) => '${b.label}, ${_shown(b, settings)}').join('; ')}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (final b in bars.reversed)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    SizedBox(
                        width: 24,
                        child: Text(b.label,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: top == 0 ? 0 : b.count / top,
                          minHeight: 10,
                          backgroundColor: LiveColors.offTint,
                          valueColor: AlwaysStoppedAnimation(look.dot),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(_shown(b, settings),
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontSize: 11.5, color: LiveColors.muted)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A choice poll's results as columns or a donut (bars are drawn in the
/// buttons themselves).
class _Chart extends StatelessWidget {
  const _Chart({required this.poll});
  final LivePoll poll;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    final choices = poll.choicesToShow;
    final settings = poll.settings;
    final colours = [for (var i = 0; i < choices.length; i++) look.answerColour(i)];
    final label = 'Results: ${choices.map((c) => '${c.label}, ${_shown(c, settings)}').join('; ')}';
    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < choices.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: colours[i],
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(choices[i].label,
                        style: const TextStyle(fontSize: 13))),
                Text(_shown(choices[i], settings),
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
    final Widget chart;
    if (settings.chart == 'donut') {
      chart = SizedBox(
        key: const ValueKey('poll-donut'),
        width: 140,
        height: 140,
        child: CustomPaint(
          painter: _DonutPainter(
            values: [for (final c in choices) c.count.toDouble()],
            colours: colours,
          ),
          child: Center(
            child: Text('${poll.responses}',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800)),
          ),
        ),
      );
    } else {
      final top = choices.map((c) => c.count).fold(0, math.max);
      chart = SizedBox(
        key: const ValueKey('poll-columns'),
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < choices.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FractionallySizedBox(
                    heightFactor:
                        top == 0 ? 0.02 : math.max(0.02, choices[i].count / top),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colours[i],
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Column(
            children: [
              Center(child: chart),
              const SizedBox(height: 10),
              legend,
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.values, required this.colours});
  final List<double> values;
  final List<Color> colours;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final stroke = size.shortestSide * 0.18;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero),
        radius: size.shortestSide / 2 - stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false,
          paint..color = LiveColors.offTint);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      if (sweep <= 0) continue;
      canvas.drawArc(rect, start, sweep, false, paint..color = colours[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.values.toString() != values.toString() ||
      old.colours.toString() != colours.toString();
}

/// An option of a ranking poll, as the room ranked it.
class _RankRow extends StatelessWidget {
  const _RankRow({required this.place, required this.rank});
  final int place;
  final PollRank rank;

  @override
  Widget build(BuildContext context) {
    final average = rank.average;
    final note = [
      if (average != null) 'average place ${average.toStringAsFixed(1)}',
      if (rank.first > 0) '${rank.first} put it first',
    ].join(' · ');
    return Semantics(
      container: true,
      label: '${ordinal(place)}, ${rank.label}${note.isEmpty ? '' : ', $note'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text('$place',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rank.label,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                  if (note.isNotEmpty)
                    Text(note,
                        style: const TextStyle(
                            fontSize: 12, color: LiveColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The room's words: the most said twice the size of the least.
class _WordCloud extends StatelessWidget {
  const _WordCloud({required this.words});
  final List<PollWord> words;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    final counts = words.map((w) => w.count);
    final max = counts.reduce((a, b) => a > b ? a : b);
    final min = counts.reduce((a, b) => a < b ? a : b);
    double size(int c) => 14 + (max == min ? 8 : 18 * (c - min) / (max - min));
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final w in words)
          Text(
            w.word,
            style: TextStyle(
              fontSize: size(w.count),
              fontWeight: FontWeight.w600,
              color: look.accent,
            ),
          ),
      ],
    );
  }
}
