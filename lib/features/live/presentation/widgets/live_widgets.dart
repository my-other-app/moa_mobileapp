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

  /// The page behind the cards.
  static const wash = Color(0xFFF9FAFB);

  /// A state that is off: a grey chip rather than a green one.
  static const offTint = Color(0xFFF3F4F6);

  /// The clock as time runs short, and a rating's stars.
  static const warn = Color(0xFFD97706);
  static const warnTint = Color(0xFFFFFBEB);
  static const warnEdge = Color(0xFFFDE68A);
  static const warnInk = Color(0xFF92400E);
  static const wrongTint = Color(0xFFFEE2E2);
  static const rightTint = Color(0xFFDCFCE7);

  /// The podium.
  static const gold = Color(0xFFD4A017);
  static const goldTint = Color(0xFFFEF9E7);
  static const silver = Color(0xFF8A94A6);
  static const silverTint = Color(0xFFF4F6F8);
  static const bronze = Color(0xFFA9631F);
  static const bronzeTint = Color(0xFFFDF3E7);
}

/// The smallest a thing to tap is: 48 by 48.
const double liveTapTarget = 48;

/// Whether the phone asks for less movement (iOS "Reduce Motion", Android
/// "Remove animations"). Everything here that moves checks it first.
bool liveStill(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// How long ago, in as few words as the room needs: "just now", "5 min
/// ago", "2 h ago", then the day.
String liveAgo(DateTime? at, {DateTime? now}) {
  if (at == null) return '';
  final gap = (now ?? DateTime.now()).difference(at);
  if (gap.isNegative || gap.inSeconds < 60) return 'just now';
  if (gap.inMinutes < 60) return '${gap.inMinutes} min ago';
  if (gap.inHours < 24) return '${gap.inHours} h ago';
  if (gap.inDays < 7) return '${gap.inDays} d ago';
  return '${at.day}/${at.month}';
}

/// A card of the room.
class LiveCard extends StatelessWidget {
  const LiveCard({
    super.key,
    required this.child,
    this.live = false,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;

  /// Something happening now: the poll, the quiz.
  final bool live;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: padding,
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
  const LiveDot(this.label, {super.key, this.colour, this.beat = false});
  final String label;
  final Color? colour;

  /// The dot breathes while the thing is on (unless motion is turned down).
  final bool beat;

  @override
  Widget build(BuildContext context) {
    final tone = colour ?? LiveColors.deep;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Beacon(
          colour: tone == LiveColors.deep ? LiveColors.dot : tone,
          beat: beat,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: tone,
            ),
          ),
        ),
      ],
    );
  }
}

/// The eight-point dot, breathing while something is live.
class _Beacon extends StatefulWidget {
  const _Beacon({required this.colour, this.beat = false});
  final Color colour;
  final bool beat;

  @override
  State<_Beacon> createState() => _BeaconState();
}

class _BeaconState extends State<_Beacon> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: widget.colour, shape: BoxShape.circle),
    );
    if (!widget.beat || liveStill(context)) {
      if (_pulse.isAnimating) _pulse.stop();
      return dot;
    }
    if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    return FadeTransition(
      opacity: _pulse.drive(Tween(begin: 1.0, end: 0.35)),
      child: dot,
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
  const _Heading(this.text, {this.size = 18});
  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
            fontSize: size, fontWeight: FontWeight.w700, height: 1.25),
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
      child: Semantics(
        liveRegion: true,
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: LiveColors.wrong),
        ),
      ),
    );
  }
}

// ─── What is on, at a glance ─────────────────────────────────────────────

/// The room's state in one line of chips: is the event live, is a poll up,
/// is the floor open, is a quiz running. A chip that is on is green with a
/// dot; one that is off is grey. It wraps, so it holds at 320 points wide
/// and at the largest system text.
class LiveStatusBar extends StatelessWidget {
  const LiveStatusBar({super.key, required this.room});
  final LiveRoom room;

