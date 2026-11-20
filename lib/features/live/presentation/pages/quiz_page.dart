import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart'
    show readableError;
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/domain/live_theme.dart';
import 'package:finnet/features/live/presentation/cubits/quiz_cubit.dart';
import 'package:finnet/features/live/presentation/widgets/live_widgets.dart';
import 'package:finnet/features/live/presentation/widgets/quiz_inputs.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The quiz on the screen, played on the phone: join with the code and a
/// name, then each question with its clock, the verdict, and the board.
///
/// Every kind of question has its own input (one tap; several picks to
/// lock in; a typed answer; rows to put in order), drawn in the event's
/// look ([theme], then whatever the quiz says); an event with no look of
/// its own is drawn as the quiz always was.
class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({
    super.key,
    required this.eventRef,
    this.eventName,
    this.theme,
  });

  /// The event's id or slug, as the address has it.
  final String eventRef;
  final String? eventName;

  /// The room's look, when the room opened the quiz.
  final LiveThemeState? theme;

  @override
  ConsumerState<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends ConsumerState<QuizPage>
    with WidgetsBindingObserver {
  QuizCubit? _cubit;
  QuizViewState _state = const QuizViewState();
  String? _resolveError;
  bool _unknownEvent = false;

  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _namePrefilled = false;
  String? _codePrefilled;

  /// The look the page is drawn in, worked out in [build]: the methods
  /// below build under the page's scope but run with the page's own
  /// context, which is above it.
  LiveLook _look = LiveLook.standard;

  /// The question last announced to a screen reader, and whether it was
  /// paused when it was.
  String? _announced;
  bool _announcedPause = false;

  @override
  void initState() {
    super.initState();
    _state = QuizViewState(theme: widget.theme);
    WidgetsBinding.instance.addObserver(this);
    _resolve();
  }

  Future<void> _resolve() async {
    setState(() {
      _resolveError = null;
      _unknownEvent = false;
    });
    final api = ref.read(liveRoomApiProvider);
    int? id;
    try {
      id = await api.resolveEventId(widget.eventRef);
    } catch (e) {
      if (!mounted) return;
      setState(() => _resolveError = readableError(e,
          fallback: 'The quiz could not load. Please try again.'));
      return;
    }
    if (!mounted) return;
    if (id == null || id <= 0) {
      setState(() => _unknownEvent = true);
      return;
    }
    final cubit = QuizCubit(
      api: api,
      identity: ref.read(liveIdentityProvider),
      eventId: id,
      theme: widget.theme,
    )..onStateChanged = _onState;
    setState(() {
      _cubit = cubit;
      _state = cubit.state;
    });
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden) {
      cubit.hidden();
    }
    await cubit.start();
  }

  void _onState(QuizViewState next) {
    if (!mounted) return;
    setState(() => _state = next);
    final code = next.suggestedCode;
    if (code != null && code != _codePrefilled) {
      _codePrefilled = code;
      _code.text = code;
    }
    final q = next.question;
    final quiz = next.quiz;
    final view = View.maybeOf(context);
    if (q != null && quiz != null && view != null) {
      String? say;
      if (q.id != _announced) {
        _announced = q.id;
        say = 'Question ${quiz.currentIndex + 1} of ${quiz.total}. ${q.prompt}';
      } else if (quiz.isPaused != _announcedPause) {
        say = quiz.isPaused
            ? 'The host paused the question.'
            : 'The question is back on.';
      }
      _announcedPause = quiz.isPaused;
      if (say != null) {
        SemanticsService.sendAnnouncement(
            view, say, Directionality.of(context));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _cubit?.shown();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _cubit?.hidden();
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cubit?.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  void _prefillName() {
    if (_namePrefilled || !ref.watch(isAuthenticatedProvider)) return;
    final name = ref.watch(profileProvider).profile?.fullName.trim() ?? '';
    if (name.isEmpty) return;
    _namePrefilled = true;
    // After this frame: the field's listeners rebuild, which may not happen
    // during a build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _name.text.isEmpty) {
        _name.text = name.length > 60 ? name.substring(0, 60) : name;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = _state.quiz?.title ?? widget.eventName;
    final look = _look = LiveLook.from(_state.theme ?? widget.theme);
    return LiveThemed(
      look: look,
      child: Scaffold(
        backgroundColor: look.page,
        appBar: AppBar(
          backgroundColor: look.bar,
          surfaceTintColor: look.bar,
          foregroundColor: look.onBar,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quiz',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              if (title != null && title.isNotEmpty)
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: look.mutedOnBar)),
            ],
          ),
        ),
        body: LiveBackdrop(child: SafeArea(child: _body(context))),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_unknownEvent) {
      return const _Centered(
        title: 'This quiz isn’t available',
        text: 'The event could not be found.',
      );
    }
    if (_resolveError != null) {
      return _Centered(
        title: 'The quiz could not load',
        text: _resolveError!,
        action: 'Try again',
        onAction: _resolve,
      );
    }
    final cubit = _cubit;
    if (cubit == null || _state.phase == QuizPhase.checking) {
      return const Center(child: CircularProgressIndicator());
    }
    switch (_state.phase) {
      case QuizPhase.checking:
        return const Center(child: CircularProgressIndicator());
      case QuizPhase.join:
        _prefillName();
        return _join(cubit);
      case QuizPhase.gone:
        return _Centered(
          title: 'That quiz has moved on',
          text: 'Join again with the code on the screen.',
          action: 'Join again',
          onAction: cubit.joinAgain,
        );
      case QuizPhase.playing:
        return _playing(cubit);
    }
  }

  Widget _join(QuizCubit cubit) {
    final look = _look;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const LiveLogo(),
        LiveCard(
          live: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LiveDot('Quiz', beat: true),
              const SizedBox(height: 8),
              Semantics(
                header: true,
                child: Text(
                    _state.suggestedCode != null
                        ? 'Join the next round'
                        : 'Join the quiz',
                    style: look.display(const TextStyle(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w800))),
              ),
              const SizedBox(height: 6),
              const Text(
                'Type the code on the screen and your name. Fast right '
                'answers score most.',
                style: TextStyle(
                    fontSize: 13.5, height: 1.4, color: LiveColors.muted),
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('quiz-code'),
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 8,
                autofocus: true,
                style: look.display(
                    const TextStyle(fontSize: 24, letterSpacing: 6)),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                  labelText: 'Code on the screen',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('quiz-name'),
                controller: _name,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                  labelText: 'Your name for the quiz',
                ),
              ),
              const SizedBox(height: 16),
              ListenableBuilder(
                listenable: Listenable.merge([_code, _name]),
                builder: (context, _) => FilledButton(
                  onPressed: _state.joining ||
                          _code.text.trim().length < 4 ||
                          _name.text.trim().isEmpty
                      ? null
                      : () => cubit.join(_code.text, _name.text),
                  style: liveButtonStyle(
                    look,
                    minimumSize: const Size.fromHeight(56),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: _state.joining
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: look.custom ? look.onButton : Colors.white),
                        )
                      : const Text('Join the quiz'),
                ),
              ),
              if (_state.joinError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(_state.joinError!,
                        style: const TextStyle(color: LiveColors.wrong)),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _playing(QuizCubit cubit) {
    final quiz = _state.quiz;
    final children = <Widget>[const LiveLogo()];
    if (_state.connectionLost) {
      children.add(const LiveConnectionBar());
    }
    if (_state.nextRound != null) {
      children.add(LiveWaiting(
        icon: Icons.replay_rounded,
        title: 'Joining ${_state.nextRound}…',
        text: 'A new round has started. You are going in under the same '
            'name.',
        spinner: true,
        onPage: true,
      ));
    } else if (quiz == null) {
      children.add(const LiveWaiting(
        icon: Icons.quiz_outlined,
        title: 'Finding the quiz…',
        text: 'One moment.',
        spinner: true,
        onPage: true,
      ));
    } else if (quiz.ended || (!quiz.live && quiz.question == null)) {
      children.add(_finished(quiz));
    } else if (quiz.question == null) {
      children.add(_lobby(quiz));
    } else {
      children.addAll(_question(cubit, quiz, quiz.question!));
    }
    if (_state.answerError != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          liveRegion: true,
          child: Text(_state.answerError!,
              style: TextStyle(
                  color: _look.drawsPage
                      ? _look.onPage
                      : LiveColors.wrong)),
        ),
      ));
    }
    // The player's own row stays on the screen while a board is up, however
    // far down they are: the board itself then leaves it out.
    final pinned = _pinnedPlace(quiz);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, pinned == null ? 32 : 12),
            children: children,
          ),
        ),
        if (pinned != null) pinned,
      ],
    );
  }

  /// The strip at the bottom: the player's place, on the screen that is
  /// the board, when they are not on the part of it that is shown. Between
  /// questions the score strip under the answers already carries it, so
  /// there is no strip then.
  Widget? _pinnedPlace(QuizState? quiz) {
    if (quiz == null || quiz.question != null) return null;
    final rank = quiz.rank;
    final boardUp = quiz.ended || !quiz.live;
    if (!boardUp || rank == null) return null;
    if (quiz.leaderboard.any((e) => e.name == quiz.name)) return null;
    return QuizOwnPlace(rank: rank, name: quiz.name, score: quiz.score);
  }

  Widget _finished(QuizState quiz) {
    final look = _look;
    final rank = quiz.rank;
    final between = quiz.ended && quiz.moreRounds;
    final overall = quiz.overall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LiveCard(
          live: quiz.ended,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quiz.ended) ...[
                LiveDot(between ? 'Round over' : 'Quiz over',
                    beat: between),
                const SizedBox(height: 8),
              ],
              Semantics(
                header: true,
                child: Text(
                  !quiz.ended
                      ? 'The host has not started yet'
                      : between
                          ? 'That is round ${quiz.roundIndex + 1} of '
                              '${quiz.roundCount}'
                          : 'That is the quiz',
                  style: look.display(const TextStyle(
                      fontSize: 22, height: 1.2, fontWeight: FontWeight.w800)),
                ),
              ),
              if (rank != null) ...[
                const SizedBox(height: 10),
                Text(
                  'You came ${ordinal(rank)} with ${quiz.score} points.',
                  style: const TextStyle(
                      fontSize: 16, height: 1.3, fontWeight: FontWeight.w600),
                ),
              ],
              if (between) ...[
                const SizedBox(height: 10),
                const Text(
                  'Stay on this screen: when the next round starts you go '
                  'straight in, under the same name.',
                  style: TextStyle(
                      fontSize: 13.5, height: 1.4, color: LiveColors.muted),
                ),
              ],
              if (quiz.team != null) ...[
                const SizedBox(height: 10),
                QuizTeamChip(team: quiz.team!),
              ],
            ],
          ),
        ),
        if (quiz.teams?.isNotEmpty ?? false)
          QuizTeamBoard(teams: quiz.teams!, mine: quiz.team?.key),
        if (quiz.leaderboard.isNotEmpty || rank != null) _board(quiz),
        if (overall != null && overall.isNotEmpty)
          LiveCard(
            key: const ValueKey('quiz-overall'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LiveHeading('Across all rounds'),
                QuizLeaderboard(
                  board: overall,
                  me: quiz.name,
                  showOwnRow: false,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// The board, in its own card: the podium, the rest, and this player's
  /// row wherever they are.
  Widget _board(QuizState quiz) {
    return LiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const Text('Leaderboard',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const Text('Tied players share a place.',
              style: TextStyle(fontSize: 12.5, color: LiveColors.muted)),
          QuizLeaderboard(
            board: quiz.leaderboard,
            me: quiz.name,
            myRank: quiz.rank,
            myScore: quiz.score,
            // The page pins it to the bottom of the screen instead.
            showOwnRow: _pinnedPlace(quiz) == null,
          ),
        ],
      ),
    );
  }

  Widget _lobby(QuizState quiz) {
    final look = _look;
    return LiveCard(
      live: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LiveDot(
              quiz.hasRounds
                  ? 'Round ${quiz.roundIndex + 1} of ${quiz.roundCount}'
                  : 'In the quiz',
              beat: true),
          const SizedBox(height: 10),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              'You are in, ${quiz.name}',
              style: look.display(const TextStyle(
                  fontSize: 22, height: 1.2, fontWeight: FontWeight.w800)),
            ),
          ),
          if (quiz.team != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: QuizTeamChip(team: quiz.team!, prefix: 'Your team:'),
            ),
          ],
          const SizedBox(height: 14),
          const LiveWaiting(
            icon: Icons.hourglass_empty_rounded,
            title: 'Waiting for the host to start',
            text: 'Watch the screen — the first question lands here.',
            spinner: true,
          ),
          Text(
            '${quiz.total} ${quiz.total == 1 ? 'question' : 'questions'} '
            '${quiz.hasRounds ? 'in this round' : 'tonight'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: LiveColors.muted),
          ),
        ],
      ),
    );
  }

  /// "Question 3 of 10", the round, and what it is worth when that is not
  /// the usual.
  Widget _header(QuizState quiz, QuizQuestion q) {
    final look = _look;
    final points = q.effectivePoints;
    final badges = <String>[
      if (q.doublePoints) 'Double points',
      if (points != null && (points != 1000 || q.doublePoints))
        '$points points',
      if (quiz.streak >= 2) '${quiz.streak} in a row',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Question ${quiz.currentIndex + 1} of ${quiz.total}'
          '${quiz.hasRounds ? ' · Round ${quiz.roundIndex + 1} of ${quiz.roundCount}' : ''}',
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: look.accent),
        ),
        if (badges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final b in badges) _Badge(b)],
            ),
          ),
      ],
    );
  }

  List<Widget> _question(QuizCubit cubit, QuizState quiz, QuizQuestion q) {
    final look = _look;
    final left = _state.left;
    final timeUp = left <= 0;
    final paused = quiz.isPaused;
    final revealed = quiz.revealedNow;
    final right = q.wasRight;
    final points = q.myPoints ?? _state.flash?.points;
    final enabled = !_state.answersClosed;
    final verdict = _verdict(quiz, q, timeUp: timeUp, points: points);
    final sideClock = look.timer == LiveTimerStyle.ring ||
        look.timer == LiveTimerStyle.number;
    final clock = QuizTimer(left: left, seconds: q.seconds, paused: paused);
    // The board between questions: once this one's clock is out (an older
    // server), or when the round says the board is up now.
    final boardUp = quiz.boardNow ?? timeUp;
    return [
      LiveCard(
        live: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _header(quiz, q),
                      const SizedBox(height: 10),
                      Semantics(
                        header: true,
                        child: Text(
                          q.prompt,
                          style: look.display(const TextStyle(
                              fontSize: 23,
                              height: 1.22,
                              fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (sideClock) ...[const SizedBox(width: 12), clock],
              ],
            ),
            if (look.timer == LiveTimerStyle.bar) ...[
              const SizedBox(height: 14),
              clock,
            ],
            if (paused) const _PausedLine(),
            const SizedBox(height: 18),
            _input(cubit, q, revealed: revealed, enabled: enabled),
            if (verdict != null) verdict,
            if (q.kind == QuizKind.poll && revealed && q.counts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: QuizTally(question: q),
              ),
            if (revealed && quiz.nextAt != null)
              QuizNextIn(at: quiz.nextAt!),
            const SizedBox(height: 14),
            _ScoreStrip(
              score: quiz.score,
              rank: quiz.rank,
              gained: right == true || q.partlyRight ? points : null,
              team: quiz.team,
            ),
          ],
        ),
      ),
      if (boardUp && (quiz.teams?.isNotEmpty ?? false))
        QuizTeamBoard(teams: quiz.teams!, mine: quiz.team?.key),
      if (boardUp && (quiz.leaderboard.isNotEmpty || quiz.rank != null))
        _board(quiz),
    ];
  }

  Widget _input(QuizCubit cubit, QuizQuestion q,
      {required bool revealed, required bool enabled}) {
    switch (q.kind) {
      case QuizKind.single:
      case QuizKind.trueFalse:
      case QuizKind.poll:
        return QuizOneTapInput(
          question: q,
          revealed: revealed,
          enabled: enabled,
          onAnswer: cubit.answer,
        );
      case QuizKind.multi:
        return QuizMultiInput(
          key: ValueKey('multi-${q.id}'),
          question: q,
          revealed: revealed,
          enabled: enabled,
          onAnswer: (keys) => cubit.submit(OptionsAnswer(keys)),
        );
      case QuizKind.type:
        return QuizTypeInput(
          key: ValueKey('type-${q.id}'),
          question: q,
          enabled: enabled,
          onAnswer: (text) => cubit.submit(TextAnswer(text)),
        );
      case QuizKind.order:
        return QuizOrderInput(
          key: ValueKey('order-${q.id}'),
          question: q,
          revealed: revealed,
          enabled: enabled,
          onAnswer: (keys) => cubit.submit(OrderAnswer(keys)),
        );
      case QuizKind.unknown:
        return const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text(quizNeedsUpdate,
              key: ValueKey('quiz-needs-update'),
              style: TextStyle(
                  fontSize: 15, height: 1.4, color: LiveColors.muted)),
        );
    }
  }

  /// The right answer, in words, once it is out.
  (String, String)? _rightAnswer(QuizQuestion q) {
    switch (q.kind) {
      case QuizKind.multi:
        final keys = q.correctKeys;
        if (keys == null || keys.isEmpty) return null;
        return (
          keys.length == 1 ? 'The answer' : 'The answers',
          keys.map(q.labelOf).join(', '),
        );
      case QuizKind.type:
        final accepted = q.accepted;
        if (accepted == null || accepted.isEmpty) return null;
        return (
          'The answer',
          accepted.length == 1
              ? accepted.first
              : '${accepted.first} (also: ${accepted.skip(1).join(', ')})',
        );
      case QuizKind.order:
        final order = q.correctOrder;
        if (order == null || order.isEmpty) return null;
        return ('The order', order.map(q.labelOf).join(' → '));
      case QuizKind.poll:
      case QuizKind.unknown:
        return null;
      case QuizKind.single:
      case QuizKind.trueFalse:
        final key = q.correctKey;
        if (key == null) return null;
        final label = q.options.where((o) => o.key == key).firstOrNull?.label;
        return label == null ? null : ('The answer', label);
    }
  }

  Widget? _verdict(QuizState quiz, QuizQuestion q,
      {required bool timeUp, required int? points}) {
    final right = q.wasRight;
    final revealed = quiz.revealedNow;
    final answer = _rightAnswer(q);
    if (quiz.isPaused && !q.answered) return null;
    if (q.kind == QuizKind.poll && q.answered) {
      return QuizVerdict(
        text: revealed ? 'Thanks for answering' : 'Answer locked in',
        tone: _look.accent,
        icon: revealed ? Icons.how_to_vote_rounded : Icons.lock_outline_rounded,
        note: revealed && q.counts.isEmpty
            ? 'A poll: no points. The room’s answers are on the screen.'
            : 'A poll: no points for this one.',
      );
    }
    if (q.answered && right != null) {
      final partly = q.partlyRight;
      final lost = points != null && points < 0;
      return QuizVerdict(
        text: right
            ? 'Right${points != null && points > 0 ? ' — +$points' : ''}'
            : partly
                ? 'Partly right${points != null && points > 0 ? ' — +$points' : ''}'
                : 'Not that one${lost ? ' — −${-points}' : ''}',
        tone: right
            ? LiveColors.right
            : partly
                ? LiveColors.warnInk
                : LiveColors.wrong,
        icon: right
            ? Icons.check_circle_rounded
            : partly
                ? Icons.adjust_rounded
                : Icons.cancel_rounded,
        answer: right ? null : answer?.$2,
        answerTitle: answer?.$1 ?? 'The answer',
        note: lost ? 'Wrong answers cost points in this quiz.' : null,
      );
    }
    if (q.answered) {
      return QuizVerdict(
        text: 'Answer locked in',
        tone: _look.accent,
        icon: Icons.lock_outline_rounded,
        note: quiz.waitingForReveal
            ? 'The host will show the answer in a moment.'
            : 'You’ll see if you were right when time is up.',
      );
    }
    if (timeUp || quiz.waitingForReveal || revealed) {
      return QuizVerdict(
        text: 'Time is up',
        tone: LiveColors.wrong,
        icon: Icons.timer_off_rounded,
        answer: answer?.$2,
        answerTitle: answer?.$1 ?? 'The answer',
        note: q.kind == QuizKind.unknown
            ? null
            : quiz.waitingForReveal
                ? 'No answer from you this time. The host will show the '
                    'answer in a moment.'
                : 'No answer from you this time.',
      );
    }
    return null;
  }
}

