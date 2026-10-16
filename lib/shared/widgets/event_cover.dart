import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The cover the app draws for an event that has no poster.
///
/// A port of the event website's drawn covers
/// (`moa_eventwebsite/src/utils/cover.js` and
/// `src/components/discover/cover.jsx`), so an event looks the same in the
/// app as it does on the site: the same palette and shape for the same
/// event, the category in a small outlined tag, and a big date in India
/// time. Never the title -- the card says that once, beside the cover.
///
/// Everything is painted; nothing is fetched. The cover is also what the
/// poster widget shows while a poster loads and when one fails, so a card
/// never collapses to nothing.

/// A stable number for anything: a numeric id is its own seed, text is
/// hashed (32-bit FNV-1a, as the site does it).
int coverSeedOf(Object? value) {
  if (value is int) return value.abs();
  if (value is double && value.isFinite) return value.floor().abs();
  final s = value?.toString() ?? '';
  if (_shortNumber.hasMatch(s)) return int.parse(s);
  var h = 0x811C9DC5;
  for (final unit in s.codeUnits) {
    h ^= unit;
    // h * 16777619, kept to 32 bits. 16777619 is 2^24 + 403; splitting it
    // keeps every step inside 53 bits, so this also holds where ints are
    // doubles.
    h = ((h * 403) + ((h << 24) & 0xFFFFFFFF)) & 0xFFFFFFFF;
  }
  return h;
}

final _shortNumber = RegExp(r'^\d{1,9}$');

/// One of the cover colourings: the site's slate, ink, pale yellow and sky.
///
/// [ink] is the text on the cover, [accent] the main shape, [pop] a small
/// second shape, [line] the strokes and [soft] the quiet fills.
@immutable
class CoverPalette {
  final String name;
  final Color from;
  final Color to;
  final Color ink;
  final Color sub;
  final Color accent;
  final Color pop;
  final Color line;
  final Color soft;

  const CoverPalette({
    required this.name,
    required this.from,
    required this.to,
    required this.ink,
    required this.sub,
    required this.accent,
    required this.pop,
    required this.line,
    required this.soft,
  });

  /// The site's `linear-gradient(160deg, from, to)`.
  LinearGradient get gradient => LinearGradient(
        begin: const Alignment(-0.36, -1),
        end: const Alignment(0.36, 1),
        colors: [from, to],
      );
}

/// The palettes, in the site's order -- the order is part of the look.
const List<CoverPalette> coverPalettes = [
  CoverPalette(
    name: 'night',
    from: Color(0xFF2C3440),
    to: Color(0xFF111827),
    ink: Color(0xFFFFFFFF),
    sub: Color(0xB8FFFFFF),
    accent: Color(0xFFF9FFA1),
    pop: Color(0xFF38BDF8),
    line: Color(0x38FFFFFF),
    soft: Color(0x14FFFFFF),
  ),
  CoverPalette(
    name: 'citron',
    from: Color(0xFFFBFFC8),
    to: Color(0xFFEEF77A),
    ink: Color(0xFF111827),
    sub: Color(0xA8111827),
    accent: Color(0xFF2C3440),
    pop: Color(0xFF0284C7),
    line: Color(0x38111827),
    soft: Color(0x12111827),
  ),
  CoverPalette(
    name: 'sky',
    from: Color(0xFF0284C7),
    to: Color(0xFF075985),
    ink: Color(0xFFFFFFFF),
    sub: Color(0xC7FFFFFF),
    accent: Color(0xFFF9FFA1),
    pop: Color(0xFF111827),
    line: Color(0x4DFFFFFF),
    soft: Color(0x1AFFFFFF),
  ),
  CoverPalette(
    name: 'paper',
    from: Color(0xFFF9FAFB),
    to: Color(0xFFE5E7EB),
    ink: Color(0xFF111827),
    sub: Color(0x9E111827),
    accent: Color(0xFF0284C7),
    pop: Color(0xFFF9FFA1),
    line: Color(0x2E111827),
    soft: Color(0x0F111827),
  ),
  CoverPalette(
    name: 'ink',
    from: Color(0xFF1F2937),
    to: Color(0xFF0B1120),
    ink: Color(0xFFFFFFFF),
    sub: Color(0xB3FFFFFF),
    accent: Color(0xFF38BDF8),
    pop: Color(0xFFF9FFA1),
    line: Color(0x5938BDF8),
    soft: Color(0x1A38BDF8),
  ),
  CoverPalette(
    name: 'mist',
    from: Color(0xFFEEF9FF),
    to: Color(0xFFC4E8FB),
    ink: Color(0xFF111827),
    sub: Color(0x9E111827),
    accent: Color(0xFF0284C7),
    pop: Color(0xFF2C3440),
    line: Color(0x4D0284C7),
    soft: Color(0x1A0284C7),
  ),
];