  @override
  Widget build(BuildContext context) {
    final closed = room.isClosed;
    final pollUp = room.poll != null && !closed;
    final floorOpen = room.qaOpen && !closed;
    final quizOn = room.quizLive && !closed;
    return Semantics(
      container: true,
      label: [
        closed
            ? 'The event is over'
            : room.isEventLive
                ? 'The event is live'
                : 'The event has not started',
        pollUp ? 'a poll is up' : 'no poll up',
        floorOpen ? 'questions are open' : 'questions are closed',
        quizOn ? 'a quiz is running' : 'no quiz running',
      ].join(', '),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StateChip(
                label: closed
                    ? 'Event over'
                    : room.isEventLive
                        ? 'Live now'
                        : 'Not started',
                on: room.isEventLive && !closed,
                beat: true,
              ),
              _StateChip(label: 'Poll', on: pollUp),
              _StateChip(label: 'Q&A', on: floorOpen),
              _StateChip(label: 'Quiz', on: quizOn),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.on, this.beat = false});
  final String label;
  final bool on;
  final bool beat;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: on ? LiveColors.tint : LiveColors.offTint,
        border: Border.all(color: on ? LiveColors.edge : LiveColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: on
          ? LiveDot(label, beat: beat)
          : Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: LiveColors.muted,
              ),
            ),
    );
  }
}

/// Reads are failing: said once, at the top, with a way to try now.
class LiveConnectionBar extends StatelessWidget {
  const LiveConnectionBar({super.key, this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Connection lost. Trying again.',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.fromLTRB(12, 10, onRetry == null ? 12 : 8, 10),
        decoration: BoxDecoration(
          color: LiveColors.warnTint,
          border: Border.all(color: LiveColors.warnEdge),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 18, color: LiveColors.warn),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Connection lost — trying again…',
                style: TextStyle(fontSize: 13, color: LiveColors.warnInk),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                style: TextButton.styleFrom(
                  foregroundColor: LiveColors.warnInk,
                  minimumSize: const Size(64, liveTapTarget),
                ),
                child: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }
}

/// A state designed on purpose: waiting for the host, nothing asked yet,
/// the room over.
class LiveWaiting extends StatelessWidget {
  const LiveWaiting({
    super.key,
    required this.icon,
    required this.title,
    required this.text,
    this.action,
    this.onAction,
    this.spinner = false,
  });

  final IconData icon;
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  /// Something is on its way: a ring around the mark.
  final bool spinner;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
      child: Column(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (spinner && !liveStill(context))
                  const SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: LiveColors.edge,
                    ),
                  ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: LiveColors.offTint,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 26, color: LiveColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13.5, height: 1.4, color: LiveColors.muted),
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: LiveColors.ink,
                minimumSize: const Size(160, liveTapTarget),
              ),
              child: Text(action!),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Updates ─────────────────────────────────────────────────────────────

IconData _updateIcon(String kind) => switch (kind) {
      'schedule' => Icons.schedule_rounded,
      'room' => Icons.place_outlined,
      _ => Icons.campaign_outlined,
    };

/// The organiser's latest update, at the top of the room: after whatever
/// is running, the loudest thing on the screen.
class LiveBannerCard extends StatelessWidget {
  const LiveBannerCard({super.key, required this.update});
  final LiveUpdate update;

