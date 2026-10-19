import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/topics/domain/entities/topic.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';
import 'package:finnet/shared/widgets/section_header.dart';

/// "Browse by topic" on Home: a tile per topic in its own colour, with how
/// many events are coming up under it when the server counts, each opening
/// the topic's page (its events and clubs, readable signed out); "See all"
/// opens Topics.
///
/// Nothing while the topics load or if they fail -- it is a way in, not the
/// feed -- and nothing on a server with one topic holding everything.
class BrowseByTopicRow extends ConsumerWidget {
  /// Space below it, only when it draws anything.
  final double bottomGap;

  /// Left and right of the title and of the first and last tile: none
  /// inside a list that is padded already, the gutter on one that is not
  /// (the tiles then scroll to the screen's edge).
  final double gutter;

  const BrowseByTopicRow({super.key, this.bottomGap = 0, this.gutter = 0});

  /// How far the tiles' text grows with the phone's text size.
  static const _maxTextScale = 2.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicDirectoryProvider).valueOrNull;
    if (topics == null || !topicsWorthShowing(topics)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: bottomGap),
      child: _content(context, topics),
    );
  }

  Widget _content(BuildContext context, List<Topic> topics) {
    final scale = MediaQuery.textScalerOf(context)
        .clamp(maxScaleFactor: _maxTextScale);
    return Column(
      key: const ValueKey('browse-by-topic'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeader(
          title: 'Browse by topic',
          onSeeAll: () => context.push(topicsPath),
          seeAllKey: const ValueKey('browse-by-topic-all'),
          padding: EdgeInsets.symmetric(horizontal: gutter),
        ),
        const SizedBox(height: 12),
        MediaQuery.withClampedTextScaling(
          maxScaleFactor: _maxTextScale,
          child: SizedBox(
            // Taller with larger text, so the name and count still fit.
            height: _TopicCard.heightFor(scale),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              itemCount: topics.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) =>
                  _TopicCard(topic: topics[i], width: _TopicCard.widthFor(scale)),
            ),
          ),
        ),
      ],
    );
  }
}

/// A topic as a tile: its colour as a wash, its icon on a disc of the
/// colour itself, then its name and how many events are coming up.
class _TopicCard extends StatelessWidget {
  final Topic topic;
  final double width;

  const _TopicCard({required this.topic, required this.width});

  static const _padding = 12.0;
  static const _disc = 34.0;
  static const _gap = 10.0;

  /// Wide enough for "Development" at the text size.
  static double widthFor(TextScaler scale) =>
      2 * _padding + scale.scale(14) * 7.4;

  static double heightFor(TextScaler scale) =>
      2 * _padding +
      _disc +
      _gap +
      scale.scale(14) * 1.3 +
      scale.scale(12) * 1.3;

  @override
  Widget build(BuildContext context) {
    final palette = TopicPalette.of(context, topic);
    final surface = TopicSurface.of(context);
    final count = topic.upcomingEvents;
    final countText = count == null || count <= 0 ? null : '$count upcoming';
    final emoji = interestGlyph(topic.icon, topic.iconType) != null;

    return Semantics(
      container: true,
      button: true,
      label: [
        topic.label,
        if (countText != null) '$count upcoming events',
      ].join(', '),
      onTap: () => _open(context),
      excludeSemantics: true,
      child: Material(
        color: palette.tint,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('browse-topic-${topic.slug}'),
          onTap: () => _open(context),
          child: SizedBox(
            width: width,
            child: Padding(
              padding: const EdgeInsets.all(_padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: _disc,
                    height: _disc,
                    // An emoji keeps its own colours, on white; an icon is
                    // drawn white on the topic's colour.
                    decoration: BoxDecoration(
                      color: emoji ? Colors.white : palette.accent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child:
                        TopicIcon(topic: topic, size: 18, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    topic.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    strutStyle: const StrutStyle(
                        fontSize: 14, height: 1.3, forceStrutHeight: true),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: palette.onTint,
                    ),
                  ),
                  Text(
                    countText ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    strutStyle: const StrutStyle(
                        fontSize: 12, height: 1.3, forceStrutHeight: true),
                    style: TextStyle(fontSize: 12, color: surface.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) => context.push(topicLocation(topic.slug));
}
