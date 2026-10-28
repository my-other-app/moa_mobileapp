import 'package:flutter/material.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_section.dart';
import 'package:finnet/shared/widgets/club_logo.dart';

/// The event's sponsors, or its partners: square tiles, three to a row on
/// a phone, each with the logo (ClubLogo: on white, whole unless it is
/// square, never cropped), the name, and the label under it. A tile with a
/// link opens it.
class EventBackersSection extends StatelessWidget {
  final String title;
  final List<EventBacker> backers;

  /// Opens a backer's link; null leaves the tiles still.
  final ValueChanged<Uri>? onOpen;

  const EventBackersSection({
    super.key,
    required this.title,
    required this.backers,
    this.onOpen,
  });

  /// The tiles a row holds at [width].
  static int columnsFor(double width) => width >= 560 ? 4 : 3;

  @override
  Widget build(BuildContext context) {
    return EventSection(
      title: title,
      child: LayoutBuilder(builder: (context, constraints) {
        const gap = 10.0;
        final columns = columnsFor(constraints.maxWidth);
        final tile = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: [
            for (final backer in backers)
              SizedBox(
                width: tile,
                child: _BackerTile(
                  key: ValueKey(
                      'backer-${backer.kind.name}-${backer.id ?? backer.name}'),
                  backer: backer,
                  size: tile,
                  onOpen: onOpen,
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _BackerTile extends StatelessWidget {
  final EventBacker backer;
  final double size;
  final ValueChanged<Uri>? onOpen;

  const _BackerTile({
    super.key,
    required this.backer,
    required this.size,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final link = backer.link;
    final initials = Center(
      child: Text(
        backer.initials,
        style: TextStyle(
          fontSize: size * 0.24,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF6B7280),
        ),
      ),
    );
    final tile = Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // The logo as every logo in the app is drawn (ClubLogo): on white
        // whatever the theme, filling its square when it is square, else
        // whole with room around it -- never cropped.
        ClubLogo(
          key: const ValueKey('backer-logo-tile'),
          url: backer.logo,
          size: size,
          radius: 12,
          fallback: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: initials,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          backer.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600, height: 1.25),
        ),
        if (backer.label != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              backer.label!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, height: 1.25, color: Color(0xFF6B7280)),
            ),
          ),
      ],
    );
    final words = [backer.name, if (backer.label != null) backer.label!];
    if (link == null || onOpen == null) {
      return Semantics(
        container: true,
        label: words.join(', '),
        child: ExcludeSemantics(child: tile),
      );
    }
    return Semantics(
      container: true,
      link: true,
      label: '${words.join(', ')}, opens their website',
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onOpen!(link),
          child: tile,
        ),
      ),
    );
  }
}
