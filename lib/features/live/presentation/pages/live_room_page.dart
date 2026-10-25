import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart'
    show readableError;
import 'package:finnet/features/live/data/live_room_api.dart';
import 'package:finnet/features/live/live_routes.dart';
import 'package:finnet/features/live/presentation/cubits/live_room_cubit.dart';
import 'package:finnet/features/live/presentation/widgets/live_widgets.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The event's live room, in the app: the organiser's updates, the poll
/// that is up, questions from the floor, and the way into the quiz.
///
/// Open without an account, as on the website. Kept current while it is on
/// screen: the room's stream when the server has one, else a read every
/// five seconds; nothing while the app is in the background.
class LiveRoomPage extends ConsumerStatefulWidget {
  const LiveRoomPage({super.key, required this.eventRef, this.eventName});

  /// The event's id or slug, as the address has it.
  final String eventRef;

  /// The event's name, shown while the room loads.
  final String? eventName;

  @override
  ConsumerState<LiveRoomPage> createState() => _LiveRoomPageState();
}

class _LiveRoomPageState extends ConsumerState<LiveRoomPage>
    with WidgetsBindingObserver {
  LiveRoomCubit? _cubit;
  LiveRoomState _state = const LiveRoomState();
  String? _resolveError;
  bool _unknownEvent = false;

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
          fallback: 'The live room could not load. Please try again.'));
      return;
    }
    if (!mounted) return;
    if (id == null || id <= 0) {
      setState(() => _unknownEvent = true);
      return;
    }
    final cubit = LiveRoomCubit(api: api, eventId: id)
      ..onStateChanged = (s) {
        if (mounted) setState(() => _state = s);
      };
    setState(() {
      _cubit = cubit;
      _state = cubit.state;
    });
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden) {
      cubit.hidden();
    }
    cubit.start();
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
    super.dispose();
  }

  String? get _signedInName {
    if (!ref.watch(isAuthenticatedProvider)) return null;
    final name = ref.watch(profileProvider).profile?.fullName.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  Future<void> _openQuiz() async {
    final cubit = _cubit;
    if (cubit == null) return;
    // Away from the room while in the quiz: it stops reading, and reads
    // again on the way back.
    cubit.hidden();
    await openLiveRoom(context, cubit.eventId,
        eventName: _state.room?.eventName ?? widget.eventName, quiz: true);
    if (mounted) cubit.shown();
  }

  @override
  Widget build(BuildContext context) {
    final room = _state.room;
    final name = room?.eventName ?? widget.eventName;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live room',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            if (name != null)
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: LiveColors.muted),
              ),
          ],
        ),
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_unknownEvent) {
      return const _Message(
        title: 'This live room isn’t available',
        text: 'The event could not be found.',
      );
    }
    if (_resolveError != null) {
      return _Message(
        title: 'The room could not load',
        text: _resolveError!,
        action: 'Try again',
        onAction: _resolve,
      );
    }
    final cubit = _cubit;
    final room = _state.room;
    if (cubit == null || (room == null && _state.loading)) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Opening the room…'),
          ],
        ),
      );
    }
    if (room == null) {
      if (_state.notFound) {
        return const _Message(
          title: 'This live room isn’t available',
          text: 'The organiser hasn’t opened a live room for this event.',
        );
      }
      return _Message(
        title: 'The room could not load',
        text: _state.loadError ??
            'Please check your connection and try again.',
        action: 'Try again',
        onAction: cubit.refresh,
      );
    }

    final children = <Widget>[
      _StatusLine(live: room.isEventLive, closed: room.isClosed),
      if (room.banner != null) LiveBannerCard(update: room.banner!),
      if (room.quizLive && !room.isClosed)
        QuizEntryCard(title: room.quizTitle, onJoin: _openQuiz),
      if (room.poll != null)
        PollCard(
          key: ValueKey('poll-${room.poll!.id}'),
          poll: room.poll!,
          busy: _state.answering,
          error: _state.pollError,
          closed: room.isClosed,
          onAnswer: cubit.respond,
        ),
      QuestionsSection(
        questions: room.questions,
        canAsk: _state.canAsk,
        approveFirst: room.approveFirst,
        refused: _state.qaRefused,
        asking: _state.asking,
        note: _state.askNote,
        error: _state.askError,
        voting: _state.voting,
        defaultName: _signedInName,
        onAsk: (text, name) => cubit.ask(text, name: name),
        onVote: cubit.toggleVote,
      ),
      if (room.earlier.isNotEmpty) EarlierUpdates(updates: room.earlier),
      if (room.isEmpty) _EmptyRoom(closed: room.isClosed),
    ];
    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.live, required this.closed});
  final bool live;
  final bool closed;

  @override
  Widget build(BuildContext context) {
    if (closed) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Text(
          'The event is over and the live room has closed. What was said '
          'stays here to read.',
          style: TextStyle(fontSize: 13, color: LiveColors.muted),
        ),
      );
    }
    if (!live) return const SizedBox(height: 4);
    return const Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: LiveDot('Live now'),
    );
  }
}

class _EmptyRoom extends StatelessWidget {
  const _EmptyRoom({required this.closed});
  final bool closed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.forum_outlined, size: 40, color: LiveColors.muted),
          const SizedBox(height: 12),
          Text(
            closed ? 'Nothing happened in this room' : 'Nothing in the room yet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            closed
                ? 'The organiser didn’t use the live room for this event.'
                : 'Updates, polls, the quiz and questions from the floor show '
                    'here as the organiser starts them.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: LiveColors.muted),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
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
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
