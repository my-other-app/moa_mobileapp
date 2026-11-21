/// The live room's look, per event ("live theme"): what the organiser chose
/// for the big screen, the website and the app, as the server resolves it
/// (`GET /events/{id}/live/theme/public`, and the room's feed's `theme`).
///
/// Read leniently: every field falls back to the Meridian dark preset's
/// value, and an event that never saved a theme ([LiveThemeState.custom]
/// false) is drawn exactly as the room always was.
library;

import 'dart:math' as math;
import 'dart:ui' show Color;

// ─── Contrast (WCAG 2.1, as the server computes it) ─────────────────────

/// Text on a fill: white, the Meridian ink, and black when neither reads.
const liveLight = Color(0xFFFFFFFF);
const liveDark = Color(0xFF111827);
const liveBlack = Color(0xFF000000);

/// AA for text; the minimum for a graphic against what is behind it.
const liveTextContrast = 4.5;
const liveGraphicContrast = 3.0;

double _channel(double s) =>
    s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();

/// Relative luminance, 0 (black) to 1 (white).
double liveLuminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// The contrast ratio of two colours, 1 to 21.
double liveContrast(Color a, Color b) {
  final la = liveLuminance(a), lb = liveLuminance(b);
  final hi = math.max(la, lb), lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// The text colour that reads on every one of [fills]: the better of white
/// and the ink when it reaches AA on all, else black or white if one does.
/// The server's rule (CONTRACT 1.2), for fills the server did not send a
/// text colour for. Black when nothing reaches AA.
Color liveTextOn(List<Color> fills) {
  double worst(Color c) =>
      fills.map((f) => liveContrast(c, f)).fold(double.infinity, math.min);
  final best = worst(liveLight) >= worst(liveDark) ? liveLight : liveDark;
  if (worst(best) >= liveTextContrast) return best;
  for (final c in const [liveBlack, liveLight]) {
    if (worst(c) >= liveTextContrast) return c;
  }
  return liveBlack;
}

/// [colour], darkened (on a light [against]) or lightened (on a dark one)
/// just enough to reach [min] against it: the same hue, readable.
Color liveEnsureContrast(Color colour, Color against, double min) {
  if (liveContrast(colour, against) >= min) return colour;
  final toward = liveLuminance(against) > 0.18 ? liveBlack : liveLight;
  for (var t = 0.05; t < 1; t += 0.05) {
    final c = Color.lerp(colour, toward, t)!;
    if (liveContrast(c, against) >= min) return c;
  }
  return toward;
}

Color? liveHex(Object? v) {
  if (v is! String) return null;
  final m = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(v.trim());
  if (m == null) return null;
  return Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
}

// ─── The theme ──────────────────────────────────────────────────────────

/// How answers are drawn: colour and a shape (the colour-blind-safe
/// default), colour and a letter, or a neutral list.
enum LiveAnswerStyle { shapes, letters, plain }

/// The question's clock: a bar, a ring, a big number, or none at all (the
/// time still runs).
enum LiveTimerStyle { bar, ring, number, hidden }

/// A picture the organiser uploaded (a logo, a background, a poll option's
/// picture), in the sizes the server made: boxes it is fitted inside.
class LiveMedia {
  const LiveMedia({
    this.thumbnail,
    this.medium,
    this.large,
    this.original,
    this.width,
    this.height,
  });

  final String? thumbnail;
  final String? medium;
  final String? large;
  final String? original;
  final int? width;
  final int? height;

  /// What a phone draws a logo or a background with: `medium` (CONTRACT
  /// 1.5), else whatever size there is.
  String? get forPhone => medium ?? large ?? original ?? thumbnail;

  /// For a small slot (a poll option's picture).
  String? get small => thumbnail ?? medium ?? large ?? original;

  static String? _url(Object? v) {
    if (v is! String) return null;
    final s = v.trim();
    return s.startsWith('https://') || s.startsWith('http://') ? s : null;
  }

  static LiveMedia? fromJson(Object? json) {
    if (json is! Map) return null;
    final media = LiveMedia(
      thumbnail: _url(json['thumbnail']),
      medium: _url(json['medium']),
      large: _url(json['large']),
      original: _url(json['original']),
      width: json['width'] is num ? (json['width'] as num).toInt() : null,
      height: json['height'] is num ? (json['height'] as num).toInt() : null,
    );
    return media.forPhone == null ? null : media;
  }
}

/// A background gradient: from one colour to another, at a CSS angle (0 is
/// "to the top", 90 "to the right").
class LiveGradient {
  const LiveGradient({required this.from, required this.to, this.angle = 180});
  final Color from;
  final Color to;
  final int angle;

  /// The colour at the middle of the top edge: [from] for 180° ("to the
  /// bottom"), [to] for 0°, halfway for 90°.
  Color get top {
    final t = (1 + math.cos(angle * math.pi / 180)) / 2;
    return Color.lerp(from, to, t.clamp(0.0, 1.0))!;
  }

  static LiveGradient? fromJson(Object? json) {
    if (json is! Map) return null;
    final from = liveHex(json['from']), to = liveHex(json['to']);
    if (from == null || to == null) return null;
    final a = json['angle'];
    return LiveGradient(
      from: from,
      to: to,
      angle: a is num ? a.toInt() % 360 : 180,
    );
  }
}

/// The resolved theme: every field present (CONTRACT 1.1).
class LiveTheme {
  const LiveTheme({
    this.preset = 'meridian_dark',
    this.background = const Color(0xFF0B0E0D),
    this.accent = const Color(0xFF4FCDB0),
    this.answers = meridianAnswers,
    this.onBackground = liveLight,
    this.onAccent = liveDark,
    this.onAnswers = const [],
    this.displayFont = 'dm_sans',
    this.bodyFont = 'dm_sans',
    this.answerStyle = LiveAnswerStyle.shapes,
    this.timer = LiveTimerStyle.bar,
    this.boardSize = 5,
    this.podium = true,
    this.animate = true,
    this.ownRank = true,
    this.logo,
    this.backgroundKind = 'color',
    this.gradient,
    this.image,
    this.dim = 0.45,
    this.guestTextScale = 1.0,
    this.guestLogo = true,
    this.guestBackground = 'plain',
    this.guestLayout = 'column',
  });

  /// The answer colours of the Meridian presets, A to F.
  static const meridianAnswers = [
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFFD97706),
    Color(0xFF16A34A),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];

  final String preset;
  final Color background;
  final Color accent;

  /// Six answer colours, A to F; a question with n options uses the first n.
  final List<Color> answers;

  /// The server's text colour on each fill (it chooses them, never the
  /// organiser). Computed here by the same rule when a server leaves one out.
  final Color onBackground;
  final Color onAccent;
  final List<Color> onAnswers;

  /// `dm_sans`, `bebas_neue`, `poppins`, `space_grotesk` (see
  /// [liveFontFamily] for the app's file of each).
  final String displayFont;

  /// `dm_sans`, `inter`, `poppins`, `noto_sans`.
  final String bodyFont;
  final LiveAnswerStyle answerStyle;
  final LiveTimerStyle timer;

  /// Rows on the big screen's board; a phone shows what the server sends.
  final int boardSize;

  /// The final board as a 1-2-3 podium.
  final bool podium;

  /// Rows slide and scores count up (never under the phone's reduce-motion).
  final bool animate;
  final bool ownRank;
  final LiveMedia? logo;

  /// `color`, `gradient`, `image`.
  final String backgroundKind;
  final LiveGradient? gradient;
  final LiveMedia? image;

  /// The background colour's overlay over an image, 0.30 to 0.80.
  final double dim;

  /// The phone's text scale, 0.90 to 1.30.
  final double guestTextScale;

  /// The logo at the top of the room and the quiz.
  final bool guestLogo;

  /// `plain`: the phone keeps its own page and uses the colours, fonts and
  /// answers; `theme`: the phone draws the background too.
  final String guestBackground;

  /// `grid` or `column`.
  final String guestLayout;

  /// The text colour on answer [i]'s colour.
  Color onAnswer(int i) {
    final fill = answerColour(i);
    return i < onAnswers.length ? onAnswers[i] : liveTextOn([fill]);
  }

  Color answerColour(int i) => answers[i % answers.length];

  bool get drawsBackground => guestBackground == 'theme';
  bool get grid => guestLayout == 'grid';

  /// The phone's text scale, held to what a phone takes (CONTRACT 1.5).
  double get textScale => guestTextScale.clamp(0.9, 1.3).toDouble();

  static double _num(Object? v, double fallback, double lo, double hi) =>
      v is num ? v.toDouble().clamp(lo, hi).toDouble() : fallback;

  static bool _bool(Object? v, bool fallback) => v is bool ? v : fallback;

  static String _oneOf(Object? v, List<String> allowed, String fallback) =>
      v is String && allowed.contains(v) ? v : fallback;

  static List<Color> _colours(Object? v, List<Color> fallback) {
    if (v is! List) return fallback;
    final out = [for (final c in v) liveHex(c)];
    if (out.length < 2 || out.any((c) => c == null)) return fallback;
    return [for (final c in out) c!];
  }

  static LiveTheme fromJson(Object? json) {
    if (json is! Map) return const LiveTheme();
    Map m(Object? v) => v is Map ? v : const {};
    final colors = m(json['colors']);
    final text = m(json['text']);
    final font = m(json['font']);
    final answers = m(json['answers']);
    final board = m(json['leaderboard']);
    final bg = m(json['background']);
    final guest = m(json['guest']);
    final background = liveHex(colors['background']) ?? const Color(0xFF0B0E0D);
    final accent = liveHex(colors['accent']) ?? const Color(0xFF4FCDB0);
    final fills = _colours(colors['answers'], meridianAnswers);
    final on = text['on_answers'];
    final onAnswers = <Color>[
      for (var i = 0; i < fills.length; i++)
        (on is List && i < on.length ? liveHex(on[i]) : null) ??
            liveTextOn([fills[i]]),
    ];
    final kind = _oneOf(bg['kind'], const ['color', 'gradient', 'image'], 'color');
    final gradient = LiveGradient.fromJson(bg['gradient']);
    final image = LiveMedia.fromJson(bg['image']);
    final size = board['size'];
    return LiveTheme(
      preset: _oneOf(json['preset'],
          const ['meridian_light', 'meridian_dark', 'high_contrast', 'club'],
          'meridian_dark'),
      background: background,
      accent: accent,
      answers: fills,
      onBackground: liveHex(text['on_background']) ?? liveTextOn([background]),
      onAccent: liveHex(text['on_accent']) ?? liveTextOn([accent]),
      onAnswers: onAnswers,
      displayFont: _oneOf(font['display'],
          const ['dm_sans', 'bebas_neue', 'poppins', 'space_grotesk'], 'dm_sans'),
      bodyFont: _oneOf(
          font['body'], const ['dm_sans', 'inter', 'poppins', 'noto_sans'], 'dm_sans'),
      answerStyle: switch (answers['style']) {
        'letters' => LiveAnswerStyle.letters,
        'plain' => LiveAnswerStyle.plain,
        _ => LiveAnswerStyle.shapes,
      },
      timer: switch (json['timer']) {
        'ring' => LiveTimerStyle.ring,
        'number' => LiveTimerStyle.number,
        'hidden' => LiveTimerStyle.hidden,
        _ => LiveTimerStyle.bar,
      },
      boardSize: size == 10 ? 10 : 5,
      podium: _bool(board['podium'], true),
      animate: _bool(board['animate'], true),
      ownRank: _bool(board['own_rank'], true),
      logo: LiveMedia.fromJson(json['logo']),
      // A gradient or a picture that is not there draws the plain colour.
      backgroundKind: kind == 'gradient' && gradient == null ||
              kind == 'image' && image == null
          ? 'color'
          : kind,
      gradient: gradient,
      image: image,
      dim: _num(bg['dim'], 0.45, 0.3, 0.8),
      guestTextScale: _num(guest['text_scale'], 1.0, 0.9, 1.3),
      guestLogo: _bool(guest['logo'], true),
      guestBackground: _oneOf(guest['background'], const ['plain', 'theme'], 'plain'),
      guestLayout: _oneOf(guest['answer_layout'], const ['grid', 'column'], 'column'),
    );
  }
}

