import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/domain/live_room.dart';
import 'package:flutter/material.dart';

/// The live room's colours: the event page's LIVE NOW strip's greens, and
/// the app's dark button.
abstract final class LiveColors {
  static const tint = Color(0xFFECFDF5);
  static const edge = Color(0xFFA7F3D0);
  static const dot = Color(0xFF14B8A6);
  static const deep = Color(0xFF0F766E);
  static const ink = Color(0xFF2C333D);
  static const muted = Color(0xFF6B7280);
  static const line = Color(0xFFE5E7EB);
  static const right = Color(0xFF15803D);
  static const wrong = Color(0xFFB91C1C);
}

/// The smallest a thing to tap is: 48 by 48.
const double liveTapTarget = 48;

/// A card of the room.
class LiveCard extends StatelessWidget {
  const LiveCard({super.key, required this.child, this.live = false});
  final Widget child;

  /// Something happening now: the poll, the quiz.
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: live ? LiveColors.tint : Colors.white,
        border: Border.all(color: live ? LiveColors.edge : LiveColors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

/// "● LIVE", "● POLL", "● QUIZ".
class LiveDot extends StatelessWidget {
  const LiveDot(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: LiveColors.dot,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: LiveColors.deep,
          ),
        ),
      ],
    );
  }
}

/// A small label beside a question: "Answered", "On screen".
class LivePill extends StatelessWidget {
  const LivePill(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: LiveColors.tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: LiveColors.edge),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: LiveColors.deep),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: LiveColors.muted),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: LiveColors.wrong),
      ),
    );
  }
}

// ─── Updates ─────────────────────────────────────────────────────────────

/// The organiser's latest update, at the top of the room.
class LiveBannerCard extends StatelessWidget {
  const LiveBannerCard({super.key, required this.update});
  final LiveUpdate update;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${update.kindLabel}: ${update.text}',
      child: ExcludeSemantics(
        child: LiveCard(
          live: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LiveDot(update.kindLabel),
              const SizedBox(height: 6),
              Text(update.text, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The updates before the banner's.
class EarlierUpdates extends StatelessWidget {
  const EarlierUpdates({super.key, required this.updates});
  final List<LiveUpdate> updates;

  @override
  Widget build(BuildContext context) {
    return LiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Heading('Earlier tonight'),
          for (final u in updates)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.text, style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    u.kindLabel,
                    style:
                        const TextStyle(fontSize: 12, color: LiveColors.muted),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── The quiz's way in ───────────────────────────────────────────────────

class QuizEntryCard extends StatelessWidget {
  const QuizEntryCard({super.key, this.title, required this.onJoin});
  final String? title;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    return LiveCard(
      live: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LiveDot('Quiz'),
          const SizedBox(height: 6),
          _Heading(title?.isNotEmpty == true ? title! : 'The quiz is on'),
          const _Sub(
              'Type the code on the screen and your name. Fast right answers '
              'score most.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onJoin,
            style: FilledButton.styleFrom(
              backgroundColor: LiveColors.ink,
              minimumSize: const Size.fromHeight(liveTapTarget),
            ),
            child: const Text('Join the quiz'),
          ),
        ],
      ),
    );
  }
}

// ─── The poll ────────────────────────────────────────────────────────────

/// The poll that is up: a choice, a word or two, or a rating, and the
/// room's answers once this phone has given one.
class PollCard extends StatefulWidget {
  const PollCard({
    super.key,
    required this.poll,
    required this.onAnswer,
    this.busy = false,
    this.error,
    this.closed = false,
  });

  final LivePoll poll;
  final Future<bool> Function(String value) onAnswer;
  final bool busy;
  final String? error;

  /// The room has closed: results only.
  final bool closed;

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  final _word = TextEditingController();

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  Future<void> _sendWord() async {
    final value = _word.text.trim();
    if (value.length < 2) return;
    if (await widget.onAnswer(value) && mounted) _word.clear();
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    final showResults = poll.answered || widget.closed;
    final count = poll.responses;
    return LiveCard(
      live: !widget.closed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LiveDot('Poll'),
          const SizedBox(height: 6),
          _Heading(poll.prompt),
          _Sub('$count ${count == 1 ? 'answer' : 'answers'} so far'
              '${poll.answered ? ' · you answered' : ''}'),
          const SizedBox(height: 12),
          if (poll.isChoice) ..._choices(poll, showResults),
          if (poll.isWords) ..._words(poll, showResults),
          if (poll.isRating) ..._rating(poll, showResults),
          if (widget.error != null) _ErrorLine(widget.error!),
        ],
      ),
    );
  }

  List<Widget> _choices(LivePoll poll, bool showResults) => [
        for (final c in poll.choicesToShow)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ChoiceButton(
              choice: c,
              mine: poll.myResponse == c.label,
              showResults: showResults,
              enabled: !widget.busy && !widget.closed,
              onTap: () => widget.onAnswer(c.label),
            ),
          ),
      ];