  @override
  Widget build(BuildContext context) {
    final when = liveAgo(update.sentAt);
    return Semantics(
      container: true,
      liveRegion: true,
      label: '${update.kindLabel}: ${update.text}'
          '${when.isEmpty ? '' : ', $when'}',
      child: ExcludeSemantics(
        child: LiveCard(
          live: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: LiveDot(update.kindLabel, beat: true)),
                  if (when.isNotEmpty)
                    Text(
                      when,
                      style:
                          const TextStyle(fontSize: 11, color: LiveColors.deep),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                update.text,
                style: const TextStyle(
                    fontSize: 17, height: 1.35, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Everything the host said before the banner's, newest first, as a feed:
/// a rail with a mark per update, what kind it was and how long ago.
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
          const _Sub('Newest first.'),
          for (var i = 0; i < updates.length; i++)
            _FeedRow(update: updates[i], last: i == updates.length - 1),
        ],
      ),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.update, required this.last});
  final LiveUpdate update;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final when = liveAgo(update.sentAt);
    return Semantics(
      container: true,
      label: '${update.kindLabel}: ${update.text}'
          '${when.isEmpty ? '' : ', $when'}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: LiveColors.offTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_updateIcon(update.kind),
                        size: 15, color: LiveColors.muted),
                  ),
                  if (!last)
                    Container(
                      width: 2,
                      height: 18,
                      margin: const EdgeInsets.only(top: 4),
                      color: LiveColors.line,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(update.text,
                        style: const TextStyle(fontSize: 14.5, height: 1.35)),
                    const SizedBox(height: 3),
                    Text(
                      [update.kindLabel, if (when.isNotEmpty) when].join(' · '),
                      style: const TextStyle(
                          fontSize: 12, color: LiveColors.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          const LiveDot('Quiz', beat: true),
          const SizedBox(height: 8),
          _Heading(title?.isNotEmpty == true ? title! : 'The quiz is on',
              size: 22),
          const _Sub(
              'Type the code on the screen and your name. Fast right answers '
              'score most.'),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: const Text('Join the quiz',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              backgroundColor: LiveColors.ink,
              minimumSize: const Size.fromHeight(56),
            ),
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
          LiveDot('Poll', beat: !widget.closed),
          const SizedBox(height: 8),
          _Heading(poll.prompt, size: 20),
          _Sub('$count ${count == 1 ? 'answer' : 'answers'} so far'
              '${poll.answered ? ' · you answered' : ''}'),
          if (poll.answered) _Voted(poll: poll),
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
            padding: const EdgeInsets.only(bottom: 10),
            child: _ChoiceButton(
              choice: c,
              mine: poll.myResponse == c.label,
              showResults: showResults,
              enabled: !widget.busy && !widget.closed,
              onTap: () => widget.onAnswer(c.label),
            ),
          ),
        if (!showResults && !widget.closed)
          const Text(
            'Tap an answer — the room’s counts show as soon as you do.',
            style: TextStyle(fontSize: 12.5, color: LiveColors.muted),
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
        child: Wrap(
          children: [
            for (var n = 1; n <= 5; n++)
              Semantics(
                button: true,
                selected: mine == n,
                label: '$n of 5',
                excludeSemantics: true,
                child: SizedBox(
                  width: liveTapTarget + 8,
                  height: liveTapTarget + 8,
                  child: IconButton(
                    key: ValueKey('rate-$n'),
                    onPressed: widget.busy || widget.closed
                        ? null
                        : () => widget.onAnswer('$n'),
                    icon: Icon(
                      mine >= n ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 38,
                      color: mine >= n ? LiveColors.warn : LiveColors.muted,
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

/// "You voted Pizza": the confirmation, right under the prompt.
class _Voted extends StatelessWidget {
  const _Voted({required this.poll});
  final LivePoll poll;

  @override
  Widget build(BuildContext context) {
    final mine = poll.myResponse ?? '';
    final said = poll.isRating ? '$mine of 5' : mine;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: LiveColors.edge),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  size: 18, color: LiveColors.deep),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You voted $said',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: LiveColors.deep),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    final votes = '${choice.count} ${choice.count == 1 ? 'vote' : 'votes'}';
    final label = [
      choice.label,
      if (showResults) '${choice.pct} percent',
      if (showResults) votes,
      if (mine) 'your answer',
    ].join(', ');
    final still = liveStill(context);
    return Semantics(
      button: true,
      selected: mine,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: mine ? LiveColors.deep : LiveColors.line,
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
                          color: mine ? LiveColors.edge : LiveColors.tint,
                        ),
                      ),
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
                              '${choice.pct}%',
                              style: const TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700),
                            ),
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

/// The room's words: the most said twice the size of the least.
class _WordCloud extends StatelessWidget {
  const _WordCloud({required this.words});
  final List<PollWord> words;

  @override
  Widget build(BuildContext context) {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    _Heading(open ? 'Ask the room' : 'Questions from the room'),
              ),
              if (questions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Text(
                    '${questions.length} on the board',
                    style: const TextStyle(
                        fontSize: 12, color: LiveColors.muted),
                  ),
                ),
            ],
          ),
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
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          size: 16, color: LiveColors.deep),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(widget.note!,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: LiveColors.deep)),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.error != null) _ErrorLine(widget.error!),
          ],
          const SizedBox(height: 8),
          if (questions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined,
                      size: 16, color: LiveColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      open
                          ? 'No questions yet. Be the first to ask.'
                          : 'No questions yet.',
                      style: const TextStyle(
                          fontSize: 13, color: LiveColors.muted),
                    ),
                  ),
                ],
              ),
            )
          else
            for (final q in questions)
              _QuestionRow(
                key: ValueKey('q-${q.id}'),
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
    super.key,
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
                      borderRadius: BorderRadius.circular(12)),
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
                      Text(q.text,
                          style: const TextStyle(fontSize: 15, height: 1.3)),
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

