import 'package:flutter/material.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/domain/topic_filter.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';
import 'package:finnet/shared/widgets/pressable.dart';
import 'package:finnet/shared/motion.dart';

/// Filter chips for an explore list: topics, then the chosen topic's
/// interests as a second row.
///
/// With fewer than two topics (the server before topics) the topic row is
/// left out and every interest is offered instead. [leading] chips -- the
/// person's college, say -- start the first row.
class TopicFilterBar extends StatelessWidget {
  final List<Topic> topics;
  final TopicFilter filter;
  final ValueChanged<TopicFilter> onChanged;
  final List<Widget> leading;

  /// A count to show on each topic chip, when there is one.
  final int? Function(Topic topic)? topicCount;

  /// What [topicCount] counts, for screen readers.
  final String topicCountUnit;

  /// A count to show on each interest chip, when there is one.
  final int? Function(Interest interest)? interestCount;

  const TopicFilterBar({
    super.key,
    required this.topics,
    required this.filter,
    required this.onChanged,
    this.leading = const [],
    this.topicCount,
    this.topicCountUnit = 'upcoming',
    this.interestCount,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = topicsWorthShowing(topics);
    final selectedTopic = grouped ? filter.topic : null;
    final interests = grouped
        ? (selectedTopic?.interests ?? const <Interest>[])
        : interestsOf(topics);

    final firstRow = <Widget>[
      ...leading,
      if (grouped) ...[
        _AllChip(
          selected: filter.topic == null && filter.interest == null,
          onTap: () => onChanged(TopicFilter.none),
        ),
        for (final topic in topics)
          TopicChip(
            topic: topic,
            selected: selectedTopic?.id == topic.id,
            count: topicCount?.call(topic),
            countUnit: topicCountUnit,
            onTap: () => onChanged(selectedTopic?.id == topic.id
                ? TopicFilter.none
                : TopicFilter(topic: topic)),
          ),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (firstRow.isNotEmpty) _row(firstRow, key: 'topic-filter-row'),
        if (interests.isNotEmpty) ...[
          if (firstRow.isNotEmpty) const SizedBox(height: 8),
          _row(
            [
              for (final interest in interests)
                InterestChip(
                  key: ValueKey('interest-filter-${interest.id}'),
                  label: interest.name,
                  glyph: interest.emoji,
                  compact: true,
                  topicLabel: selectedTopic?.label,
                  count: interestCount?.call(interest),
                  selected: filter.interest?.id == interest.id,
                  onTap: () => onChanged(filter.interest?.id == interest.id
                      ? TopicFilter(topic: selectedTopic)
                      : TopicFilter(topic: selectedTopic, interest: interest)),
                ),
            ],
            key: 'interest-filter-row',
          ),
        ],
      ],
    );
  }

  Widget _row(List<Widget> chips, {required String key}) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        key: ValueKey(key),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}

class _AllChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _AllChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: 'All topics',
      onTap: onTap,
      excludeSemantics: true,
      child: _PlainPill(
        key: const ValueKey('topic-filter-all'),
        label: 'All',
        selected: selected,
        onTap: onTap,
      ),
    );
  }
}

/// A chip in the explore rows that is not a topic: the person's college.
class PlainFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const PlainFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: _PlainPill(
        label: label,
        selected: selected,
        onTap: onTap,
        icon: Icons.school_outlined,
      ),
    );
  }
}

/// A chip with no emoji, in the shared chip look: "All", a college.
class _PlainPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const _PlainPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final look = ChipLook.of(context);
    final radius = BorderRadius.circular(60);
    final ink = selected ? look.onChosen : look.ink;
    final duration = motionDuration(context, Motion.medium);
    return Pressable(
        scale: 0.94,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Haptics.selection();
              onTap();
            },
            borderRadius: radius,
            child: AnimatedContainer(
              duration: duration,
              curve: Motion.curve,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? look.chosen : look.idle,
                borderRadius: radius,
                border: Border.all(color: selected ? look.edge : look.idle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 15, color: ink),
                    const SizedBox(width: 5),
                  ],
                  Text(label, style: TextStyle(fontSize: 14, color: ink)),
                ],
              ),
            ),
          ),
        ));
  }
}
