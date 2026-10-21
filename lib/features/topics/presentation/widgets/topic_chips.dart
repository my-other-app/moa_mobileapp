import 'package:flutter/material.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart'
    show formatCount;
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';
import 'package:finnet/shared/motion.dart';
import 'package:finnet/shared/widgets/pressable.dart';

// The chips topics and interests are drawn as, after the Interests screen:
// an emoji, then the name, on a soft pill with no edge; chosen, the app's
// yellow with a thin ink edge. One look for the Interests screen, the
// explore filters, a topic's page and Discover.

/// A topic as a chip.
///
/// With [selected] set it is a filter, in the shared chip look. Without, it
/// is a tag -- on an event's or a club's page: a wash of the topic's colour
/// with its emoji.
class TopicChip extends StatelessWidget {
  final Topic topic;
  final bool? selected;
  final VoidCallback? onTap;

  /// Shown after the name ("Development 12"), when the server counted.
  final int? count;

  /// What [count] counts, for screen readers: "12 upcoming", "30 clubs".
  final String countUnit;

  const TopicChip({
    super.key,
    required this.topic,
    this.selected,
    this.onTap,
    this.count,
    this.countUnit = 'upcoming',
  });

  @override
  Widget build(BuildContext context) {
    final isFilter = selected != null;
    final on = selected ?? false;
    // A filter being chosen is felt; a tag opening its topic is a tap.
    final tap = onTap == null
        ? null
        : isFilter
            ? () {
                Haptics.selection();
                onTap!();
              }
            : onTap;
    final look = ChipLook.of(context);
    final palette = TopicPalette.of(context, topic);

    final Color background;
    final Color foreground;
    final Color edge;
    if (!isFilter) {
      background = palette.tint;
      foreground = palette.onTint;
      edge = palette.tint;
    } else if (on) {
      background = look.chosen;
      foreground = look.onChosen;
      edge = look.edge;
    } else {
      background = look.idle;
      foreground = look.ink;
      edge = look.idle;
    }

    return Semantics(
      container: true,
      button: onTap != null,
      selected: isFilter ? on : null,
      label: [
        '${topic.label} topic',
        if (count != null) '$count $countUnit',
      ].join(', '),
      onTap: tap,
      excludeSemantics: true,
      child: _Pill(
        key: ValueKey('topic-chip-${topic.slug}'),
        background: background,
        edge: edge,
        onTap: tap,
        compact: true,
        leading: TopicIcon(topic: topic, size: 15, color: palette.accent),
        label: topic.label,
        labelColor: foreground,
        labelWeight: isFilter ? FontWeight.w400 : FontWeight.w600,
        count: count,
        countColor: isFilter ? look.muted : palette.onTint,
      ),
    );
  }
}

/// An interest as a chip to choose: its emoji and name, in the shared chip
/// look.
class InterestChip extends StatelessWidget {
  final String label;

  /// Its emoji -- the server's, else the default tree's (see
  /// `interestEmoji`); none for "All".
  final String? glyph;
  final bool selected;

  /// False once the limit is reached: its name drawn faded; a tap still reaches
  /// [onTap], so the screen can say why nothing happened.
  final bool enabled;
  final VoidCallback? onTap;
  final int? count;

  /// What [count] counts, for screen readers: "12 upcoming", "30 clubs".
  final String countUnit;

  /// The topic, for screen readers ("Coding, Development").
  final String? topicLabel;

  /// Smaller, for a row of filters; the full size is the Interests screen's.
  final bool compact;

  /// The fill when not chosen, in place of the soft grey: white on the
  /// yellow of onboarding.
  final Color? idleColor;

  /// The Interests screen's look, after the owner's design: not chosen, just
  /// the emoji and the name, no fill and no edge; chosen, the yellow pill.
  final bool plain;

  const InterestChip({
    super.key,
    required this.label,
    this.glyph,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.count,
    this.countUnit = 'upcoming',
    this.topicLabel,
    this.compact = false,
    this.idleColor,
    this.plain = false,
  });