/// A score that counts up to its new value, so a change is seen rather
/// than blinked past. Jumps when motion is turned down.
class LiveScore extends StatelessWidget {
  const LiveScore(this.score, {super.key, required this.style});
  final int score;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (liveStill(context)) return Text('$score', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: score.toDouble()),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// The quiz's board: a podium for the first three, the rest as a ranked
/// list, and the player's own row always there — pinned under the list
/// when they are too far down to be on it.
///
/// Ranks come from the server (`live/board.py`): tied players share a
/// rank, so two firsts both read 1 and the next is 3. Nothing here
/// renumbers them.
class QuizLeaderboard extends StatefulWidget {
  const QuizLeaderboard({
    super.key,
    required this.board,
    this.me,
    this.myRank,
    this.myScore,
  });

  final List<BoardEntry> board;

  /// The player's name, to pick out their row.
  final String? me;

  /// Where the player is, for the pinned row when the board does not
  /// reach them.
  final int? myRank;
  final int? myScore;

  @override
  State<QuizLeaderboard> createState() => _QuizLeaderboardState();
}

class _QuizLeaderboardState extends State<QuizLeaderboard> {
  /// Where each name was last build, to say which way it moved.
  Map<String, int> _was = const {};

  @override
  void initState() {
    super.initState();
    _was = {for (final e in widget.board) e.name: e.rank};
  }

  @override
  void didUpdateWidget(QuizLeaderboard old) {
    super.didUpdateWidget(old);
    if (!identical(old.board, widget.board)) {
      _was = {for (final e in old.board) e.name: e.rank};
    }
  }

  /// -1 climbed, 1 dropped, 0 unchanged or new.
  int _moved(BoardEntry e) {
    final before = _was[e.name];
    if (before == null || before == e.rank) return 0;
    return e.rank < before ? -1 : 1;
  }

  bool _isMe(BoardEntry e) => widget.me != null && e.name == widget.me;

