import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/discover/domain/entities/discover_club.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_event_card.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/club_logo.dart';

const _ink = Color(0xFF1E1E1E);
const _muted = Color(0xFF6B6B6B);

/// A club in a list or a rail: its logo, name and tagline, where, what it
/// is into, and -- pinned to the bottom -- its followers and upcoming
/// events. Like an event card, each of those has a fixed slot (left empty
/// when the club has nothing for it), so clubs side by side are one height
/// and line up. The whole card opens the club.
class DiscoverClubCard extends StatelessWidget {
  const DiscoverClubCard({super.key, required this.club, this.width});

  final DiscoverClub club;

  /// Fixed in a rail; the list's width otherwise.
  final double? width;

  static const railWidth = 240.0;
  static const _maxInterests = 3;
  static const _padding = 14.0;
  static const _logo = 44.0;

  static const _line = 1.3;
  static const _smallStrut =
      StrutStyle(fontSize: 12, height: _line, forceStrutHeight: true);
  static const _nameStrut =
      StrutStyle(fontSize: 15, height: _line, forceStrutHeight: true);

  /// How tall every club card is at [context]'s text size: [inRail] for a
  /// card in a rail, which grows less with large text.
  static double heightFor(BuildContext context, {bool inRail = true}) =>
      _Slots(_scaler(context, inRail)).height;

  static TextScaler _scaler(BuildContext context, bool inRail) =>
      MediaQuery.textScalerOf(context).clamp(
          maxScaleFactor: inRail ? cardMaxTextScale : tileMaxTextScale);

  @override
  Widget build(BuildContext context) {
    final inRail = width != null;
    final slots = _Slots(_scaler(context, inRail));
    final distance = formatDistance(club.distanceKm);
    final place = [
      if ((club.locationName ?? '').isNotEmpty) club.locationName!,
      if (distance != null) distance,
    ].join(' · ');
    final shown = club.interests.take(_maxInterests).toList();
    final more = club.interests.length - shown.length;
    final tagline = club.tagline?.trim() ?? '';

    void open() => openDiscoverClub(context,
        id: club.id, slug: club.slug, name: club.name);

    Widget line(String text, {Key? key, Color color = _muted}) => SizedBox(
          height: slots.line,
          child: Text(
            text,
            key: key,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            strutStyle: _smallStrut,
            style: TextStyle(fontSize: 12, color: color),
          ),
        );

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: inRail ? cardMaxTextScale : tileMaxTextScale,
      child: Semantics(
        container: true,
        button: club.id > 0,
        label: [
          club.name,
          if (tagline.isNotEmpty) tagline,
          if (place.isNotEmpty) place,
          plural(club.followers, 'follower'),
          '${club.upcomingEvents} upcoming',
        ].join(', '),
        excludeSemantics: true,
        onTap: club.id > 0 ? open : null,
        child: SizedBox(
          width: width,
          height: slots.height,
          child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppColors.border, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: ValueKey('discover-club-${club.slug ?? club.id}'),
              onTap: club.id > 0 ? open : null,
              child: Padding(
                padding: const EdgeInsets.all(_padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: slots.head,
                      child: Row(
                        children: [
                          ClubLogo(
                              url: imageUrlFrom(club.logo),
                              size: _logo,
                              radius: 8),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: slots.name,
                                  child: Text(
                                    club.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    strutStyle: _nameStrut,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: _ink,
                                    ),
                                  ),
                                ),
                                line(tagline),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: _Slots.headGap),
                    SizedBox(
                      height: slots.line,
                      child: place.isEmpty
                          ? null
                          : Row(
                              children: [
                                const Icon(Icons.place_outlined,
                                    size: 14, color: _muted),
                                const SizedBox(width: 4),
                                Expanded(child: line(place)),
                              ],
                            ),
                    ),
                    const SizedBox(height: _Slots.lineGap),
                    shown.isEmpty
                        ? SizedBox(height: slots.line)
                        : line(
                            [...shown, if (more > 0) '+$more'].join(' · '),
                            key: const ValueKey('discover-club-interests'),
                            color: _ink,
                          ),
                    const Spacer(),
                    SizedBox(
                      height: slots.line,
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: plural(club.followers, 'follower'),
                            style: const TextStyle(color: _ink),
                          ),
                          const TextSpan(text: '  ·  '),
                          TextSpan(
                            text:
                                '${formatCount(club.upcomingEvents)} upcoming',
                            style: TextStyle(
                              color: club.upcomingEvents > 0
                                  ? const Color(0xFF17A58F)
                                  : _muted,
                            ),
                          ),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        strutStyle: _smallStrut,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _muted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A club card's slots at a text size.
class _Slots {
  _Slots(this.scaler);

  final TextScaler scaler;

  static const headGap = 10.0;
  static const lineGap = 4.0;
  static const footGap = 10.0;

  double get line => scaler.scale(12) * DiscoverClubCard._line;
  double get name => scaler.scale(15) * DiscoverClubCard._line;

  /// The logo beside the name and the tagline.
  double get head => math.max(DiscoverClubCard._logo, name + line);

  double get height =>
      2 * DiscoverClubCard._padding +
      head +
      headGap +
      line +
      lineGap +
      line +
      footGap +
      line;
}