  List<Widget> _words(LivePoll poll, bool showResults) {
    final words = poll.words;
    return [
      if (showResults && words.isNotEmpty) ...[
        Semantics(
          label: 'What the room said: '
              '${words.map((w) => '${w.word}, ${w.count}').join('; ')}',
          child: ExcludeSemantics(child: _WordCloud(words: words)),
        ),
        const SizedBox(height: 12),
      ],
      if (!widget.closed)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: const ValueKey('poll-word'),
                controller: _word,
                maxLength: 40,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendWord(),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  labelText: 'Your word',
                  hintText: poll.myResponse != null
                      ? 'You said “${poll.myResponse}” — change it?'
                      : 'A word or two',
                ),
              ),
            ),
            const SizedBox(width: 8),
            ListenableBuilder(
              listenable: _word,
              builder: (context, _) => FilledButton(
                onPressed: widget.busy || _word.text.trim().length < 2
                    ? null
                    : _sendWord,
                style: FilledButton.styleFrom(
                  backgroundColor: LiveColors.ink,
                  minimumSize: const Size(72, liveTapTarget),
                ),
                child: const Text('Send'),
              ),
            ),
          ],
        ),
    ];
  }

  List<Widget> _rating(LivePoll poll, bool showResults) {
    final mine = int.tryParse(poll.myResponse ?? '') ?? 0;
    return [
      Semantics(
        container: true,
        label: 'Rate from 1 to 5',
        child: Row(
          children: [
            for (var n = 1; n <= 5; n++)
              Semantics(
                button: true,
                selected: mine == n,
                label: '$n of 5',
                excludeSemantics: true,
                child: SizedBox(
                  width: liveTapTarget + 4,
                  height: liveTapTarget + 4,
                  child: IconButton(
                    key: ValueKey('rate-$n'),
                    onPressed: widget.busy || widget.closed
                        ? null
                        : () => widget.onAnswer('$n'),
                    icon: Icon(
                      mine >= n ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 36,
                      color: mine >= n
                          ? const Color(0xFFF59E0B)
                          : LiveColors.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      if (showResults && poll.ratingAverage != null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Room average ${_trim(poll.ratingAverage!)} of 5',
            style: const TextStyle(fontSize: 13, color: LiveColors.muted),
          ),
        ),
    ];
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.choice,
    required this.mine,
    required this.showResults,
    required this.enabled,
    required this.onTap,
  });

  final PollChoice choice;
  final bool mine;
  final bool showResults;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = [
      choice.label,
      if (showResults) '${choice.pct} percent',
      if (mine) 'your answer',
    ].join(', ');
    return Semantics(
      button: true,
      selected: mine,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: mine ? LiveColors.deep : LiveColors.line,
            width: mine ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: liveTapTarget + 4),
            child: Stack(
              children: [
                if (showResults)
                  Positioned.fill(
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: choice.pct.clamp(0, 100) / 100,
                      child: Container(color: LiveColors.tint),
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      if (mine)
                        const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(Icons.check_circle,
                              size: 20, color: LiveColors.deep),
                        ),
                      Expanded(
                        child: Text(choice.label,
                            style: const TextStyle(fontSize: 15)),
                      ),
                      if (showResults)
                        Text(
                          '${choice.pct}%',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
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

/// The room's words: the most said twice the size of the least.
class _WordCloud extends StatelessWidget {
  const _WordCloud({required this.words});
  final List<PollWord> words;

  @override
  Widget build(BuildContext context) {
    final counts = words.map((w) => w.count);
    final max = counts.reduce((a, b) => a > b ? a : b);
    final min = counts.reduce((a, b) => a < b ? a : b);
    double size(int c) =>
        14 + (max == min ? 8 : 18 * (c - min) / (max - min));
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
              color: LiveColors.deep,
            ),
          ),
      ],
    );
  }
}

// ─── Questions from the floor ───────────────────────────────────────────

/// Ask the room, and the questions on the board to vote up.
class QuestionsSection extends StatefulWidget {
  const QuestionsSection({
    super.key,
    required this.questions,
    required this.canAsk,
    required this.approveFirst,
    required this.onAsk,
    required this.onVote,
    this.refused = false,
    this.asking = false,
    this.note,
    this.error,
    this.voting = const {},
    this.defaultName,
  });

  final List<LiveQuestion> questions;
  final bool canAsk;
  final bool approveFirst;
  final Future<bool> Function(String text, String name) onAsk;
  final void Function(String questionId) onVote;

  /// A question was refused because the floor is closed.
  final bool refused;
  final bool asking;
  final String? note;
  final String? error;
  final Set<String> voting;

  /// The name the ask box starts with: the signed-in person's.
  final String? defaultName;

  @override
  State<QuestionsSection> createState() => _QuestionsSectionState();
}

class _QuestionsSectionState extends State<QuestionsSection> {
  final _text = TextEditingController();
  late final _name = TextEditingController(text: widget.defaultName ?? '');

  @override
  void didUpdateWidget(QuestionsSection old) {
    super.didUpdateWidget(old);
    if (old.defaultName != widget.defaultName &&
        _name.text.isEmpty &&
        widget.defaultName != null) {
      _name.text = widget.defaultName!;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _ask() async {
    if (await widget.onAsk(_text.text, _name.text) && mounted) {
      _text.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.canAsk;
    final questions = widget.questions;
    if (!open && questions.isEmpty) {
      return widget.refused
          ? const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text("Questions aren't open right now.",
                  style: TextStyle(color: LiveColors.muted)),
            )
          : const SizedBox.shrink();
    }
    return LiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Heading(open ? 'Ask the room' : 'Questions from the room'),
          _Sub(!open
              ? 'Questions aren’t open right now. Vote up the ones you want '
                  'answered.'
              : widget.approveFirst
                  ? 'Questions show once the organiser lets them through. '
                      'Vote up the ones you want answered.'
                  : 'Questions go straight to the board. Vote up the ones '
                      'you want answered.'),
          if (open) ...[
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('ask-text'),
              controller: _text,
              maxLength: 500,
              minLines: 2,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Your question',
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('ask-name'),
                    controller: _name,
                    maxLength: 60,
                    decoration: const InputDecoration(
                      counterText: '',
                      isDense: true,
                      border: OutlineInputBorder(),
                      labelText: 'Your name (optional)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ListenableBuilder(
                  listenable: _text,
                  builder: (context, _) => FilledButton(
                    onPressed: widget.asking || _text.text.trim().length < 3
                        ? null
                        : _ask,
                    style: FilledButton.styleFrom(
                      backgroundColor: LiveColors.ink,
                      minimumSize: const Size(72, liveTapTarget),
                    ),
                    child: widget.asking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Ask'),
                  ),
                ),
              ],
            ),
            if (widget.note != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(widget.note!,
                      style: const TextStyle(
                          fontSize: 13, color: LiveColors.deep)),
                ),
              ),
            if (widget.error != null) _ErrorLine(widget.error!),
          ],
          const SizedBox(height: 8),
          if (questions.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('No questions yet. Be the first to ask.',
                  style: TextStyle(fontSize: 13, color: LiveColors.muted)),
            )
          else
            for (final q in questions)
              _QuestionRow(
                question: q,
                busy: widget.voting.contains(q.id),
                onVote: () => widget.onVote(q.id),
              ),
        ],
      ),
    );
  }
}

