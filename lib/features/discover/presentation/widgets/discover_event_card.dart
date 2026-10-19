import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';

const _ink = Color(0xFF1E1E1E);
const _muted = Color(0xFF6B6B6B);

/// An event in a rail on the front page: the poster (or its drawn cover)
/// with what matters right now pinned to it, then the name, when and where,
/// the price and how many are going. The whole card opens the event.
class DiscoverEventCard extends StatelessWidget {
  const DiscoverEventCard({super.key, required this.event, this.width = 248});

  final DiscoverEvent event;
  final double width;

  @override
  Widget build(BuildContext context) {
    final when = formatWhen(event.startsAt);
    final pill = statusLabel(event);
    final club = event.club;

    return Semantics(
      container: true,
      button: true,
      label: [
        event.name,
        if (when.isNotEmpty) when,
        placeLine(event),
        formatPrice(event.hasFee, event.fee),
        if (pill != null) pill,
      ].join(', '),
      excludeSemantics: true,
      onTap: () => openDiscoverEvent(context, event.id),
      child: SizedBox(
        width: width,
        child: Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border, width: 0.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('discover-event-${event.id}'),
            onTap: () => openDiscoverEvent(context, event.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    EventPosterImage(
                      poster: event.poster,
                      eventId: event.id,
                      categoryId: event.category?.id,
                      categoryName: event.category?.name,
                      startsAt: event.startsAt,
                      isOnline: event.isOnline,
                      width: width,
                      height: width * 9 / 16,
                    ),
                    if (pill != null || !event.hasFee)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: _Pills(event: event, status: pill),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (club != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              ClubLogo(
                                url: imageUrlFrom(club.logo),
                                size: 20,
                                circle: true,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  club.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12, color: _muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Text(
                        event.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          height: 1.25,
                        ),
                      ),
                      if (when.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB4232C),
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      _PlaceLine(event: event),
                      const SizedBox(height: 8),
                      _Foot(event: event),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// An event as a row in a list: a small poster beside when, the name, the
/// club and where, and the price.
class DiscoverEventTile extends StatelessWidget {
  const DiscoverEventTile({super.key, required this.event});

  final DiscoverEvent event;

  @override
  Widget build(BuildContext context) {
    final when = formatWhen(event.startsAt);
    final pill = statusLabel(event);
    final club = event.club;

    return Semantics(
      container: true,
      button: true,
      label: [
        event.name,
        if (when.isNotEmpty) when,
        if (club != null) club.name,
        placeLine(event),
        formatPrice(event.hasFee, event.fee),
        if (pill != null) pill,
      ].join(', '),
      excludeSemantics: true,
      onTap: () => openDiscoverEvent(context, event.id),
      child: InkWell(
        key: ValueKey('discover-event-${event.id}'),
        onTap: () => openDiscoverEvent(context, event.id),
        borderRadius: BorderRadius.circular(10),
        child: Opacity(
          opacity: event.isEnded ? 0.6 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EventPosterImage(
                  poster: event.poster,
                  eventId: event.id,
                  categoryId: event.category?.id,
                  categoryName: event.category?.name,
                  startsAt: event.startsAt,
                  isOnline: event.isOnline,
                  slot: PosterSlot.thumb,
                  width: 92,
                  height: 92,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (when.isNotEmpty)
                        Text(
                          when,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB4232C),
                          ),
                        ),
                      Text(
                        event.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          height: 1.25,
                        ),
                      ),
                      if (club != null)
                        Text(
                          club.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: _muted),
                        ),
                      const SizedBox(height: 2),
                      _PlaceLine(event: event),
                      const SizedBox(height: 4),
                      _Foot(event: event, status: pill),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaceLine extends StatelessWidget {
  const _PlaceLine({required this.event});

  final DiscoverEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          event.isOnline ? Icons.videocam_outlined : Icons.place_outlined,
          size: 14,
          color: _muted,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            placeLine(event),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ),
      ],
    );
  }
}

/// The price, how many are going, and (in a row) the status.
class _Foot extends StatelessWidget {
  const _Foot({required this.event, this.status});

  final DiscoverEvent event;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          formatPrice(event.hasFee, event.fee),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _ink,
          ),
        ),
        if (event.going > 0)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline, size: 14, color: _muted),
              const SizedBox(width: 3),
              Text(
                '${formatCount(event.going)} going',
                style: const TextStyle(fontSize: 12, color: _muted),
              ),
            ],
          ),
        if (status != null) _Pill(label: status!, tone: _toneOf(event)),
      ],
    );
  }
}

enum _Tone { live, warn, muted, free }

_Tone _toneOf(DiscoverEvent e) => switch (e.status) {
      DiscoverEventStatus.live => _Tone.live,
      DiscoverEventStatus.closingSoon => _Tone.warn,
      DiscoverEventStatus.full || DiscoverEventStatus.ended => _Tone.muted,
      DiscoverEventStatus.upcoming => _Tone.free,
    };

class _Pills extends StatelessWidget {
  const _Pills({required this.event, this.status});

  final DiscoverEvent event;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final free = !event.hasFee &&
        event.status != DiscoverEventStatus.ended &&
        event.status != DiscoverEventStatus.full;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status != null) _Pill(label: status!, tone: _toneOf(event)),
        if (status != null && free) const SizedBox(width: 6),
        if (free) const _Pill(label: 'Free', tone: _Tone.free),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});

  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      _Tone.live => (const Color(0xFFE53935), Colors.white),
      _Tone.warn => (const Color(0xFFFF9800), Colors.white),
      _Tone.muted => (const Color(0xFF616161), Colors.white),
      _Tone.free => (AppColors.paleYellow, _ink),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