  @override
  Widget build(BuildContext context) {
    final board = widget.board;
    final myRank = widget.myRank;
    if (board.isEmpty) {
      return myRank == null
          ? const SizedBox.shrink()
          : _MyRow(
              rank: myRank,
              name: widget.me ?? 'You',
              score: widget.myScore ?? 0,
            );
    }
    final onBoard = board.any(_isMe);
    final podium = board.take(3).toList();
    final rest = board.length > 3 ? board.sublist(3) : const <BoardEntry>[];
    return Semantics(
      container: true,
      label: 'Leaderboard',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Podium(entries: podium, me: widget.me),
          for (final e in rest)
            _BoardRow(
              key: ValueKey('board-${e.name}'),
              entry: e,
              mine: _isMe(e),
              moved: _moved(e),
            ),
          // Always visible, however far down they are.
          if (!onBoard && myRank != null)
            _MyRow(
              rank: myRank,
              name: widget.me ?? 'You',
              score: widget.myScore ?? 0,
              dots: true,
            ),
        ],
      ),
    );
  }
}

/// The first three: three steps, the winner raised and in the middle. No
/// fixed heights, so a long name or the largest system text makes the
/// step taller rather than cutting anything off.
class _Podium extends StatelessWidget {
  const _Podium({required this.entries, this.me});
  final List<BoardEntry> entries;
  final String? me;

  /// Second, first, third — the winner in the middle. With only one or two
  /// players there is no middle, so they stand in order.
  static const _order = [1, 0, 2];

