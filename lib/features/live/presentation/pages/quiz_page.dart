import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart'
    show readableError;
import 'package:finnet/features/live/data/live_identity.dart';
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/domain/live_quiz.dart';
import 'package:finnet/features/live/presentation/cubits/quiz_cubit.dart';
import 'package:finnet/features/live/presentation/widgets/live_widgets.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The quiz on the screen, played on the phone: join with the code and a
/// name, then each question with its clock, the verdict, and the board.
class QuizPage extends ConsumerStatefulWidget {
  const QuizPage({super.key, required this.eventRef, this.eventName});

  /// The event's id or slug, as the address has it.
  final String eventRef;
  final String? eventName;

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

  /// The question last announced to a screen reader.
  String? _announced;

  @override
  void initState() {
    super.initState();
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
    final q = next.question;
    final quiz = next.quiz;
    if (q != null && quiz != null && q.id != _announced) {
      _announced = q.id;
      final view = View.maybeOf(context);
      if (view != null) {
        SemanticsService.sendAnnouncement(
          view,
          'Question ${quiz.currentIndex + 1} of ${quiz.total}. ${q.prompt}',
          Directionality.of(context),
        );
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
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Quiz',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (title != null && title.isNotEmpty)
              Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontSize: 12, color: LiveColors.muted)),
          ],
        ),
      ),
      body: SafeArea(child: _body(context)),
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
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LiveCard(
          live: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LiveDot('Quiz'),
              const SizedBox(height: 6),
              Semantics(
                header: true,
                child: const Text('Join the quiz',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Type the code on the screen and your name. Fast right '
                'answers score most.',
                style: TextStyle(fontSize: 13, color: LiveColors.muted),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('quiz-code'),
                controller: _code,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 8,
                autofocus: true,
                style: const TextStyle(fontSize: 24, letterSpacing: 6),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: LiveColors.ink,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _state.joining
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
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
    final children = <Widget>[];
    if (_state.connectionLost) {
      children.add(const Padding(
        padding: EdgeInsets.only(bottom: 10),
        child: Text('Lost the room for a moment…',
            style: TextStyle(color: LiveColors.wrong)),
      ));
    }
    if (quiz == null) {
      children.add(const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
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
        child: Text(_state.answerError!,
            style: const TextStyle(color: LiveColors.wrong)),
      ));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: children,
    );
  }

  Widget _finished(QuizState quiz) {
    final rank = quiz.rank;
    return LiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              quiz.ended ? 'That is the quiz' : 'The host has not started yet',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          if (rank != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'You came ${ordinal(rank)} with ${quiz.score} points.',
                style: const TextStyle(fontSize: 15),
              ),
            ),
          const SizedBox(height: 8),
          QuizLeaderboard(board: quiz.leaderboard, me: quiz.name),
        ],
      ),
    );
  }

  Widget _lobby(QuizState quiz) {
    return LiveCard(
      live: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(
              'You are in, ${quiz.name}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Watch the screen — the first question is coming.'),
          const SizedBox(height: 8),
          Text(
            '${quiz.total} ${quiz.total == 1 ? 'question' : 'questions'} '
            'tonight',
            style: const TextStyle(fontSize: 13, color: LiveColors.muted),
          ),
        ],
      ),
    );
  }

  static const _marks = ['▲', '◆', '●', '■', '★', '✚'];
  static const _colours = [
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFFD97706),
    Color(0xFF16A34A),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];

  List<Widget> _question(QuizCubit cubit, QuizState quiz, QuizQuestion q) {
    final left = _state.left;
    final timeUp = left <= 0;
    final right = q.wasRight;
    final reveal = q.revealed;
    final String? verdict;
    final Color verdictColour;
    if (q.answered && right != null) {
      final points = q.myPoints ?? _state.flash?.points;
      verdict = right
          ? 'Right${points != null && points > 0 ? ' — +$points' : ''}'
          : 'Not that one';
      verdictColour = right ? LiveColors.right : LiveColors.wrong;
    } else if (q.answered) {
      verdict = 'Answer locked in';
      verdictColour = LiveColors.deep;
    } else if (timeUp) {
      verdict = 'Time is up';
      verdictColour = LiveColors.wrong;
    } else {
      verdict = null;
      verdictColour = LiveColors.ink;
    }
    return [
      LiveCard(
        live: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Question ${quiz.currentIndex + 1} of ${quiz.total}',
                    style:
                        const TextStyle(fontSize: 13, color: LiveColors.muted),
                  ),
                ),
                Semantics(
                  label: timeUp ? 'Time is up' : '$left seconds left',
                  excludeSemantics: true,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: timeUp ? const Color(0xFFFEE2E2) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: LiveColors.edge),
                    ),
                    child: Text(
                      timeUp ? 'Time' : '${left}s',
                      key: const ValueKey('quiz-clock'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Semantics(
              header: true,
              child: Text(
                q.prompt,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < q.options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnswerButton(
                  option: q.options[i],
                  mark: _marks[i % _marks.length],
                  colour: _colours[i % _colours.length],
                  mine: q.myAnswer == q.options[i].key,
                  right: reveal && q.correctKey == q.options[i].key,
                  wrong: reveal &&
                      q.myAnswer == q.options[i].key &&
                      q.correctKey != q.options[i].key,
                  enabled: !_state.answersClosed,
                  onTap: () => cubit.answer(q.options[i].key),
                ),
              ),
            if (verdict != null)
              Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    verdict,
                    key: const ValueKey('quiz-verdict'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: verdictColour,
                    ),
                  ),
                ),
              ),
            if (q.answered && right == null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'You’ll see if you were right when time is up.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: LiveColors.muted),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('${quiz.score} points',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (quiz.rank != null)
                  Text('${ordinal(quiz.rank!)} right now',
                      style: const TextStyle(fontSize: 15)),
              ],
            ),
          ],
        ),
      ),
      // The board between questions: once this one's clock is out.
      if (timeUp && quiz.leaderboard.isNotEmpty)
        LiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: const Text('Leaderboard',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              QuizLeaderboard(board: quiz.leaderboard, me: quiz.name),
            ],
          ),
        ),
    ];
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.option,
    required this.mark,
    required this.colour,
    required this.mine,
    required this.right,
    required this.wrong,
    required this.enabled,
    required this.onTap,
  });

  final QuizOption option;
  final String mark;
  final Color colour;
  final bool mine;
  final bool right;
  final bool wrong;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = [
      option.label,
      if (mine) 'your answer',
      if (right) 'the right answer',
      if (wrong) 'wrong',
    ].join(', ');
    final background = right
        ? LiveColors.right
        : wrong
            ? LiveColors.wrong
            : colour;
    final dim = !enabled && !mine && !right;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: mine,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: dim ? 0.55 : 1,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('answer-${option.key}'),
            onTap: enabled ? onTap : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: mine
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 3),
                    )
                  : null,
              child: Row(
                children: [
                  Text(mark,
                      style:
                          const TextStyle(fontSize: 20, color: Colors.white)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      option.label,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  if (mine)
                    const Icon(Icons.check_circle, color: Colors.white),
                ],
              ),
            ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: LiveColors.muted)),
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
      ),
    );
  }
}
