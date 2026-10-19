import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/topic_emoji.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_chips.dart';

/// Interests as small read-only tags: each its emoji and name on one of the
/// app's pastels.
///
/// A screen reader hears the interest's topic too -- from its
/// `category_id`, or from where the catalogue lists it -- unless there is
/// no catalogue, or only the one topic of a server from before topics.
class InterestTags extends ConsumerWidget {
  final List<Interest> interests;

  const InterestTags({super.key, required this.interests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (interests.isEmpty) return const SizedBox.shrink();
    final catalogue = ref.watch(topicCatalogueProvider).valueOrNull ?? const [];
    final grouped = topicsWorthShowing(catalogue);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final (index, interest) in interests.indexed)
          Builder(builder: (context) {
            final topic = !grouped
                ? null
                : (topicNamed('${interest.categoryId}', catalogue) ??
                    topicOfInterest(interest.id, catalogue));
            return InterestTag(
              label: interest.name,
              glyph: interest.emoji,
              color: InterestTag.pastelAt(index),
              semanticLabel: topic == null
                  ? interest.name
                  : '${interest.name}, ${topic.label}',
            );
          }),
      ],
    );
  }
}
