import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/core/config/app_config.dart';
import 'package:finnet/features/events/presentation/utils/event_errors.dart';
import 'package:finnet/features/games/data/games_api.dart';
import 'package:finnet/features/games/domain/games.dart';
import 'package:finnet/shared/utils/external_links.dart';

/// Which games event [eventId] has on, by the server's public card; none
/// when it has none or cannot be asked.
final eventGamesProvider = FutureProvider.autoDispose.family<EventGames, int>((
  ref,
  eventId,
) async {
  if (eventId <= 0) return EventGames.none;
  return ref.watch(gamesApiProvider).fetchPublic(eventId);
});

/// The address that opens the games for the event with [slug] already
/// signed in (never its id: `/play/<number>` is the live quiz): the website takes the session in the
/// fragment and clears it at once, so it never reaches the server.
Uri gameLinkFor(String slug, String token) => Uri.parse(
      '${AppConfig.publicSiteUrl}/play/${Uri.encodeComponent(slug)}'
      '#gs=${Uri.encodeComponent(token)}',
    );

/// How one game's button is drawn: its [offer], whether its session is
/// being made, and what a tap does (null while another is in flight).
typedef GameButtonBuilder = Widget Function(
  BuildContext context,
  GameOffer offer,
  bool busy,
  VoidCallback? onPressed,
);

/// "Play (game name)", one button per game the event has switched on, for
/// anyone registered. Nothing at all while it loads or when there are none.
///
/// A tap asks for a game session, then opens the website's game page in the
/// app's browser view. A refusal -- not checked in yet, the club's plan --
/// is said in the server's own words; offline, in the app's usual offline
/// words. The session token goes nowhere but that address.
class GamePlayButtons extends ConsumerStatefulWidget {
  const GamePlayButtons({
    super.key,
    required this.eventId,
    this.eventRef,
    this.padding = const EdgeInsets.only(top: 10),
    this.buttonBuilder,
  });

  final int eventId;

  /// The event's slug, when the screen knows it (the server's public card
  /// carries it too). An id is never used.
  final String? eventRef;

  final EdgeInsetsGeometry padding;

  /// Draws each button in the host screen's own style; the event page's
  /// outlined button when null.
  final GameButtonBuilder? buttonBuilder;

  static Key buttonKey(GameKind kind) => ValueKey('play-game-${kind.name}');

  @override
  ConsumerState<GamePlayButtons> createState() => _GamePlayButtonsState();
}

class _GamePlayButtonsState extends ConsumerState<GamePlayButtons> {
  GameKind? _opening;

  Future<void> _play(GameOffer offer) async {
    if (_opening != null) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final launch = ref.read(linkLauncherProvider);
    final api = ref.read(gamesApiProvider);
    final slug = ref
        .read(eventGamesProvider(widget.eventId))
        .valueOrNull
        ?.slugOr(widget.eventRef);
    if (slug == null) return;
    setState(() => _opening = offer.kind);
    String? problem;
    try {
      final session = await api.createSession(widget.eventId);
      final opened = await launch(gameLinkFor(slug, session.token));
      if (!opened) problem = "Couldn't open the game. Please try again.";
    } catch (e) {
      problem = readableError(
        e,
        fallback: "Couldn't start the game. Please try again.",
      );
    }
    if (mounted) setState(() => _opening = null);
    if (problem != null) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(problem)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final games = ref.watch(eventGamesProvider(widget.eventId)).valueOrNull;
    // No slug, no way in: the games' address is the slug, never the id.
    if (games == null ||
        games.isEmpty ||
        games.slugOr(widget.eventRef) == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: widget.padding,
      child: Column(
        children: [
          for (final offer in games.offers)
            Padding(
              padding: EdgeInsets.only(
                top: offer == games.offers.first ? 0 : 10,
              ),
              child: (widget.buttonBuilder ?? _outlined)(
                context,
                offer,
                _opening == offer.kind,
                _opening == null ? () => _play(offer) : null,
              ),
            ),
        ],
      ),
    );
  }

  /// The event page's button: outlined, in its dark ink.
  Widget _outlined(
    BuildContext context,
    GameOffer offer,
    bool busy,
    VoidCallback? onTap,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: GamePlayButtons.buttonKey(offer.kind),
        onPressed: onTap,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(gameIcon(offer.kind), size: 18),
        label: Text(offer.label),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2C333D),
          side: const BorderSide(color: Color(0xFF2C333D)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

/// The icon for a game's button.
IconData gameIcon(GameKind kind) =>
    kind == GameKind.cards ? Icons.style_outlined : Icons.travel_explore;