/// The shapes a cover can carry, in the site's order.
enum CoverMotif { rings, grid, burst, arches, bars, waves, stripes, blocks }

/// The look of one cover: its colours, its shape, and which of three
/// placements of that shape.
@immutable
class CoverLook {
  final CoverPalette palette;
  final CoverMotif motif;

  /// 0, 1 or 2. Nudges the shape sideways; 2 also mirrors it.
  final int variant;

  const CoverLook({
    required this.palette,
    required this.motif,
    required this.variant,
  });

  @override
  bool operator ==(Object other) =>
      other is CoverLook &&
      other.palette.name == palette.name &&
      other.motif == motif &&
      other.variant == variant;

  @override
  int get hashCode => Object.hash(palette.name, motif, variant);

  @override
  String toString() => 'CoverLook(${palette.name}, ${motif.name}, $variant)';
}

/// The look of a generated cover, the same every time for the same event:
///  - the colour comes from the event id, so neighbours differ;
///  - the shape comes from a small set that belongs to the category (three
///    shapes each), picked by the id -- a row of workshops reads as one
///    family without being eight copies of the same picture.
///
/// [category] is the category's id, or the category map from the API.
CoverLook coverLook({Object? id, Object? category}) {
  final idSeed = coverSeedOf(id);
  final catId = category is Map ? category['id'] : category;
  final hasCat = catId != null && catId != '';
  final shape = hasCat ? coverSeedOf(catId) * 3 + ((idSeed ~/ 2) % 3) : idSeed;
  return CoverLook(
    palette: coverPalettes[idSeed % coverPalettes.length],
    motif: CoverMotif.values[shape % CoverMotif.values.length],
    variant: (idSeed ~/ coverPalettes.length) % 3,
  );
}

/// The date pieces a cover shows, in India time.
@immutable
class CoverDate {
  /// "7", "17" -- not zero-padded.
  final String day;

  /// "Oct".
  final String month;

  /// "Sat".
  final String weekday;

  const CoverDate(this.day, this.month, this.weekday);
}

const _ist = Duration(hours: 5, minutes: 30);
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// The day, month and weekday of [at] in India time, whatever the phone's
/// own time zone; null when there is no date.
CoverDate? coverDateParts(DateTime? at) {
  if (at == null) return null;
  final ist = at.toUtc().add(_ist);
  return CoverDate(
    '${ist.day}',
    _months[ist.month - 1],
    _weekdays[ist.weekday - 1],
  );
}

/// An event's start from the API's `event_datetime`, or null.
///
/// The server sends an offset (`+05:30`). A time without one is India
/// time -- that is what the server means by it
/// (`app/core/response/base_model.py`) -- not the phone's.
DateTime? parseEventStart(Object? raw) {
  if (raw is DateTime) return raw;
  if (raw is! String) return null;
  final s = raw.trim();
  if (s.isEmpty) return null;
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return null;
  // Dart returns a UTC time exactly when the text carried a zone.
  if (parsed.isUtc) return parsed;
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
  ).subtract(_ist);
}

/// The drawn cover for an event without a poster.
///
/// Fills whatever box it is given. The art is laid out for a 4:5 card and
/// cropped from the top to fit other shapes, as the site does; the text
/// scales with the box, drops the category tag in small boxes, and becomes
/// a little calendar leaf in tiny ones (a search-result thumbnail).
class EventCover extends StatelessWidget {
  /// The event's id: picks the colours and, with the category, the shape.
  final Object? eventId;

  /// The category's id. Events in one category share a family of shapes.
  final Object? categoryId;

  /// Shown in the tag, e.g. "Workshop".
  final String? categoryName;

