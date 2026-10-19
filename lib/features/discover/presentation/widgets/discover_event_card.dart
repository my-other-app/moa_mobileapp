import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/discover/domain/entities/discover_event.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/club_logo.dart';
import 'package:finnet/shared/widgets/event_poster_image.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';

const _ink = Color(0xFF1E1E1E);
const _muted = Color(0xFF6B6B6B);
const _whenColor = Color(0xFFB4232C);

/// How far a card's text grows with the phone's text size. Past it the
/// card stays the same size: cards side by side have no room to grow.
const cardMaxTextScale = 1.6;

/// How far a row's text grows: a row has the screen's width to grow in.
const tileMaxTextScale = 2.0;

/// The slots an event card is laid out in, at a text size.
///
/// Every card, and every row in a list, keeps the same slots whatever the
/// event holds: the club (one line), the name (room for two lines, used or
/// not), when, where, then the price and the status pinned to the bottom.
/// So cards side by side line up row for row and are all one height.
class EventCardSlots {
  EventCardSlots(this.scaler);

  /// The slots at [context]'s text size, up to [maxScale].
  factory EventCardSlots.of(BuildContext context,
          {double maxScale = cardMaxTextScale}) =>
      EventCardSlots(
          MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxScale));

  final TextScaler scaler;

  static const _small = 12.0;
  static const _title = 15.0;
  static const _price = 13.0;
  static const _badge = 11.0;
  static const _lineHeight = 1.3;
  static const _titleHeight = 1.25;

  /// The club's logo beside its name.
  static const logo = 18.0;
  static const clubGap = 6.0;
  static const titleGap = 6.0;
  static const lineGap = 2.0;

  /// At least this much between where and the bottom row.
  static const footGap = 10.0;

  /// Around a card's text.
  static const padding = 12.0;

  /// One line of small text: the club, when, where.
  double get line => scaler.scale(_small) * _lineHeight;
  double get club => math.max(line, logo);

  /// Two lines of the name, always.
  double get title => scaler.scale(_title) * _titleHeight * 2;

  /// The bottom row: the price, or a status badge.
  double get foot => math.max(scaler.scale(_price) * _lineHeight,
      scaler.scale(_badge) * _lineHeight + 6);

  /// The club, the name, when and where.
  double get facts =>
      club + clubGap + title + titleGap + line + lineGap + line;

  /// The text and the bottom row.
  double get content => facts + footGap + foot;

  /// Everything under a card's poster.
  double get cardBody => padding + content + padding;

  static const smallStrut = StrutStyle(
      fontSize: _small, height: _lineHeight, forceStrutHeight: true);
  static const titleStrut = StrutStyle(
      fontSize: _title, height: _titleHeight, forceStrutHeight: true);
  static const priceStrut = StrutStyle(
      fontSize: _price, height: _lineHeight, forceStrutHeight: true);
  static const badgeStrut = StrutStyle(
      fontSize: _badge, height: _lineHeight, forceStrutHeight: true);
}

/// What a screen reader says for an event card or row.
String discoverEventLabel(DiscoverEvent event) {
  final when = formatWhen(event.startsAt);
  final price = cardPrice(event);
  final status = statusLabel(event);
  return [
    event.name,
    if (event.club != null) event.club!.name,
    if (when.isNotEmpty) when,
    placeLine(event),
    if (price != null) price,
    if (status != null) status,
    if (event.going > 0) '${formatCount(event.going)} going',
  ].join(', ');
}

/// An event in a rail: the poster (or its drawn cover), then the event's
/// facts in fixed slots, so every card in a rail is the same height and
/// its rows line up with the next card's. The whole card opens the event.
class DiscoverEventCard extends StatelessWidget {
  const DiscoverEventCard({
    super.key,
    required this.event,
    this.width = defaultWidth,
  });

  static const defaultWidth = 248.0;

  final DiscoverEvent event;
  final double width;

  /// How tall a card [width] wide is at [context]'s text size: every card
  /// is exactly this tall, whatever it holds.
  static double heightFor(BuildContext context,
          {double width = defaultWidth}) =>
      width * 9 / 16 + EventCardSlots.of(context).cardBody;

