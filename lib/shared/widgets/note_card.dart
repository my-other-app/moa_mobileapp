import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A club's note, as a card.
///
/// Laid out to the Figma design (Frame 168): the note's own title is the
/// hero, with the club name and the time together on one line beneath it,
/// the logo spanning both on the left, and an open-link affordance in the
/// top-right corner. The body sits below, separated by a clear gap.
///
/// The previous version had this the other way round -- club name largest at
/// the top, the note's title demoted below the header -- which read as a
/// list of clubs rather than a list of things clubs had said.
class NoteCard extends StatelessWidget {
  /// URL to the club's logo.
  final String logoUrl;

  /// The club's name, shown beside the timestamp.
  final String headerTitle;

  /// Relative time, e.g. "1 hour ago".
  final String headerSubtitle;

  /// The note's own title -- the largest thing on the card.
  final String cardTitle;

  /// The note body.
  final String description;

  /// The club this note belongs to, for taps on the logo and the open icon.
  ///
  /// Null disables both rather than sending someone somewhere arbitrary,
  /// which is what a hardcoded `/clubs/1` used to do.
  final int? clubId;
  final String? clubSlug;

  /// Overrides what the open-link icon does. Defaults to opening the club.
  final VoidCallback? onLinkTap;

  const NoteCard({
    super.key,
    required this.logoUrl,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.cardTitle,
    required this.description,
    this.clubId,
    this.clubSlug,
    this.onLinkTap,
  });

  // --- Design tokens, read off Frame 168 -------------------------------------
  static const _radius = 16.0;
  static const _padding = 16.0;
  static const _borderWidth = 1.5;
  static const _logoSize = 44.0;
  static const _ink = Color(0xFF1E1E1E);

  void _openClub(BuildContext context) {
    if (clubId == null) return;
    context.push('/clubs/$clubId', extra: {
      'clubSlug': clubSlug ?? '',
      'clubName': headerTitle,
      'clubLogoUrl': logoUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    final tapClub = clubId == null ? null : () => _openClub(context);

    return Container(
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: _ink, width: _borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: tapClub,
                child: _Logo(logoUrl: logoUrl, clubName: headerTitle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cardTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: _ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Club and time share a line, as in the design. Wrap
                    // rather than overflow: a long club name on a narrow
                    // phone would otherwise clip the timestamp off the edge.
                    Wrap(
                      spacing: 12,
                      children: [
                        Text(
                          headerTitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: _ink,
                          ),
                        ),
                        Text(
                          headerSubtitle,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onLinkTap != null || clubId != null)
                GestureDetector(
                  onTap: onLinkTap ?? tapClub,
                  behavior: HitTestBehavior.opaque,
                  // A 24px icon is below the 44px minimum touch target, so
                  // the padding is the tap area rather than decoration.
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.open_in_new, size: 26, color: _ink),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            description,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.5,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// The club's logo, or its initial when there is no usable image.
class _Logo extends StatelessWidget {
  final String logoUrl;
  final String clubName;

  const _Logo({required this.logoUrl, required this.clubName});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: NoteCard._logoSize,
        height: NoteCard._logoSize,
        child: logoUrl.isEmpty
            ? _Fallback(clubName: clubName)
            : Image.network(
                logoUrl,
                fit: BoxFit.cover,
                // A club with no logo is ordinary, so this is its initial on
                // a neutral tile rather than a broken-image icon.
                errorBuilder: (_, __, ___) => _Fallback(clubName: clubName),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  // A plain tile while loading, so the row does not jump
                  // once the image arrives.
                  return const ColoredBox(color: Color(0xFFEFEFEF));
                },
              ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  final String clubName;

  const _Fallback({required this.clubName});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFEFEFEF),
      child: Center(
        child: Text(
          clubName.isEmpty ? '?' : clubName.characters.first.toUpperCase(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black54,
          ),
        ),
      ),
    );
  }
}