/// "Paused by the host": the clock stands still and answers wait.
class _PausedLine extends StatelessWidget {
  const _PausedLine();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Paused. The host stopped the clock; answers open again when it '
          'restarts.',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('quiz-paused'),
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: LiveColors.warnTint,
          border: Border.all(color: LiveColors.warnEdge),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.pause_circle_filled_rounded, color: LiveColors.warn),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Paused by the host — the clock has stopped. Answers open '
                'again when it restarts.',
                style: TextStyle(
                    fontSize: 13.5, height: 1.35, color: LiveColors.warnInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: look.liveEdge),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: look.accent)),
    );
  }
}

/// Where the player stands under the question: the score, counting up to
/// its new total, what the last answer added, the place, and the team.
class _ScoreStrip extends StatelessWidget {
  const _ScoreStrip({required this.score, this.rank, this.gained, this.team});
  final int score;
  final int? rank;
  final int? gained;
  final QuizTeam? team;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: [
        '$score points',
        if (gained != null && gained! > 0) 'up $gained',
        if (rank != null) '${ordinal(rank!)} right now',
        if (team != null) 'team ${team!.name}',
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: LiveColors.edge),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LiveScore(
                    score,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 5),
                  const Flexible(
                    child: Text('points',
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 14, color: LiveColors.muted)),
                  ),
                ],
              ),
              if (gained != null && gained! > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: LiveColors.right,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+$gained',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              if (rank != null)
                Text('${ordinal(rank!)} right now',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              if (team != null) QuizTeamChip(team: team!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.title,
    required this.text,
    this.action,
    this.onAction,
  });

  final String title;
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: look.custom ? look.onPage : null)),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: look.mutedOnPage)),
            if (action != null) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: onAction,
                style: liveButtonStyle(look,
                    minimumSize: const Size(160, liveTapTarget)),
                child: Text(action!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
