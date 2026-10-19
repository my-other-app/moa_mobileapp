import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/discover/domain/entities/discover_club.dart';
import 'package:finnet/features/discover/presentation/discover_navigation.dart';
import 'package:finnet/features/discover/presentation/widgets/discover_format.dart';
import 'package:finnet/shared/utils/image_url.dart';
import 'package:finnet/shared/widgets/club_logo.dart';

const _ink = Color(0xFF1E1E1E);
const _muted = Color(0xFF6B6B6B);

/// A club in a list or a rail: its logo, what it is about, where, and how
/// alive it is. The whole card opens the club.
class DiscoverClubCard extends StatelessWidget {
  const DiscoverClubCard({super.key, required this.club, this.width});

  final DiscoverClub club;

  /// Fixed in a rail; the list's width otherwise.
  final double? width;

  static const _maxInterests = 3;

  @override
  Widget build(BuildContext context) {
    final distance = formatDistance(club.distanceKm);
    final place = [
      if ((club.locationName ?? '').isNotEmpty) club.locationName!,
      if (distance != null) distance,
    ].join(' · ');
    final shown = club.interests.take(_maxInterests).toList();
    final more = club.interests.length - shown.length;

    void open() => openDiscoverClub(context,
        id: club.id, slug: club.slug, name: club.name);

    return Semantics(
      container: true,
      button: club.id > 0,
      label: [
        club.name,
        if ((club.tagline ?? '').isNotEmpty) club.tagline!,
        if (place.isNotEmpty) place,
        plural(club.followers, 'follower'),
        '${club.upcomingEvents} upcoming',
      ].join(', '),
      excludeSemantics: true,
      onTap: club.id > 0 ? open : null,
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
            key: ValueKey('discover-club-${club.slug ?? club.id}'),
            onTap: club.id > 0 ? open : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      ClubLogo(url: imageUrlFrom(club.logo), size: 44, radius: 8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              club.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _ink,
                              ),
                            ),
                            if ((club.tagline ?? '').isNotEmpty)
                              Text(
                                club.tagline!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: _muted),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (place.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 14, color: _muted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            place,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontSize: 12, color: _muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (shown.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final name in shown) _Tag(label: name),
                        if (more > 0) _Tag(label: '+$more'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        plural(club.followers, 'follower'),
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _ink),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${formatCount(club.upcomingEvents)} upcoming',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: club.upcomingEvents > 0
                              ? const Color(0xFF17A58F)
                              : _muted,
                        ),
                      ),
                    ],
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

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, color: _ink),
      ),
    );
  }
}
