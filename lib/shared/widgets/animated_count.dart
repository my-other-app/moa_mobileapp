import 'package:flutter/material.dart';
import 'package:finnet/shared/motion.dart';

/// A number that ticks over rather than jumps: a new count rises in from
/// below as the old one leaves above it when it went up, and drops in from
/// above when it went down -- a like's count, a post's comments.
///
/// [format] draws the number ("1.2K"); the text a screen reader or a test
/// finds is always just the current one, as before.
class AnimatedCount extends StatefulWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    this.format,
  });

  final int value;
  final TextStyle style;
  final String Function(int value)? format;

  @override
  State<AnimatedCount> createState() => _AnimatedCountState();
}

class _AnimatedCountState extends State<AnimatedCount> {
  /// Whether the last change was upwards.
  bool _up = true;

  @override
  void didUpdateWidget(AnimatedCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) _up = widget.value > oldWidget.value;
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.format?.call(widget.value) ?? '${widget.value}';
    final current = ValueKey<int>(widget.value);

    return ClipRect(
      child: AnimatedSwitcher(
        duration: motionDuration(context, Motion.medium),
        switchInCurve: Motion.curve,
        switchOutCurve: Motion.curve,
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.centerStart,
          children: [...previous, if (current != null) current],
        ),
        transitionBuilder: (child, animation) {
          // The new number comes from below (up) or above (down); the old
          // one, its animation running backwards, leaves the other way.
          final incoming = child.key == current;
          final from = (incoming == _up) ? 0.7 : -0.7;
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: Offset(0, from), end: Offset.zero)
                  .animate(animation),
              child: child,
            ),
          );
        },
        child: Text(text, key: current, style: widget.style),
      ),
    );
  }
}
