import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_section.dart';

/// Where to go: a map preview and Directions for a venue, the ticket for an
/// online event.
class EventVenueSection extends StatelessWidget {
  final bool isOnline;
  final String? locationName;
  final double? lat;
  final double? lng;

  /// Opens directions in the phone's maps app; null when there is nothing
  /// to give it (no point, no name, no link).
  final VoidCallback? onDirections;

  const EventVenueSection({
    super.key,
    required this.isOnline,
    this.locationName,
    this.lat,
    this.lng,
    this.onDirections,
  });

  static const directionsKey = ValueKey('event-directions');
  static const mapKey = ValueKey('event-map-preview');

  @override
  Widget build(BuildContext context) {
    if (isOnline) {
      return const EventSection(
        title: 'Online event',
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Tile(icon: Icons.videocam_outlined),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Join from anywhere',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text(
                    'The joining link is on your ticket once you register. '
                    'Keep it handy — it opens when the event starts.',
                    style: TextStyle(fontSize: 13.5, color: Color(0xFF4B5563)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final hasPoint = lat != null && lng != null;
    final name = locationName?.trim() ?? '';
    return EventSection(
      title: 'Venue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasPoint || onDirections != null)
            Semantics(
              button: onDirections != null,
              label: 'Map of ${name.isEmpty ? 'the venue' : name}. '
                  'Opens directions.',
              child: GestureDetector(
                key: mapKey,
                onTap: onDirections,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 7,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(
                          painter: MapPreviewPainter(
                            seed: hasPoint
                                ? (lat! * 1000).round() ^ (lng! * 1000).round()
                                : name.hashCode,
                          ),
                        ),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 18),
                            child: Icon(Icons.location_on,
                                size: 40, color: Color(0xFFDC2626)),
                          ),
                        ),
                        if (onDirections != null)
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x22000000), blurRadius: 4),
                                ],
                              ),
                              child: const Text('Open in Maps',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              const _Tile(icon: Icons.place_outlined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Venue to be announced' : name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    if (hasPoint)
                      const Text('Pinned on the map',
                          style: TextStyle(
                              fontSize: 12.5, color: Color(0xFF6B7280))),
                  ],
                ),
              ),
              if (onDirections != null)
                OutlinedButton.icon(
                  key: directionsKey,
                  onPressed: onDirections,
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text('Directions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2C333D),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;

  const _Tile({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: const Color(0xFF2C333D)),
    );
  }
}

/// A drawn street map: blocks, a few roads and a park, the same for the
/// same venue. It stands for the place rather than showing it -- the real
/// map is one tap away, in the phone's own maps app -- so the page needs
/// no map tiles, no map SDK and no API key.
class MapPreviewPainter extends CustomPainter {
  final int seed;

  MapPreviewPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFEFF1EA));

    // A park and some water.
    final park = Paint()..color = const Color(0xFFD5E8C9);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * (0.05 + random.nextDouble() * 0.5),
            size.height * random.nextDouble() * 0.5, size.width * 0.22,
            size.height * 0.35),
        const Radius.circular(6),
      ),
      park,
    );
    final water = Paint()..color = const Color(0xFFCFE3F0);
    final waterPath = Path()
      ..moveTo(0, size.height * (0.7 + random.nextDouble() * 0.2))
      ..quadraticBezierTo(size.width * 0.3, size.height * 0.95,
          size.width * 0.55, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(waterPath, water);

    // Small streets, then the main roads over them.
    final street = Paint()
      ..color = Colors.white
      ..strokeWidth = 3;
    for (var i = 0; i < 6; i++) {
      final x = size.width * random.nextDouble();
      canvas.drawLine(Offset(x, 0), Offset(x + 30, size.height), street);
      final y = size.height * random.nextDouble();
      canvas.drawLine(Offset(0, y), Offset(size.width, y - 12), street);
    }
    final road = Paint()
      ..color = const Color(0xFFFFE8A3)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = const Color(0xFFE5C76B)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final a = Offset(0, size.height * (0.3 + random.nextDouble() * 0.3));
    final b = Offset(size.width, size.height * (0.2 + random.nextDouble() * 0.5));
    final c = Offset(size.width * (0.3 + random.nextDouble() * 0.4), 0);
    final d = Offset(size.width * (0.4 + random.nextDouble() * 0.3), size.height);
    for (final paint in [edge, road]) {
      canvas.drawLine(a, b, paint);
      canvas.drawLine(c, d, paint);
    }
  }

  @override
  bool shouldRepaint(MapPreviewPainter oldDelegate) => oldDelegate.seed != seed;
}
