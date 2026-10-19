import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';

// How a topic looks: its colour and icon, with fallbacks for a server that
// sends neither (production before the topics migration), and the surface
// colours for light and dark.

/// The default tree's colours (the contract's), for a topic the server sent
/// without one.
const Map<String, int> _defaultColors = {
  'development': 0xFF2563EB,
  'deep-tech': 0xFF7C3AED,
  'design': 0xFFDB2777,
  'arts': 0xFFEA580C,
  'business': 0xFF059669,
  'gaming-media': 0xFFDC2626,
  'community': 0xFF0D9488,
  'sports-fitness': 0xFFCA8A04,
};

const Map<String, IconData> _defaultIcons = {
  'development': Icons.code,
  'deep-tech': Icons.memory,
  'design': Icons.design_services_outlined,
  'arts': Icons.palette_outlined,
  'business': Icons.business_center_outlined,
  'gaming-media': Icons.sports_esports_outlined,
  'community': Icons.groups_outlined,
  'sports-fitness': Icons.sports_soccer_outlined,
};

/// `#RRGGBB`, `RRGGBB`, `#RGB` or `#AARRGGBB` as a colour; null otherwise.
Color? parseHexColor(String? value) {
  var hex = value?.trim() ?? '';
  if (hex.startsWith('#')) hex = hex.substring(1);
  if (hex.length == 3) hex = hex.split('').map((c) => '$c$c').join();
  if (hex.length == 6) hex = 'FF$hex';
  if (hex.length != 8) return null;
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// The topic's colour: the server's, else the default tree's for its slug,
/// else one of those picked by its id -- so it is at least stable.
Color topicColor(Topic topic) {
  final sent = parseHexColor(topic.color);
  if (sent != null) return sent;
  final known = _defaultColors[topic.slug];
  if (known != null) return Color(known);
  final palette = _defaultColors.values.toList();
  return Color(palette[topic.id.abs() % palette.length]);
}

/// The topic's icon: its emoji -- the server's, else the default tree's
/// for its slug -- and a symbol only for a topic the app does not know that
/// came without one.
class TopicIcon extends StatelessWidget {
  final Topic topic;
  final double size;
  final Color? color;

  const TopicIcon({super.key, required this.topic, this.size = 18, this.color});

  @override
  Widget build(BuildContext context) {
    final emoji = topic.emoji;
    if (emoji != null) return EmojiGlyph(emoji, size: size);
    return Icon(_defaultIcons[topic.slug] ?? Icons.interests_outlined,
        size: size, color: color ?? topicColor(topic));
  }
}

/// An emoji drawn as an icon: the same size whatever the phone's text size,
/// like an [Icon] -- it marks, it is not read.
class EmojiGlyph extends StatelessWidget {
  final String emoji;
  final double size;

  const EmojiGlyph(this.emoji, {super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Text(
      emoji,
      textScaler: TextScaler.noScaling,
      // The emoji's own height, so it sits centred beside text.
      style: TextStyle(fontSize: size * 0.9, height: 1.15),
    );
  }
}

/// The neutral colours topic widgets sit on.
///
/// The app draws on white with near-black ink; a dark theme, when there is
/// one, is taken from the colour scheme instead.
class TopicSurface {
  final Color background;
  final Color ink;
  final Color muted;
  final Color outline;
  final bool isDark;

  const TopicSurface._(
      this.background, this.ink, this.muted, this.outline, this.isDark);

  factory TopicSurface.of(BuildContext context) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      final scheme = theme.colorScheme;
      return TopicSurface._(scheme.surface, scheme.onSurface,
          scheme.onSurfaceVariant, scheme.outlineVariant, true);
    }
    return const TopicSurface._(Colors.white, Color(0xFF1E1E1E),
        Color(0xFF6B6B6B), Color(0xFFAFAFAF), false);
  }
}

/// The look every chip shares, after the Interests screen: a soft grey
/// pill with no edge; chosen, the app's yellow with a thin ink edge.
class ChipLook {
  /// An unchosen chip's fill.
  final Color idle;

  /// A chosen chip's fill.
  final Color chosen;

  /// A chosen chip's edge.
  final Color edge;

  /// Text on an unchosen chip.
  final Color ink;

  /// Text on a chosen chip.
  final Color onChosen;

  /// A count beside the name.
  final Color muted;

  const ChipLook._(
      this.idle, this.chosen, this.edge, this.ink, this.onChosen, this.muted);

  /// [idle] replaces the grey -- white, on the yellow of onboarding.
  factory ChipLook.of(BuildContext context, {Color? idle}) {
    final theme = Theme.of(context);
    if (theme.brightness == Brightness.dark) {
      final scheme = theme.colorScheme;
      return ChipLook._(
        idle ?? scheme.surfaceContainerHighest,
        AppColors.paleYellow,
        AppColors.paleYellow,
        scheme.onSurface,
        AppColors.ink,
        scheme.onSurfaceVariant,
      );
    }
    return ChipLook._(
      idle ?? AppColors.softGrey,
      AppColors.paleYellow,
      AppColors.ink,
      const Color(0xFF1E1E1E),
      AppColors.ink,
      const Color(0xFF6B6B6B),
    );
  }
}

/// The colours one topic is drawn in, readable on light and dark.
class TopicPalette {
  /// The topic's own colour, lifted a little on dark backgrounds.
  final Color accent;

  /// A wash of it, for a chip or card behind text.
  final Color tint;

  /// Text on [tint].
  final Color onTint;

  const TopicPalette._(this.accent, this.tint, this.onTint);

  factory TopicPalette.of(BuildContext context, Topic topic) =>
      TopicPalette.forColor(context, topicColor(topic));

  factory TopicPalette.forColor(BuildContext context, Color color) {
    final surface = TopicSurface.of(context);
    if (surface.isDark) {
      final accent = Color.lerp(color, Colors.white, 0.3)!;
      return TopicPalette._(
        accent,
        Color.alphaBlend(accent.withValues(alpha: 0.22), surface.background),
        surface.ink,
      );
    }
    return TopicPalette._(
      color,
      Color.alphaBlend(color.withValues(alpha: 0.12), surface.background),
      // Darkened, so a light colour (the yellow of Sports) still reads.
      Color.lerp(color, Colors.black, 0.45)!,
    );
  }
}
