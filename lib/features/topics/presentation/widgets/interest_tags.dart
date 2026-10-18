import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/features/topics/domain/topic_rules.dart';
import 'package:finnet/features/topics/presentation/providers/topics_provider.dart';
import 'package:finnet/features/topics/presentation/widgets/topic_style.dart';

/// Interests as small read-only tags, each dotted with its topic's colour.
///
/// The topic comes from the interest's `category_id`, or from where the
/// catalogue lists it. Without a catalogue, or with only the one topic of
/// a server from before topics, the dots are left out.
class InterestTags extends ConsumerWidget {
  final List<Interest> interests;

  const InterestTags({super.key, required this.interests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (interests.isEmpty) return const SizedBox.shrink();
    final catalogue = ref.watch(topicCatalogueProvider).valueOrNull ?? const [];
    final coloured = topicsWorthShowing(catalogue);
    final surface = TopicSurface.of(context);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final interest in interests)
          Builder(builder: (context) {
            final topic = !coloured
                ? null
                : (topicNamed('${interest.categoryId}', catalogue) ??
                    topicOfInterest(interest.id, catalogue));
            return Semantics(
              label: topic == null
                  ? interest.name
                  : '${interest.name}, ${topic.label}',
              excludeSemantics: true,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: surface.background,
                  borderRadius: BorderRadius.circular(60),
                  border: Border.all(color: surface.outline, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (topic != null) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: topicColor(topic),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(interest.name,
                        style: TextStyle(fontSize: 12, color: surface.ink)),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
