import 'dart:math' as math;

import 'package:finnet/features/live/domain/live_theme.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:flutter/material.dart';

/// The live room's colours: the event page's LIVE NOW strip's greens, and
/// the app's dark button. The room's own look: what an event that never
/// saved a theme is drawn with ([LiveLook.standard]).
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

  /// The quiz's answer tiles, A to F, as they always were.
  static const answers = [
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFFD97706),
    Color(0xFF16A34A),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];
}

/// The smallest a thing to tap is: 48 by 48.
const double liveTapTarget = 48;

/// Whether the phone asks for less movement (iOS "Reduce Motion", Android
/// "Remove animations"). Everything here that moves checks it first.
bool liveStill(BuildContext context) =>
    (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
    !LiveLook.of(context).animate;

/// The marks on the answer tiles, A to F: shapes for colour-blind players,
/// or letters.
const liveShapes = ['▲', '◆', '●', '■', '★', '✚'];
const liveLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

/// The room's and the quiz's colours, type and choices, from the event's
/// theme (CONTRACT 1) as a phone draws them.
///
/// An event with no theme saved is drawn with [standard]: the room exactly
/// as it was before themes. With one:
///
/// - The page is the phone's own (`guest.background: plain`), or the
///   theme's colour, gradient or picture under its overlay (`theme`). The
///   cards stay light surfaces on it, so every form and line inside reads
///   the same on any theme; only what sits on the page itself takes the
///   server's text colour for the background.
/// - The accent marks what is live (the dot, the timer, highlights, the
///   main buttons), darkened where it would not reach 3:1 (4.5:1 as text)
///   on a card: the same hue, readable.
/// - The answers take the theme's six colours with the server's text
///   colours on them, as shapes, letters or a plain list, in a column or a
///   grid; the clock is a bar, a ring, a number or not drawn.
/// - The display font is the question's, the join code's and the
///   podium's; DM Sans and Bebas Neue ship with the app and the other
///   choices draw in DM Sans (CONTRACT 1.5).
@immutable
class LiveLook {
  const LiveLook({
    required this.id,
    this.custom = false,
    this.page = LiveColors.wash,
    this.backdrop = 'color',
    this.background,
    this.gradient,
    this.image,
    this.dim = 0.45,
    this.onPage = LiveColors.ink,
    this.mutedOnPage = LiveColors.muted,
    this.bar = Colors.white,
    this.onBar,
    this.mutedOnBar = LiveColors.muted,
    this.liveCard = LiveColors.tint,
    this.liveEdge = LiveColors.edge,
    this.accent = LiveColors.deep,
    this.dot = LiveColors.dot,
    this.button = LiveColors.ink,
    this.onButton = Colors.white,
    this.answers = LiveColors.answers,
    this.onAnswers = const [],
    this.answerStyle = LiveAnswerStyle.shapes,
    this.grid = false,
    this.timer = LiveTimerStyle.ring,
    this.podium = true,
    this.animate = true,
    this.displayFamily,
    this.bodyFamily,
    this.textScale = 1.0,
    this.logo,
    this.ownRank = true,
  });

  /// What sets this look apart (the theme's version): a scope rebuilds
  /// what is under it only when it changes.
  final String id;

  /// Drawn from a theme the organiser saved.
  final bool custom;

  /// The page behind the cards, and what is drawn on it: `color`,
  /// `gradient` or `image` (over [page], which shows while a picture loads
  /// or when it cannot).
  final Color page;
  final String backdrop;
  final Color? background;
  final LiveGradient? gradient;
  final String? image;
  final double dim;

  /// Text drawn on the page itself, outside the cards.
  final Color onPage;
  final Color mutedOnPage;

  /// The bar at the top; null [onBar] is the app's own.
  final Color bar;
  final Color? onBar;
  final Color mutedOnBar;

  /// A card of something happening now (the poll, the quiz).
  final Color liveCard;
  final Color liveEdge;

  /// The accent as text and lines on a card (4.5:1).
  final Color accent;

  /// The accent as a dot or a fill on a card (3:1).
  final Color dot;

  /// The main buttons.
  final Color button;
  final Color onButton;

  /// The answer tiles, A to F, and the text on each.
  final List<Color> answers;
  final List<Color> onAnswers;
  final LiveAnswerStyle answerStyle;

  /// Answers two by two rather than one under the other.
  final bool grid;
  final LiveTimerStyle timer;

  /// The board's first three on a podium.
  final bool podium;

  /// Scores count up and rows slide (never under reduce-motion).
  final bool animate;
  final String? displayFamily;
  final String? bodyFamily;

  /// Multiplies the phone's own text size (0.9 to 1.3).
  final double textScale;

  /// The logo's picture for a phone.
  final String? logo;
  final bool ownRank;

  /// The room as it was before themes.
  static const standard = LiveLook(id: 'standard');

  /// The look for [state]: [standard] unless the organiser saved a theme.
  factory LiveLook.from(LiveThemeState? state) {
    if (state == null || !state.custom) return standard;
    final t = state.theme;
    const white = Color(0xFFFFFFFF);
    final liveCard = Color.lerp(white, t.accent, 0.08)!;
    final dot = liveEnsureContrast(t.accent, liveCard, liveGraphicContrast);
    final accent = liveEnsureContrast(t.accent, liveCard, liveTextContrast);
    final onPage = t.drawsBackground ? t.onBackground : LiveColors.ink;
    final bar = t.drawsBackground ? t.background : white;
    final display = liveFontFamily(t.displayFont);
    return LiveLook(
      id: 'theme:${state.version ?? identityHashCode(state)}',
      custom: true,
      page: t.drawsBackground ? t.background : LiveColors.wash,
      backdrop: t.drawsBackground ? t.backgroundKind : 'color',
      background: t.background,
      gradient: t.gradient,
      image: t.image?.forPhone,
      dim: t.dim,
      onPage: onPage,
      // Muted text on the theme's page stays the full text colour: the
      // server only vouches for that one on it.
      mutedOnPage: t.drawsBackground ? onPage : LiveColors.muted,
      bar: bar,
      onBar: t.drawsBackground ? liveTextOn([bar]) : null,
      mutedOnBar: t.drawsBackground ? liveTextOn([bar]) : LiveColors.muted,
      liveCard: liveCard,
      liveEdge: Color.lerp(white, dot, 0.45)!,
      accent: accent,
      dot: dot,
      button: dot,
      onButton: dot == t.accent ? t.onAccent : liveTextOn([dot]),
      answers: [for (var i = 0; i < 6; i++) t.answerColour(i)],
      onAnswers: [for (var i = 0; i < 6; i++) t.onAnswer(i)],
      answerStyle: t.answerStyle,
      grid: t.grid,
      timer: t.timer,
      podium: t.podium,
      animate: t.animate,
      displayFamily: display == 'DMSans' ? null : display,
      bodyFamily: liveFontFamily(t.bodyFont),
      textScale: t.textScale,
      logo: t.guestLogo ? t.logo?.forPhone : null,
      ownRank: t.ownRank,
    );
  }

  /// The look under [context]: the page's, or [standard] outside one.
  static LiveLook of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiveLookScope>()?.look ??
      standard;

  Color answerColour(int i) => answers[i % answers.length];

  Color onAnswer(int i) =>
      i < onAnswers.length ? onAnswers[i] : const Color(0xFFFFFFFF);

  /// The mark on answer [i]: its shape or its letter; none in a plain list.
  String? mark(int i) => switch (answerStyle) {
        LiveAnswerStyle.shapes => liveShapes[i % liveShapes.length],
        LiveAnswerStyle.letters => liveLetters[i % liveLetters.length],
        LiveAnswerStyle.plain => null,
      };

  /// [base] in the display font: the question, the join code, the podium.
  /// Bebas Neue is a capitals face, a little smaller to the eye: drawn a
  /// size up with air between the letters.
  TextStyle display(TextStyle base) {
    final family = displayFamily;
    if (family == null) return base;
    if (family == 'BebasNeue') {
      return base.copyWith(
        fontFamily: family,
        fontSize: (base.fontSize ?? 14) * 1.18,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.6,
        height: 1.08,
      );
    }
    return base.copyWith(fontFamily: family);
  }

  @override
  bool operator ==(Object other) => other is LiveLook && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// The look for everything under it.
class LiveLookScope extends InheritedWidget {
  const LiveLookScope({super.key, required this.look, required super.child});
  final LiveLook look;

  @override
  bool updateShouldNotify(LiveLookScope old) => old.look != look;
}

/// The phone's text size times the theme's: a person's own large text stays
/// large, and the organiser's scale only moves it within what a phone takes.
class LiveTextScaler extends TextScaler {
  const LiveTextScaler(this.base, this.factor);
  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize * factor);

  @override
  double get textScaleFactor => base.scale(14) / 14 * factor;

  @override
  bool operator ==(Object other) =>
      other is LiveTextScaler && other.base == base && other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);
}

