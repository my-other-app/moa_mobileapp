import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:finnet/shared/motion.dart';

/// A list whose first rows come in one after another the first time it is
/// shown: wrap the list, and each row in an [Entrance] with its index.
///
/// Only the first [Motion.staggered] rows, and only while the list is
/// first appearing: a row built later -- scrolled to, scrolled back to,
/// the next page arriving -- is simply there. So a list never replays its
/// entrance as it is scrolled.
class EntranceScope extends StatefulWidget {
  const EntranceScope({super.key, required this.child});

  final Widget child;

  /// How long after the list first appears a row may still come in.
  static const window = Duration(milliseconds: 400);

  @override
  State<EntranceScope> createState() => _EntranceScopeState();
}

class _EntranceScopeState extends State<EntranceScope> {
  Duration? _shownAt;
  final Set<int> _seen = {};

  /// The current frame's time: the same clock a test's pumps move.
  static Duration get _now =>
      SchedulerBinding.instance.currentSystemFrameTimeStamp;

  /// Whether the row at [index] should come in: one of the first rows, built
  /// for the first time, while the list is first appearing.
  bool _claim(int index) {
    if (index >= Motion.staggered || !_seen.add(index)) return false;
    final shownAt = _shownAt ??= _now;
    return _now - shownAt <= EntranceScope.window;
  }

  @override
  Widget build(BuildContext context) =>
      _EntranceClock(state: this, child: widget.child);
}

class _EntranceClock extends InheritedWidget {
  const _EntranceClock({required this.state, required super.child});

  final _EntranceScopeState state;

  static _EntranceScopeState? maybeOf(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<_EntranceClock>()?.widget
              as _EntranceClock?)
          ?.state;

  @override
  bool updateShouldNotify(_EntranceClock oldWidget) => false;
}

/// One row of an [EntranceScope]'s list: it fades in and rises
/// [Motion.entranceOffset] into place, a little after the row above it.
///
/// Outside a scope, or with less motion asked for, it is just [child].
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.index, required this.child});

  /// The row's place in the list, from 0.
  final int index;
  final Widget child;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _progress;
  bool _decided = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;
    final scope = _EntranceClock.maybeOf(context);
    if (scope == null || reduceMotion(context) || !scope._claim(widget.index)) {
      return;
    }
    final delay = Motion.stagger * widget.index;
    final total = delay + Motion.slow;
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    _progress = CurvedAnimation(
      parent: controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Motion.curve,
      ),
    );
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    if (progress == null) return widget.child;
    return AnimatedBuilder(
      animation: progress,
      child: widget.child,
      builder: (context, child) {
        final t = progress.value;
        // The same widgets at the end as during, so nothing under them is
        // rebuilt from scratch when the entrance finishes.
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * Motion.entranceOffset),
            child: child,
          ),
        );
      },
    );
  }
}