  /// When the event starts; shown in India time.
  final DateTime? startsAt;

  /// Labels the tag "Online" when there is no category.
  final bool isOnline;

  /// Overrides the tag's text.
  final String? label;

  const EventCover({
    super.key,
    required this.eventId,
    this.categoryId,
    this.categoryName,
    this.startsAt,
    this.isOnline = false,
    this.label,
  });

  /// The text in the tag: the label, else the category, else "Online".
  String get kind {
    final given = label?.trim();
    if (given != null) return given;
    final category = categoryName?.trim() ?? '';
    if (category.isNotEmpty) return category;
    return isOnline ? 'Online' : '';
  }

  @override
  Widget build(BuildContext context) {
    final look = coverLook(id: eventId, category: categoryId);
    final date = coverDateParts(startsAt);
    final kind = this.kind;

    return LayoutBuilder(builder: (context, constraints) {
      // Something has to give the cover a size; if nothing does, take the
      // card's shape rather than throwing.
      final w = constraints.hasBoundedWidth
          ? constraints.maxWidth
          : (constraints.hasBoundedHeight
              ? constraints.maxHeight * 0.8
              : 200.0);
      final h = constraints.hasBoundedHeight ? constraints.maxHeight : w * 1.25;
      final tiny = _textUnit(w, h) < _tinyUnit;

      return SizedBox(
        width: w,
        height: h,
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: look.palette.gradient),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // In a thumbnail the shape would only fight the date.
                if (!tiny) CustomPaint(painter: CoverArtPainter(look)),
                // The cover is a picture: its text is sized to the box, not
                // to the reader's text size, or it would overflow it.
                MediaQuery.withNoTextScaling(
                  child: _CoverText(
                    width: w,
                    height: h,
                    ink: look.palette.ink,
                    kind: kind,
                    date: date,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// The site sizes the cover's text by the card's width, and its cards are
/// 4:5. Measuring against the 4:5 box that fits keeps a wide or square box
/// from getting a date too tall for it.
double _textUnit(double width, double height) => math.min(width, height * 0.8);

/// Below this the cover is a thumbnail: just the month over the day.
const double _tinyUnit = 96;

class _CoverText extends StatelessWidget {
  final double width;
  final double height;
  final Color ink;
  final String kind;
  final CoverDate? date;

  const _CoverText({
    required this.width,
    required this.height,
    required this.ink,
    required this.kind,
    required this.date,
  });

  static const _display = 'BebasNeue';

  @override
  Widget build(BuildContext context) {
    final unit = _textUnit(width, height);
    final cq = unit / 100;
    final date = this.date;

    if (unit < _tinyUnit) {
      // Too small for the tag or a sideways date: a calendar leaf, the
      // month over the day, centred.
      if (date == null) return const SizedBox.shrink();
      final side = math.min(width, height);
      return Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                date.month.toUpperCase(),
                style: _style(math.max(8.0, side * 0.24), 1, 0.06),
              ),
              Text(date.day, style: _style(side * 0.52, 0.9, 0)),
            ],
          ),
        ),
      );
    }

    final compact = unit <= 150;
    final pad = unit * (compact ? 0.10 : 0.08);
    final showKind = !compact && kind.isNotEmpty;
    final kindSize = (6.4 * cq).clamp(12.0, 20.0).toDouble();
    final daySize = 42 * cq;
    final monSize = 12 * cq;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showKind)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 3),
              decoration: BoxDecoration(
                border: Border.all(color: ink, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                kind.toUpperCase(),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: _style(kindSize, 1, 0.08),
              ),
            ),
          if (showKind && date != null) const SizedBox(height: 8),
          if (date != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(date.day, style: _style(daySize, 0.76, -0.01)),
                  SizedBox(width: daySize * 0.05),
                  Padding(
                    padding: EdgeInsets.only(bottom: monSize * 0.1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date.month.toUpperCase(),
                          style: _style(monSize, 0.86, 0.04),
                        ),
                        SizedBox(height: monSize * 0.08),
                        Text(
                          date.weekday.toUpperCase(),
                          style: _style(monSize, 0.86, 0.04,
                              ink.withValues(alpha: ink.a * 0.66)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Bebas Neue at [size], with a CSS-like line height (the leading split
  /// above and below) and letter spacing in ems.
  TextStyle _style(double size, double lineHeight, double trackingEm,
          [Color? color]) =>
      TextStyle(
        fontFamily: _display,
        fontSize: size,
        height: lineHeight,
        leadingDistribution: TextLeadingDistribution.even,
        letterSpacing: size * trackingEm,
        color: color ?? ink,
      );
}

/// Paints a cover's shape. Laid out on the site's 100 x 125 canvas, scaled
/// to cover the box and pinned to its top -- SVG's `xMidYMin slice`.
class CoverArtPainter extends CustomPainter {
  final CoverLook look;

  const CoverArtPainter(this.look);

  static const double _w = 100;
  static const double _h = 125;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final s = math.max(size.width / _w, size.height / _h);
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.translate((size.width - _w * s) / 2, 0);
    canvas.scale(s);
    if (look.variant == 2) {
      canvas.translate(_w, 0);
      canvas.scale(-1, 1);
    }
    _paintMotif(canvas, look.motif, _w, _h, look.palette, look.variant);
    canvas.restore();
  }

  @override
  bool shouldRepaint(CoverArtPainter oldDelegate) => oldDelegate.look != look;
}

const _barHeights = [0.42, 0.6, 0.3, 0.54, 0.36, 0.64, 0.46];
const _rays = 20;

Paint _fill(Color color) => Paint()
  ..color = color
  ..style = PaintingStyle.fill;

Paint _stroke(Color color, double width, [StrokeCap cap = StrokeCap.butt]) =>
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = cap;

/// Rotates what [draw] paints by [degrees] about ([cx], [cy]).
void _rotated(
    Canvas canvas, double degrees, double cx, double cy, void Function() draw) {
  canvas.save();
  canvas.translate(cx, cy);
  canvas.rotate(degrees * math.pi / 180);
  canvas.translate(-cx, -cy);
  draw();
  canvas.restore();
}

/// A wave across the box at height [y], in smooth quadratic segments that
/// alternate up and down (the site's `q` then repeated `t`).
Path _wave(double y, double w, double amp, double len) {
  final path = Path()..moveTo(-len, y);
  var x0 = -len;
  var dir = -1.0;
  void segment() {
    path.quadraticBezierTo(x0 + len / 4, y + dir * amp, x0 + len / 2, y);
    x0 += len / 2;
    dir = -dir;
  }

  segment();
  for (var x = -len / 2; x < w + len; x += len / 2) {
    segment();
  }
  return path;
}

/// The shape on a cover. Everything sits in the top part, leaving the
/// bottom for the date.
void _paintMotif(
  Canvas canvas,
  CoverMotif motif,
  double w,
  double h,
  CoverPalette c,
  int v,
) {
  final m = math.min(w, h);
  final shift = const [0.0, 0.07, -0.05][v];

  switch (motif) {
    case CoverMotif.rings:
      final cx = w * (0.72 + shift);
      final cy = h * 0.26;
      final r = m * 0.19;
      for (final k in const [2.3, 1.9, 1.5]) {
        canvas.drawCircle(Offset(cx, cy), r * k, _stroke(c.line, m * 0.012));
      }
      canvas.drawCircle(Offset(cx, cy), r, _fill(c.accent));
      canvas.drawCircle(
        Offset(cx - r * 1.9 * 0.72, cy + r * 1.9 * 0.7),
        m * 0.035,
        _fill(c.pop),
      );

    case CoverMotif.grid:
      final step = m * 0.075;
      final dotR = m * 0.009;
      final bottom = h * 0.64;
      final dot = _fill(c.line);
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, w, bottom));
      for (var y = step / 2; y - dotR < bottom; y += step) {
        for (var x = step / 2; x - dotR < w; x += step) {
          canvas.drawCircle(Offset(x, y), dotR, dot);
        }
      }
      canvas.restore();
      final corner = Offset(w * (1 + shift), 0);
      canvas.drawCircle(corner, m * 0.72, _stroke(c.line, m * 0.012));
      canvas.drawCircle(corner, m * 0.56, _fill(c.accent));
      final side = m * 0.12;
      final x = w * 0.16;
      final y = h * 0.24;
      _rotated(canvas, 45, x + side / 2, y + side / 2, () {
        canvas.drawRect(Rect.fromLTWH(x, y, side, side), _fill(c.pop));
      });

    case CoverMotif.burst:
      final cx = w * (0.7 + shift);
      final cy = h * 0.28;
      final r1 = m * 0.13;
      final r2 = m * 0.46;
      final ray = _stroke(c.accent, m * 0.026, StrokeCap.round);
      for (var i = 0; i < _rays; i++) {
        final a = (i / _rays) * math.pi * 2;
        final r = i.isOdd ? r2 * 0.74 : r2;
        canvas.drawLine(
          Offset(cx + math.cos(a) * r1, cy + math.sin(a) * r1),
          Offset(cx + math.cos(a) * r, cy + math.sin(a) * r),
          ray,
        );
      }
      canvas.drawCircle(Offset(cx, cy), m * 0.075, _fill(c.pop));

    case CoverMotif.arches:
      final cx = w * (0.88 + shift / 2);
      final cy = h * 0.5;
      final colors = [c.accent, c.line, c.accent, c.pop];
      const radii = [0.64, 0.51, 0.38, 0.25];
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, w, cy));
      for (var i = 0; i < radii.length; i++) {
        canvas.drawCircle(
          Offset(cx, cy),
          m * radii[i],
          _stroke(colors[i], m * 0.075),
        );
      }
      canvas.restore();

    case CoverMotif.bars:
      final n = _barHeights.length;
      final gap = w * 0.035;
      final x0 = w * 0.2;
      final bw = (w * 0.76 - gap * (n - 1)) / n;
      for (var i = 0; i < n; i++) {
        final k = _barHeights[(i + v * 2) % n];
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x0 + i * (bw + gap), -bw, bw, h * k * 0.95 + bw),
            Radius.circular(bw / 2),
          ),
          _fill(i == 2 + v ? c.pop : c.accent),
        );
      }

    case CoverMotif.waves:
      final len = m * 0.28;
      final amp = m * 0.035;
      for (var i = 0; i < 6; i++) {
        canvas.drawPath(
          _wave(h * 0.1 + i * m * 0.075, w, amp, len),
          _stroke(i == 3 ? c.pop : c.accent, m * 0.022, StrokeCap.round),
        );
      }

    case CoverMotif.stripes:
      final cx = w * (0.68 + shift);
      final cy = h * 0.27;
      final s = m * 0.06;
      final r = m * 0.34;
      canvas.drawCircle(
        Offset(cx + m * 0.1, cy - m * 0.06),
        r,
        _stroke(c.line, m * 0.012),
      );
      // A disc of 45-degree stripes: half-width bars every [s], drawn in
      // the stripes' own rotated frame and clipped to the disc.
      canvas.save();
      canvas.clipPath(
          Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
      canvas.rotate(math.pi / 4);
      const k = math.sqrt1_2;
      final px = cx * k + cy * k;
      final py = -cx * k + cy * k;
      final stripe = _fill(c.accent);
      for (var i = ((px - r) / s).floor() - 1;
          i <= ((px + r) / s).ceil() + 1;
          i++) {
        canvas.drawRect(
          Rect.fromLTWH(i * s, py - r - s, s / 2, 2 * (r + s)),
          stripe,
        );
      }
      canvas.restore();
      canvas.drawCircle(
          Offset(cx - m * 0.3, cy + m * 0.28), m * 0.05, _fill(c.pop));

    case CoverMotif.blocks:
      final bx = w * (0.48 + shift);
      final size = m * 0.48;
      _rotated(canvas, 14, bx + size / 2, size / 2, () {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(bx, -m * 0.08, size, size),
            Radius.circular(m * 0.06),
          ),
          _fill(c.accent),
        );
      });
      final ox = w * 0.26;
      final oy = h * 0.16;
      final os = m * 0.3;
      _rotated(canvas, -12, ox + os / 2, oy + os / 2, () {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(ox, oy, os, os),
            Radius.circular(m * 0.05),
          ),
          _stroke(c.line, m * 0.014),
        );
      });
      canvas.drawCircle(Offset(w * 0.86, h * 0.5), m * 0.07, _fill(c.pop));
  }
}