/// A page of the room in [look]: its scope and its text size. The page's
/// own body goes in [LiveBackdrop] (under the Scaffold, where the body
/// font can take).
class LiveThemed extends StatelessWidget {
  const LiveThemed({super.key, required this.look, required this.child});
  final LiveLook look;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var body = child;
    final media = MediaQuery.maybeOf(context);
    if (look.textScale != 1.0 && media != null) {
      body = MediaQuery(
        data: media.copyWith(
            textScaler: LiveTextScaler(media.textScaler, look.textScale)),
        child: body,
      );
    }
    return LiveLookScope(look: look, child: body);
  }
}

/// The page's background in the event's look: its colour, gradient or
/// picture (under the colour's overlay, so text on it reads; the plain
/// colour while it loads or when it cannot), and the body font.
class LiveBackdrop extends StatelessWidget {
  const LiveBackdrop({super.key, required this.child});
  final Widget child;

  /// A CSS angle (0 "to the top", 90 "to the right") as where a gradient
  /// begins and ends.
  static (Alignment, Alignment) ends(int angle) {
    final a = angle * math.pi / 180;
    final x = math.sin(a), y = -math.cos(a);
    return (Alignment(-x, -y), Alignment(x, y));
  }

  @override
  Widget build(BuildContext context) {
    final look = LiveLook.of(context);
    var body = child;
    if (look.bodyFamily != null) {
      body = DefaultTextStyle.merge(
        style: TextStyle(fontFamily: look.bodyFamily),
        child: body,
      );
    }
    final gradient = look.gradient;
    final image = look.image;
    Decoration? decoration;
    if (look.backdrop == 'gradient' && gradient != null) {
      final (begin, end) = ends(gradient.angle);
      decoration = BoxDecoration(
        gradient: LinearGradient(
            begin: begin, end: end, colors: [gradient.from, gradient.to]),
      );
    } else if (look.backdrop == 'image' && image != null) {
      final overlay = (look.background ?? look.page).withValues(alpha: look.dim);
      decoration = BoxDecoration(
        color: look.page,
        image: DecorationImage(
          image: appImageProvider(image, decodeWidth: screenDecodeWidth(context)),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(overlay, BlendMode.srcOver),
          onError: (_, __) {},
        ),
      );
    }
    if (decoration == null) return body;
    return DecoratedBox(
      key: const ValueKey('live-backdrop'),
      decoration: decoration,
      child: body,
    );
  }
}

/// The organiser's logo at the top of the room and the quiz, when the
/// theme shows one on phones. Nothing when it cannot load.
class LiveLogo extends StatelessWidget {
  const LiveLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final url = LiveLook.of(context).logo;
    if (url == null) return const SizedBox.shrink();
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 56, maxWidth: 200),
            child: AppNetworkImage(
              key: const ValueKey('live-logo'),
              url: url,
              height: 56,
              fit: BoxFit.contain,
              placeholder: (_) => const SizedBox(height: 56),
              errorWidget: (_) => const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}
