import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';

/// Interests to choose from, grouped by topic: the Interests screen.
///
/// One section per topic -- its emoji and name in bold -- holding its
/// interests as emoji chips; a search across all of them; how many are
/// chosen.
/// With fewer than two topics (the server before the migration, which files
/// everything under "arts") the sections are left out and the interests
/// shown as one set.
///
/// The selection belongs to the caller: [onToggle] is told which interest
/// was tapped, and taps past [maxSelected] go to [onLimitReached] instead.
class TopicInterestPicker extends StatefulWidget {
  final List<Topic> topics;
  final Set<int> selectedIds;
  final ValueChanged<Interest> onToggle;
  final int maxSelected;
  final VoidCallback? onLimitReached;

  /// The fill of an unchosen chip and of the search, in place of the soft
  /// grey: white, on the yellow of onboarding.
  final Color? idleColor;

  const TopicInterestPicker({
    super.key,
    required this.topics,
    required this.selectedIds,
    required this.onToggle,
    required this.maxSelected,
    this.onLimitReached,
    this.idleColor,
  });

  @override
  State<TopicInterestPicker> createState() => _TopicInterestPickerState();
}

class _TopicInterestPickerState extends State<TopicInterestPicker> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _full => widget.selectedIds.length >= widget.maxSelected;

  void _tap(Interest interest) {
    final selected = widget.selectedIds.contains(interest.id);
    if (!selected && _full) {
      widget.onLimitReached?.call();
      return;
    }
    widget.onToggle(interest);
  }

  @override
  Widget build(BuildContext context) {
    final surface = TopicSurface.of(context);
    final look = ChipLook.of(context, idle: widget.idleColor);
    final grouped = topicsWorthShowing(widget.topics);
    final shown = searchTopics(widget.topics, _query);
    final hasAny = widget.topics.any((t) => t.interests.isNotEmpty);
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(60),
      borderSide: BorderSide.none,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            key: const ValueKey('interest-search'),
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            style: TextStyle(color: look.ink, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Search interests',
              hintStyle: TextStyle(color: look.muted, fontSize: 15),
              prefixIcon: Icon(Icons.search, color: look.muted, size: 20),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: Icon(Icons.close, size: 18, color: look.muted),
                      onPressed: () {
                        _search.clear();
                        setState(() => _query = '');
                      },
                    ),
              isDense: true,
              filled: true,
              fillColor: look.idle,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: field,
              enabledBorder: field,
              focusedBorder: field.copyWith(
                borderSide: const BorderSide(color: AppColors.ink),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              '${widget.selectedIds.length} of ${widget.maxSelected} selected',
              key: const ValueKey('interest-count'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: _full ? FontWeight.w600 : FontWeight.w400,
                color: _full ? look.onChosen : look.muted,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (!hasAny)
          _message(surface, 'No interests to choose from yet.')
        else if (shown.isEmpty)
          _message(surface, 'No interests match "${_query.trim()}".')
        else if (!grouped)
          _chips(interestsOf(shown), null)
        else
          for (final topic in shown) ...[
            _TopicHeader(
              topic: topic,
              selectedCount: topic.interests
                  .where((i) => widget.selectedIds.contains(i.id))
                  .length,
            ),
            const SizedBox(height: 14),
            _chips(topic.interests, topic),
            const SizedBox(height: 32),
          ],
      ],
    );
  }

  Widget _message(TopicSurface surface, String text) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Text(text, style: TextStyle(color: surface.muted, fontSize: 14)),
      );

  Widget _chips(List<Interest> interests, Topic? topic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Plain chips, as in the owner's design: the padding is the gap, so
      // the row packs like a line of words.
      child: Wrap(
        spacing: 4,
        runSpacing: 6,
        children: [
          for (final interest in interests)
            InterestChip(
              key: ValueKey('interest-chip-${interest.id}'),
              label: interest.name,
              glyph: interest.emoji,
              idleColor: widget.idleColor,
              plain: true,
              topicLabel: topic?.label,
              selected: widget.selectedIds.contains(interest.id),
              enabled: !_full || widget.selectedIds.contains(interest.id),
              onTap: () => _tap(interest),
            ),
        ],
      ),
    );
  }
}

class _TopicHeader extends StatelessWidget {
  final Topic topic;
  final int selectedCount;

  const _TopicHeader({required this.topic, required this.selectedCount});

  @override
  Widget build(BuildContext context) {
    final look = ChipLook.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Semantics(
        header: true,
        label: selectedCount > 0
            ? '${topic.label}, $selectedCount selected'
            : topic.label,
        excludeSemantics: true,
        child: Row(
          children: [
            TopicIcon(topic: topic, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                topic.label,
                key: ValueKey('topic-header-${topic.slug}'),
                style: TextStyle(
                  color: look.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selectedCount > 0)
              Text(
                '$selectedCount selected',
                style: TextStyle(fontSize: 13, color: look.muted),
              ),
          ],
        ),
      ),
    );
  }
}