  @override
  Widget build(BuildContext context) {
    final places = entries.length < 3
        ? entries
        : [
            for (final i in _order)
              if (i < entries.length) entries[i],
          ];
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final e in places)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _Step(entry: e, mine: me != null && e.name == me),
              ),
            ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.entry, required this.mine});
  final BoardEntry entry;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    final (tone, tint) = switch (rank) {
      1 => (LiveColors.gold, LiveColors.goldTint),
      2 => (LiveColors.silver, LiveColors.silverTint),
      _ => (LiveColors.bronze, LiveColors.bronzeTint),
    };
    // The stair: the winner's step is the deepest.
    final lift = switch (rank) { 1 => 26.0, 2 => 14.0, _ => 6.0 };
    return Semantics(
      container: true,
      label: '${ordinal(rank)}, ${entry.name}, ${entry.score} points'
          '${mine ? ', you' : ''}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.fromLTRB(6, 10, 6, 10 + lift),
        decoration: BoxDecoration(
          color: mine ? LiveColors.tint : tint,
          border: Border.all(
              color: mine ? LiveColors.deep : tone, width: mine ? 2 : 1),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(12),
            bottom: Radius.circular(4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: mine ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            LiveScore(
              entry.score,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, height: 1.1),
            ),
            // Kept in the layout whether or not it shows, so one step is
            // not taller than the others for carrying it.
            Visibility(
              visible: mine,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: const Text('you',
                  style: TextStyle(fontSize: 11, color: LiveColors.deep)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the rest: rank, name, score, and which way it moved.
class _BoardRow extends StatelessWidget {
  const _BoardRow({
    super.key,
    required this.entry,
    required this.mine,
    this.moved = 0,
  });

  final BoardEntry entry;
  final bool mine;

  /// -1 climbed, 1 dropped, 0 still.
  final int moved;

  @override
  Widget build(BuildContext context) {
    final still = liveStill(context);
    return Semantics(
      container: true,
      label: '${ordinal(entry.rank)}, ${entry.name}, ${entry.score} points'
          '${mine ? ', you' : ''}'
          '${moved == 0 ? '' : moved < 0 ? ', moved up' : ', moved down'}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Duration(milliseconds: still ? 0 : 300),
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? LiveColors.tint : Colors.white,
          border: Border.all(
              color: mine ? LiveColors.deep : LiveColors.line,
              width: mine ? 2 : 1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 24),
              child: Text(
                '${entry.rank}',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            SizedBox(
              width: 20,
              child: moved == 0
                  ? null
                  : Icon(
                      moved < 0
                          ? Icons.arrow_drop_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 20,
                      color: moved < 0 ? LiveColors.right : LiveColors.muted,
                    ),
            ),
            Expanded(
              child: Text(
                mine ? '${entry.name} · you' : entry.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: mine ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            LiveScore(
              entry.score,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// The player's own row, kept where they can always see it.
class _MyRow extends StatelessWidget {
  const _MyRow({
    required this.rank,
    required this.name,
    required this.score,
    this.dots = false,
  });

  final int rank;
  final String name;
  final int score;

  /// A gap above it: the rows between were left out.
  final bool dots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (dots)
          const Padding(
            padding: EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              '· · ·',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 14, letterSpacing: 2, color: LiveColors.muted),
            ),
          ),
        Semantics(
          container: true,
          label: '${ordinal(rank)}, $name, $score points, you',
          excludeSemantics: true,
          child: Container(
            key: const ValueKey('board-me'),
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: LiveColors.tint,
              border: Border.all(color: LiveColors.deep, width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 24),
                  child: Text('$rank',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    '$name · you',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                LiveScore(score,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── The quiz's clock and verdict ───────────────────────────────────────

/// The question's clock: a ring that empties smoothly between the server's
/// seconds, with the number inside it. The ring is tweened over a second,
/// so it slides rather than jumping a step at a time; with motion turned
/// down it steps with the number.
class QuizClock extends StatelessWidget {
  const QuizClock({
    super.key,
    required this.left,
    required this.seconds,
  });

  /// Seconds left.
  final int left;

  /// How long the question had.
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final timeUp = left <= 0;
    final short = !timeUp && left <= 5;
    final tone = timeUp
        ? LiveColors.wrong
        : short
            ? LiveColors.warn
            : LiveColors.deep;
    final span = seconds <= 0 ? 1 : seconds;
    final fraction = (left / span).clamp(0.0, 1.0);
    final still = liveStill(context);
    return Semantics(
      label: timeUp ? 'Time is up' : '$left seconds left',
      excludeSemantics: true,
      child: SizedBox(
        width: 58,
        height: 58,
        child: Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(end: fraction),
              // One second, linear: the ring keeps moving between reads.
              duration: Duration(milliseconds: still ? 0 : 950),
              curve: Curves.linear,
              builder: (context, v, _) => SizedBox(
                width: 58,
                height: 58,
                child: CircularProgressIndicator(
                  value: v,
                  strokeWidth: 5,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation(tone),
                ),
              ),
            ),
            Text(
              timeUp ? 'Time' : '${left}s',
              key: const ValueKey('quiz-clock'),
              style: TextStyle(
                fontSize: timeUp ? 13 : 18,
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// How the answer went, big enough to read from a seat: right or wrong,
/// the points won, and the right answer when it was not this one.
class QuizVerdict extends StatelessWidget {
  const QuizVerdict({
    super.key,
    required this.text,
    required this.tone,
    this.icon,
    this.points,
    this.answer,
    this.note,
  });

  /// "Right — +870", "Not that one", "Answer locked in", "Time is up".
  final String text;
  final Color tone;
  final IconData? icon;

  /// What this answer won, shown as its own badge.
  final int? points;

  /// The right answer's label, when this answer was not it.
  final String? answer;

  /// A line under it: what happens next.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tint = tone == LiveColors.right
        ? LiveColors.rightTint
        : tone == LiveColors.wrong
            ? LiveColors.wrongTint
            : Colors.white;
    return Semantics(
      liveRegion: true,
      container: true,
      label: [
        text,
        if (answer != null) 'The answer was $answer',
        if (note != null) note!,
      ].join('. '),
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: tint,
            border: Border.all(color: tone.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (icon != null) Icon(icon, size: 24, color: tone),
                  Text(
                    text,
                    key: const ValueKey('quiz-verdict'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: tone,
                    ),
                  ),
                  if (points != null && points! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: tone,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '+${points!}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              if (answer != null) ...[
                const SizedBox(height: 8),
                Text(
                  'The answer: $answer',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: LiveColors.ink),
                ),
              ],
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(
                  note!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, height: 1.3, color: LiveColors.muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
