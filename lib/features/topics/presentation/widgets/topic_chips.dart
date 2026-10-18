import 'package:flutter/material.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';

/// A topic as a chip.
///
/// With [selected] set it is a filter, filled with the topic's colour when
/// on. Without, it is a tag: a wash of the colour with its icon -- on an
/// event's or a club's page.
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
    final palette = TopicPalette.of(context, topic);
    final surface = TopicSurface.of(context);
    final isFilter = selected != null;
    final on = selected ?? false;

    final Color background;
    final Color foreground;
    final Color border;
    if (!isFilter) {
      background = palette.tint;
      foreground = palette.onTint;
      border = palette.tint;
    } else if (on) {
      background = palette.accent;
      foreground = Colors.white;
      border = palette.accent;
    } else {
      background = surface.background;
      foreground = surface.ink;
      border = surface.outline;
    }

    final countText = count == null ? null : '$count';
    return Semantics(
      container: true,
      button: onTap != null,
      selected: isFilter ? on : null,
      label: [
        '${topic.label} topic',
        if (count != null) '$count $countUnit',
      ].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('topic-chip-${topic.slug}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isFilter && !on)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  TopicIcon(
                    topic: topic,
                    size: 14,
                    color: on ? Colors.white : palette.onTint,
                  ),
                const SizedBox(width: 6),
                Text(
                  topic.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: foreground,
                    fontWeight: on || !isFilter
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                if (countText != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    countText,
                    style: TextStyle(
                      fontSize: 12,
                      color: on
                          ? Colors.white.withValues(alpha: 0.85)
                          : surface.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An interest as a chip, edged in its topic's colour when chosen.
class InterestChip extends StatelessWidget {
  final String label;

  /// Its emoji, when it has one.
  final String? glyph;

  /// The colour of the topic it sits under.
  final Color accent;
  final bool selected;

  /// False once the limit is reached: drawn faded; a tap still reaches
  /// [onTap], so the screen can say why nothing happened.
  final bool enabled;
  final VoidCallback? onTap;
  final int? count;

  /// The topic, for screen readers ("Coding, Development").
  final String? topicLabel;

  const InterestChip({
    super.key,
    required this.label,
    required this.accent,
    this.glyph,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.count,
    this.topicLabel,
  });

  @override
  Widget build(BuildContext context) {
    final surface = TopicSurface.of(context);
    final palette = TopicPalette.forColor(context, accent);

    return Semantics(
      container: true,
      button: onTap != null,
      selected: selected,
      enabled: enabled || selected,
      label: [
        label,
        if (topicLabel != null && topicLabel!.isNotEmpty) topicLabel!,
        if (count != null) '$count upcoming',
      ].join(', '),
      hint: !enabled && !selected ? 'Limit reached' : null,
      onTap: onTap,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled || selected ? 1 : 0.45,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(60),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                  horizontal: selected ? 11 : 12, vertical: selected ? 6 : 7),
              decoration: BoxDecoration(
                color: selected ? palette.tint : surface.background,
                borderRadius: BorderRadius.circular(60),
                border: Border.all(
                  color: selected ? palette.accent : surface.outline,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    Icon(Icons.check, size: 16, color: palette.accent),
                    const SizedBox(width: 4),
                  ] else if (glyph != null) ...[
                    Text(glyph!, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: selected ? palette.onTint : surface.ink,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Text('$count',
                        style: TextStyle(fontSize: 12, color: surface.muted)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