  @override
  Widget build(BuildContext context) {
    final slots = EventCardSlots.of(context);
    final posterHeight = width * 9 / 16;
    void open() => openDiscoverEvent(context, event.id);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: cardMaxTextScale,
      child: Semantics(
        container: true,
        button: true,
        label: discoverEventLabel(event),
        excludeSemantics: true,
        onTap: open,
        child: SizedBox(
          width: width,
          height: posterHeight + slots.cardBody,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('discover-event-${event.id}'),
              onTap: open,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  EventPosterImage(
                    poster: event.poster,
                    eventId: event.id,
                    categoryId: event.category?.id,
                    categoryName: event.category?.name,
                    startsAt: event.startsAt,
                    isOnline: event.isOnline,
                    width: width,
                    height: posterHeight,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(EventCardSlots.padding),
                      child: _EventFacts(event: event, slots: slots),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An event as a row in a list: the same card on its side -- a poster
/// beside the same slots, in the same order, with the same bottom row.
class DiscoverEventTile extends StatelessWidget {
  const DiscoverEventTile({super.key, required this.event});

  final DiscoverEvent event;

  static const thumbWidth = 96.0;
  static const _padding = 10.0;

  @override
  Widget build(BuildContext context) {
    final slots = EventCardSlots.of(context, maxScale: tileMaxTextScale);
    void open() => openDiscoverEvent(context, event.id);

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: tileMaxTextScale,
      child: Semantics(
        container: true,
        button: true,
        label: discoverEventLabel(event),
        excludeSemantics: true,
        onTap: open,
        // Half the gap between rows above and below each, so a list of
        // them is evenly spaced.
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Opacity(
            opacity: event.isEnded ? 0.6 : 1,
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: AppColors.border, width: 0.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: ValueKey('discover-event-${event.id}'),
                onTap: open,
                child: Padding(
                  padding: const EdgeInsets.all(_padding),
                  child: SizedBox(
                    height: slots.content,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        EventPosterImage(
                          poster: event.poster,
                          eventId: event.id,
                          categoryId: event.category?.id,
                          categoryName: event.category?.name,
                          startsAt: event.startsAt,
                          isOnline: event.isOnline,
                          slot: PosterSlot.thumb,
                          width: thumbWidth,
                          height: slots.content,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _EventFacts(event: event, slots: slots),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The club, the name, when, where -- each in its slot -- and the bottom
/// row pinned to the bottom of whatever height it is given.
class _EventFacts extends StatelessWidget {
  const _EventFacts({required this.event, required this.slots});

  final DiscoverEvent event;
  final EventCardSlots slots;

  @override
  Widget build(BuildContext context) {
    final when = formatWhen(event.startsAt);
    final club = event.club;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: slots.club,
          child: club == null
              ? null
              : Row(
                  children: [
                    ClubLogo(
                      url: imageUrlFrom(club.logo),
                      size: EventCardSlots.logo,
                      circle: true,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        club.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        strutStyle: EventCardSlots.smallStrut,
                        style: const TextStyle(fontSize: 12, color: _muted),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: EventCardSlots.clubGap),
        SizedBox(
          height: slots.title,
          child: Text(
            event.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            strutStyle: EventCardSlots.titleStrut,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
        ),
        const SizedBox(height: EventCardSlots.titleGap),
        SizedBox(
          height: slots.line,
          child: Text(
            when.isEmpty ? 'Date to be announced' : when,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            strutStyle: EventCardSlots.smallStrut,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: when.isEmpty ? _muted : _whenColor,
            ),
          ),
        ),
        const SizedBox(height: EventCardSlots.lineGap),
        SizedBox(height: slots.line, child: _PlaceLine(event: event)),
        const Spacer(),
        SizedBox(height: slots.foot, child: _Foot(event: event)),
      ],
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
            strutStyle: EventCardSlots.smallStrut,
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
        ),
      ],
    );
  }
}

/// The bottom row: the one price (none for an event the iOS app doesn't
/// sell; see [cardPrice]) on the left, and on the right the status when
/// there is one, else how many are going.
class _Foot extends StatelessWidget {
  const _Foot({required this.event});

  final DiscoverEvent event;

  @override
  Widget build(BuildContext context) {
    final price = cardPrice(event);
    final status = statusLabel(event);
    return Row(
      children: [
        if (price != null) ...[
          Text(
            price,
            key: const ValueKey('discover-event-price'),
            maxLines: 1,
            strutStyle: EventCardSlots.priceStrut,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _ink,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: status != null
                ? StatusBadge(label: status, tone: statusTone(event))
                : event.going > 0
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline,
                              size: 14, color: _muted),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${formatCount(event.going)} going',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              strutStyle: EventCardSlots.smallStrut,
                              style:
                                  const TextStyle(fontSize: 12, color: _muted),
                            ),
                          ),
                        ],
                      )
                    : null,
          ),
        ),
      ],
    );
  }
}

/// How a status badge is coloured.
enum StatusTone { live, warn, muted }

StatusTone statusTone(DiscoverEvent e) => switch (e.status) {
      DiscoverEventStatus.live => StatusTone.live,
      DiscoverEventStatus.closingSoon => StatusTone.warn,
      _ => StatusTone.muted,
    };

/// The one badge style: "Live now", "Closing soon", "Full", "Ended".
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      StatusTone.live => (const Color(0xFFE53935), Colors.white),
      StatusTone.warn => (const Color(0xFFFFE0B2), const Color(0xFF8A4B00)),
      StatusTone.muted => (const Color(0xFFEDEDED), const Color(0xFF4A4A4A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        strutStyle: EventCardSlots.badgeStrut,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

/// A card's shape while a rail loads: the poster, then a bar in each of
/// the card's slots, at a card's exact size.
class EventCardSkeleton extends StatelessWidget {
  const EventCardSkeleton(
      {super.key, this.width = DiscoverEventCard.defaultWidth});

  final double width;

  @override
  Widget build(BuildContext context) {
    final slots = EventCardSlots.of(context);
    Widget bar(double height, double barWidth, double slot) => SizedBox(
          height: slot,
          child: Align(
            alignment: Alignment.centerLeft,
            child: ShimmerBox(height: height, width: barWidth, borderRadius: 4),
          ),
        );
    return SizedBox(
      width: width,
      height: DiscoverEventCard.heightFor(context, width: width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBox(height: width * 9 / 16, width: width, borderRadius: 10),
          Padding(
            padding: const EdgeInsets.all(EventCardSlots.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                bar(10, width * 0.45, slots.club),
                const SizedBox(height: EventCardSlots.clubGap),
                SizedBox(
                  height: slots.title,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBox(
                          height: 13, width: width * 0.85, borderRadius: 4),
                      ShimmerBox(
                          height: 13, width: width * 0.55, borderRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(height: EventCardSlots.titleGap),
                bar(10, width * 0.5, slots.line),
                const SizedBox(height: EventCardSlots.lineGap),
                bar(10, width * 0.62, slots.line),
                const SizedBox(height: EventCardSlots.footGap),
                bar(12, 44, slots.foot),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