class _QuestionRow extends StatelessWidget {
  const _QuestionRow({
    required this.question,
    required this.busy,
    required this.onVote,
  });

  final LiveQuestion question;
  final bool busy;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final q = question;
    final votes = '${q.votes} ${q.votes == 1 ? 'vote' : 'votes'}';
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            toggled: q.voted,
            enabled: !q.answered,
            label: q.answered
                ? '$votes, answered'
                : q.voted
                    ? '$votes, yours among them. Take your vote back'
                    : '$votes. Vote this question up',
            excludeSemantics: true,
            child: SizedBox(
              width: 56,
              height: 56,
              child: OutlinedButton(
                key: ValueKey('vote-${q.id}'),
                onPressed: q.answered || busy ? null : onVote,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: q.voted ? LiveColors.tint : null,
                  side: BorderSide(
                      color: q.voted ? LiveColors.deep : LiveColors.line),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.arrow_drop_up,
                        size: 22,
                        color: q.voted ? LiveColors.deep : LiveColors.muted),
                    Text(
                      '${q.votes}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: q.voted ? LiveColors.deep : LiveColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Opacity(
              opacity: q.answered ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: [
                      Text(q.text, style: const TextStyle(fontSize: 15)),
                      if (q.pinned) const LivePill('On screen'),
                      if (q.answered) const LivePill('Answered'),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${q.authorName ?? 'Anonymous'}${q.mine ? ' · you' : ''}',
                    style:
                        const TextStyle(fontSize: 12, color: LiveColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── The quiz's board ───────────────────────────────────────────────────

/// "1st", "2nd", "3rd", "11th".
String ordinal(int n) {
  final teen = n % 100 >= 11 && n % 100 <= 13;
  final suffix = teen
      ? 'th'
      : switch (n % 10) {
          1 => 'st',
          2 => 'nd',
          3 => 'rd',
          _ => 'th',
        };
  return '$n$suffix';
}

class QuizLeaderboard extends StatelessWidget {
  const QuizLeaderboard({super.key, required this.board, this.me});
  final List<BoardEntry> board;

  /// The player's name, to pick out their row.
  final String? me;

  @override
  Widget build(BuildContext context) {
    if (board.isEmpty) return const SizedBox.shrink();
    return Semantics(
      container: true,
      label: 'Leaderboard',
      child: Column(
        children: [
          for (final e in board)
            Semantics(
              container: true,
              label: '${ordinal(e.rank)}, ${e.name}, ${e.score} points'
                  '${e.name == me ? ', you' : ''}',
              excludeSemantics: true,
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: e.name == me ? LiveColors.tint : Colors.white,
                  border: Border.all(
                      color: e.name == me ? LiveColors.edge : LiveColors.line),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text('${e.rank}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    Expanded(
                        child: Text(e.name,
                            style: const TextStyle(fontSize: 15))),
                    Text('${e.score}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
