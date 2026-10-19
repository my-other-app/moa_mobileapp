import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_section.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';

/// "More from this club" or "Similar events": a row of cards that scrolls
/// sideways, at most [max] of them.
class EventRail extends StatelessWidget {
  final String title;
  final List<EventSummary> events;
  final ValueChanged<EventSummary> onOpen;
  final VoidCallback? onSeeAll;
  final int max;

  const EventRail({
    super.key,
    required this.title,
    required this.events,
    required this.onOpen,
    this.onSeeAll,
    this.max = 6,
  });

  @override
  Widget build(BuildContext context) {
    final shown = events.take(max).toList();
    return EventSection(
      title: title,
      trailing: onSeeAll == null
          ? null
          : TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2C333D),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('See all'),
            ),
      child: SizedBox(
        height: 236,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: shown.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => EventSummaryCard(
            event: shown[i],
            onTap: () => onOpen(shown[i]),
          ),
        ),
      ),
    );
  }
}

/// One event in a rail: its poster, name, when, and where or online.
class EventSummaryCard extends StatelessWidget {
  final EventSummary event;
  final VoidCallback onTap;

  const EventSummaryCard({super.key, required this.event, required this.onTap});

  static const width = 168.0;

  String? get _when {
    final start = event.startsAt;
    return start == null
        ? null
        : DateFormat("EEE, d MMM '·' h:mm a").format(start);
  }

  String get _price {
    if (!event.hasFee) return 'Free';
    final fee = event.fee;
    return fee == null ? 'Paid' : '₹${NumberFormat('#,##0', 'en_IN').format(fee)}';
  }

  @override
  Widget build(BuildContext context) {
    final where =
        event.isOnline ? 'Online' : (event.locationName ?? 'Venue to be announced');
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('rail-event-${event.id}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 112,
                width: width,
                child: EventPosterImage(
                  poster: event.poster,
                  eventId: event.id,
                  categoryId: event.categoryId,
                  categoryName: event.categoryName,
                  startsAt: event.startsAt,
                  isOnline: event.isOnline,
                  slot: PosterSlot.card,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (_when != null) ...[
                      const SizedBox(height: 4),
                      Text(_when!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: Color(0xFF6B7280))),
                    ],
                    Text(
                      '$where · $_price',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
