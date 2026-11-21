import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/motion.dart';

/// The app's loading spinner: an ink arc with rounded ends running round a
/// faint ring of the same ink, in place of Material's square-ended arc in
/// the theme's primary colour.
///
/// Takes what a [CircularProgressIndicator] takes, so it drops in where one
/// was: it fills the box it is given (a [SizedBox] in a button), or is
/// [defaultSize] across on its own. With [value] it shows that much of the
/// ring (an upload's progress); without, it turns.
///
/// On a dark fill (an ink button) give it white: the ring follows the arc's
/// colour. With less motion asked for, it still turns -- a spinner that
/// stops reads as frozen -- but the arc no longer stretches.
class AppSpinner extends StatefulWidget {
  const AppSpinner({
    super.key,
    this.value,
    this.color,
    this.valueColor,
    this.backgroundColor,
    this.strokeWidth,
    this.strokeCap,
    this.semanticsLabel,
    this.semanticsValue,
    this.size,
  });

  /// A small one for inside a button or beside a line of text.
  const AppSpinner.small({
    super.key,
    this.color,
    this.semanticsLabel,
  })  : value = null,
        valueColor = null,
        backgroundColor = null,
        strokeWidth = 2,
        strokeCap = null,
        semanticsValue = null,
        size = 16;

  /// How far round, 0 to 1; null turns.
  final double? value;

  /// The arc's colour; [AppColors.ink] when neither this nor [valueColor].
  final Color? color;

  /// As a [CircularProgressIndicator]'s: wins over [color].
  final Animation<Color?>? valueColor;

  /// The ring under the arc; a faint wash of the arc's colour when null.
  final Color? backgroundColor;

  /// The line's width; a tenth of the spinner across (2 to 3.5) when null.
  final double? strokeWidth;

  /// Accepted for a [CircularProgressIndicator]'s callers; the ends are
  /// always round unless [StrokeCap.butt] is asked for.
  final StrokeCap? strokeCap;

  final String? semanticsLabel;
  final String? semanticsValue;

  /// Across, when the box it is in does not say.
  final double? size;

  /// Across, alone.
  static const defaultSize = 28.0;

  /// One turn of the arc.
  static const turn = Duration(milliseconds: 1100);

  @override
  State<AppSpinner> createState() => _AppSpinnerState();
}

class _AppSpinnerState extends State<AppSpinner>
    with SingleTickerProviderStateMixin {
  // Three turns while the arc stretches and shrinks twice.
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(vsync: this, duration: AppSpinner.turn * 3);
    if (widget.value == null) _clock.repeat();
  }

  @override
  void didUpdateWidget(AppSpinner old) {
    super.didUpdateWidget(old);
    if (widget.value == null && !_clock.isAnimating) {
      _clock.repeat();
    } else if (widget.value != null && _clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  Color get _arc => widget.valueColor?.value ?? widget.color ?? AppColors.ink;

  @override
  Widget build(BuildContext context) {
    final arc = _arc;
    final ring = widget.backgroundColor ??
        arc.withValues(alpha: arc.computeLuminance() > 0.5 ? 0.28 : 0.12);
    final steady = reduceMotion(context);
    final size = widget.size ?? AppSpinner.defaultSize;
    final value = widget.value;
    Widget paint(double t) => CustomPaint(
          painter: AppSpinnerPainter(
            arc: arc,
            ring: ring,
            value: value?.clamp(0.0, 1.0),
            t: t,
            steady: steady,
            strokeWidth: widget.strokeWidth,
            cap: widget.strokeCap == StrokeCap.butt
                ? StrokeCap.butt
                : StrokeCap.round,
          ),
        );
    return Semantics(
      label: widget.semanticsLabel,
      value: widget.semanticsValue ??
          (value == null ? null : '${(value.clamp(0.0, 1.0) * 100).round()}%'),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: size, minHeight: size),
        child: value != null
            ? paint(0)
            : AnimatedBuilder(
                animation: _clock,
                builder: (_, __) => paint(_clock.value),
              ),
      ),
    );
  }
}

/// Draws [AppSpinner]: public so a test can read what it would draw.
class AppSpinnerPainter extends CustomPainter {
  AppSpinnerPainter({
    required this.arc,
    required this.ring,
    required this.t,
    this.value,
    this.steady = false,
    this.strokeWidth,
    this.cap = StrokeCap.round,
  });

  final Color arc;
  final Color ring;
  final double? value;

  /// Where in its three-turn cycle the spinner is, 0 to 1.
  final double t;

  /// No stretching (less motion).
  final bool steady;
  final double? strokeWidth;
  final StrokeCap cap;