  @override
  Widget build(BuildContext context) {
    final look = ChipLook.of(context, idle: idleColor);
    final idle = plain ? Colors.transparent : look.idle;
    // Choosing and unchoosing are felt.
    final tap = onTap == null
        ? null
        : () {
            Haptics.selection();
            onTap!();
          };

    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      enabled: enabled || selected,
      label: [
        label,
        if (topicLabel != null && topicLabel!.isNotEmpty) topicLabel!,
        if (count != null) '$count $countUnit',
      ].join(', '),
      hint: !enabled && !selected ? 'Limit reached' : null,
      onTap: tap,
      excludeSemantics: true,
      child: _Pill(
        background: selected ? look.chosen : idle,
        edge: selected ? look.edge : idle,
        onTap: tap,
        compact: compact,
        plain: plain,
        // Past the limit the name and emoji fade; the fill stays, so a
        // faded chip is never mistaken for a chosen one.
        faded: !enabled && !selected,
        leading:
            glyph == null ? null : EmojiGlyph(glyph!, size: compact ? 15 : 19),
        label: label,
        labelColor: selected ? look.onChosen : look.ink,
        count: count,
        countColor: look.muted,
      ),
    );
  }
}

/// An interest as a read-only tag: its emoji and name on one of the app's
/// pastels -- on a club's page and card, an event's page, the profile.
class InterestTag extends StatelessWidget {
  final String label;

  /// Its emoji, when it has one.
  final String? glyph;

  /// The fill; [pastelAt] gives the app's pastels in turn.
  final Color color;

  /// What a screen reader says, when more than [label]: "Coding,
  /// Development".
  final String? semanticLabel;

  /// The name's size; the tag grows around it.
  final double fontSize;

  const InterestTag({
    super.key,
    required this.label,
    required this.color,
    this.glyph,
    this.semanticLabel,
    this.fontSize = 12,
  });

  /// The pastels interest tags take in turn, so neighbours differ.
  static const pastels = [
    Color(0xFFE1C9FF),
    Color(0xFFF9FFA1),
    Color(0xFFB8DFF2),
    Color(0xFFFFC84A),
    Color(0xFFFFDEDD),
  ];

  /// The pastel for the tag at [index].
  static Color pastelAt(int index) => pastels[index % pastels.length];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: fontSize * 2 / 3, vertical: fontSize / 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (glyph != null) ...[
              EmojiGlyph(glyph!, size: fontSize + 1),
              SizedBox(width: fontSize / 3),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // On a pastel in either theme, so always dark.
                style: TextStyle(
                    fontSize: fontSize, color: const Color(0xFF1E1E1E)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The pill every chip is: an optional emoji, the name, an optional count.
/// The edge is drawn in every state, in the fill's colour when there is
/// none to show, so choosing a chip never changes its size.
class _Pill extends StatelessWidget {
  final Color background;
  final Color edge;
  final VoidCallback? onTap;
  final bool compact;
  final Widget? leading;
  final String label;
  final Color labelColor;
  final FontWeight labelWeight;
  final int? count;
  final Color countColor;
  final bool faded;
  final bool plain;

  const _Pill({
    super.key,
    required this.background,
    required this.edge,
    required this.onTap,
    required this.compact,
    required this.leading,
    required this.label,
    required this.labelColor,
    this.labelWeight = FontWeight.w400,
    required this.count,
    required this.countColor,
    this.faded = false,
    this.plain = false,
  });

  static final _radius = BorderRadius.circular(60);

  @override
  Widget build(BuildContext context) {
    // Choosing it fills it and draws its edge, eased rather than switched;
    // a finger on it presses it in a little.
    final duration = motionDuration(context, Motion.medium);
    final base = DefaultTextStyle.of(context).style;
    return Pressable(
        enabled: onTap != null,
        scale: 0.94,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: _radius,
            child: AnimatedContainer(
              duration: duration,
              curve: Motion.curve,
              padding: compact
                  ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                  : plain
                      ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
                      : const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: background,
                borderRadius: _radius,
                border: Border.all(color: edge),
              ),
              child: AnimatedOpacity(
                duration: duration,
                opacity: faded ? 0.4 : 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      SizedBox(width: compact ? 5 : 6),
                    ],
                    AnimatedDefaultTextStyle(
                      duration: duration,
                      curve: Motion.curve,
                      style: base.copyWith(
                        fontSize: compact ? 14 : 15,
                        color: labelColor,
                        fontWeight: labelWeight,
                      ),
                      child: Text(label),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Text(formatCount(count!),
                          style: TextStyle(
                              fontSize: compact ? 12 : 13, color: countColor)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ));
  }
}