/// The theme as the room and the quiz read it: whether the organiser saved
/// one, the theme, and its version (it changes whenever the theme does).
class LiveThemeState {
  const LiveThemeState({
    this.custom = false,
    this.theme = const LiveTheme(),
    this.version,
  });

  /// False: the organiser never saved a theme. The room is then drawn as it
  /// always was, whatever [theme] says (CONTRACT 1.4).
  final bool custom;
  final LiveTheme theme;
  final String? version;

  static LiveThemeState? fromJson(Object? json) {
    if (json is! Map) return null;
    final v = json['version'];
    return LiveThemeState(
      custom: json['custom'] == true,
      theme: LiveTheme.fromJson(json['theme']),
      version: v is String && v.trim().isNotEmpty ? v.trim() : null,
    );
  }
}

/// The app's bundled family for each theme font (CONTRACT 1.5). Every font
/// the contract allows ships with the app, so a phone sets the room in the
/// same face as the website and the big screen:
///
/// | theme key       | family (pubspec)  | file in assets/fonts/                      |
/// |-----------------|-------------------|--------------------------------------------|
/// | `dm_sans`       | `DMSans`          | DMSans-VariableFont_opsz,wght.ttf          |
/// | `bebas_neue`    | `BebasNeue`       | BebasNeue-Regular.ttf (display only)       |
/// | `poppins`       | `Poppins`         | Poppins-{Regular,Medium,SemiBold,Bold}.ttf |
/// | `space_grotesk` | `SpaceGrotesk`    | SpaceGrotesk-Latin-VariableFont_wght.ttf   |
/// | `inter`         | `Inter`           | Inter-Latin-VariableFont_wght.ttf          |
/// | `noto_sans`     | `NotoSans`        | NotoSans-Latin-VariableFont_wght.ttf       |
///
/// The four extra faces are the Google Fonts files cut to Latin (with
/// Latin Extended A, B and Additional, the currency signs and arrows), as
/// the website serves them; a character outside that falls back to the
/// phone's own font. Anything else is drawn in DM Sans, the room's own.
String liveFontFamily(String key) => switch (key) {
      'bebas_neue' => 'BebasNeue',
      'poppins' => 'Poppins',
      'space_grotesk' => 'SpaceGrotesk',
      'inter' => 'Inter',
      'noto_sans' => 'NotoSans',
      _ => 'DMSans',
    };

/// Every family [liveFontFamily] can name.
const liveFontFamilies = {
  'DMSans',
  'BebasNeue',
  'Poppins',
  'SpaceGrotesk',
  'Inter',
  'NotoSans',
};