  /// The share of the ring the turning arc covers, at [t].
  static double sweepAt(double t, {bool steady = false}) {
    if (steady) return 0.3;
    // Twice a cycle: from a short arc to most of the ring and back.
    final wave = 0.5 - 0.5 * math.cos(t * 2 * math.pi * 2);
    return 0.1 + 0.55 * wave;
  }

  double widthFor(Size size) =>
      strokeWidth ?? (size.shortestSide / 10).clamp(2.0, 3.5);

  @override
  void paint(Canvas canvas, Size size) {
    final width = widthFor(size);
    final rect = (Offset.zero & size).deflate(width / 2);
    final square = Rect.fromCenter(
      center: rect.center,
      width: rect.shortestSide,
      height: rect.shortestSide,
    );
    canvas.drawArc(
      square,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
    final line = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = cap;
    final known = value;
    if (known != null) {
      if (known <= 0) return;
      canvas.drawArc(square, -math.pi / 2, 2 * math.pi * known, false, line);
      return;
    }
    final sweep = sweepAt(t, steady: steady);
    final start = -math.pi / 2 + t * 2 * math.pi * 3;
    canvas.drawArc(square, start, 2 * math.pi * sweep, false, line);
  }

  @override
  bool shouldRepaint(AppSpinnerPainter old) =>
      old.t != t ||
      old.value != value ||
      old.arc != arc ||
      old.ring != ring ||
      old.steady != steady ||
      old.strokeWidth != strokeWidth ||
      old.cap != cap;
}

/// A whole screen, or a part of one, waiting: the [AppSpinner] in the
/// middle, with an optional line under it. Said as "Loading" to a screen
/// reader.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({
    super.key,
    this.message,
    this.color,
    this.size = AppSpinner.defaultSize,
    this.padding = EdgeInsets.zero,
  });

  /// "Reading your tickets…": a line under the spinner.
  final String? message;
  final Color? color;
  final double size;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: padding,
        child: Semantics(
          label: message ?? 'Loading',
          liveRegion: true,
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: size,
                child: AppSpinner(color: color),
              ),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280), height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The app's progress bar: a rounded ink bar on a soft grey track, in
/// place of Material's square one. Takes what a [LinearProgressIndicator]
/// takes; without [value], a short bar slides along.
class AppProgressBar extends StatefulWidget {
  const AppProgressBar({
    super.key,
    this.value,
    this.minHeight,
    this.color,
    this.valueColor,
    this.backgroundColor,
    this.borderRadius,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double? value;

  /// The bar's height; 4 when null.
  final double? minHeight;
  final Color? color;
  final Animation<Color?>? valueColor;
  final Color? backgroundColor;
  final BorderRadiusGeometry? borderRadius;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  State<AppProgressBar> createState() => _AppProgressBarState();
}

class _AppProgressBarState extends State<AppProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock;

  @override
  void initState() {
    super.initState();
    _clock = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    if (widget.value == null) _clock.repeat();
  }

  @override
  void didUpdateWidget(AppProgressBar old) {
    super.didUpdateWidget(old);
    if (widget.value == null && !_clock.isAnimating) {
      _clock.repeat();
    } else if (widget.value != null && _clock.isAnimating) {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.minHeight ?? 4;
    final fill = widget.valueColor?.value ?? widget.color ?? AppColors.ink;
    final track = widget.backgroundColor ?? AppColors.softGrey;
    final radius = widget.borderRadius ?? BorderRadius.circular(height);
    final value = widget.value?.clamp(0.0, 1.0);
    Widget bar(double t) => LayoutBuilder(builder: (context, box) {
          final width = box.maxWidth.isFinite ? box.maxWidth : 0.0;
          final double left;
          final double length;
          if (value != null) {
            left = 0;
            length = width * value;
          } else {
            // A third of the track, sliding in from the left and out at the
            // right.
            length = width / 3;
            left = -length + (width + length) * Curves.easeInOut.transform(t);
          }
          return ClipRRect(
            borderRadius: radius,
            child: SizedBox(
              height: height,
              width: width,
              child: Stack(children: [
                Positioned.fill(child: ColoredBox(color: track)),
                Positioned(
                  left: left,
                  top: 0,
                  bottom: 0,
                  width: length,
                  child: DecoratedBox(
                    decoration:
                        BoxDecoration(color: fill, borderRadius: radius),
                  ),
                ),
              ]),
            ),
          );
        });
    return Semantics(
      label: widget.semanticsLabel,
      value: widget.semanticsValue ??
          (value == null ? null : '${(value * 100).round()}%'),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(minWidth: double.infinity, minHeight: height),
        child: value != null
            ? bar(0)
            : AnimatedBuilder(
                animation: _clock, builder: (_, __) => bar(_clock.value)),
      ),
    );
  }
}
