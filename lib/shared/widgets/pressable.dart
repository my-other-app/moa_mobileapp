import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:finnet/shared/motion.dart';

/// A touch you can see: [child] sinks a little while a finger is on it and
/// springs back when it lifts.
///
/// Only the look. The tap itself is still [child]'s own -- its InkWell, its
/// button -- so wrapping something changes nothing about what it does, what
/// a screen reader says, or what a test taps.
///
/// Careful with scrolling: the press waits a moment ([delay]) before it
/// shows, and a finger that moves is a scroll, not a press -- so flicking
/// through a list of cards does not set them all twitching. A tap quicker
/// than [delay] still gets one short dip.
///
/// A Pressable inside another (a like button on a card) keeps the touch to
/// itself: pressing the button does not sink the card.
///
/// Nothing moves when [enabled] is false, or when the phone asks for less
/// motion ([reduceMotion]).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.enabled = true,
    this.scale = Motion.pressedScale,
  });

  final Widget child;

  /// False for something that cannot be tapped now: it stays still.
  final bool enabled;

  /// How small [child] gets while pressed: 0.97 for a card or a button;
  /// smaller for a small icon, where 3% would not be seen.
  final double scale;

  /// How long a finger rests before the press shows.
  static const delay = Duration(milliseconds: 50);

  @override
  State<Pressable> createState() => PressableState();
}

/// Public for tests, which read [pressed] and [scale].
class PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: Motion.fast,
    reverseDuration: Motion.medium,
  );
  late final Animation<double> _scale = _press.drive(CurveTween(
    curve: Motion.curve,
  ));

  /// The finger being followed, while there is one.
  int? _pointer;
  Offset _origin = Offset.zero;
  Timer? _wait;

  /// Pointers a Pressable inside this one has already taken.
  final Set<int> _claimed = {};

  /// Whether it is drawn pressed now (or on its way down).
  bool get pressed =>
      _press.status == AnimationStatus.forward ||
      _press.status == AnimationStatus.completed;

  /// The scale it is drawn at: 1 at rest, [Pressable.scale] fully pressed.
  double get scale => 1 - (1 - widget.scale) * _scale.value;

  /// A Pressable inside this one has the touch [pointer]: so does every
  /// Pressable around this one.
  void _claim(int pointer) {
    _claimed.add(pointer);
    _PressScope.maybeOf(context)?._claim(pointer);
  }

  bool get _live => widget.enabled && !reduceMotion(context);

  void _down(PointerDownEvent event) {
    // Taken first by a Pressable inside: the press is that one's.
    if (_claimed.remove(event.pointer)) return;
    // Whatever happens here, the Pressables around this one stay still.
    _PressScope.maybeOf(context)?._claim(event.pointer);
    if (_pointer != null || !_live) return;
    _pointer = event.pointer;
    _origin = event.position;
    _wait?.cancel();
    _wait = Timer(Pressable.delay, () {
      _wait = null;
      if (mounted && _pointer != null) _press.forward();
    });
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    // Moved: a scroll or a drag, not a press. Straight back.
    if ((event.position - _origin).distance > kTouchSlop) _letGo(tapped: false);
  }

  void _up(PointerUpEvent event) {
    _claimed.remove(event.pointer);
    if (event.pointer == _pointer) _letGo(tapped: true);
  }

  void _cancel(PointerCancelEvent event) {
    _claimed.remove(event.pointer);
    if (event.pointer == _pointer) _letGo(tapped: false);
  }

  void _letGo({required bool tapped}) {
    _pointer = null;
    final waiting = _wait?.isActive ?? false;
    _wait?.cancel();
    _wait = null;
    if (waiting) {
      // A tap quicker than the wait: one short dip, so it was seen.
      if (tapped && _live) {
        _press.forward().whenCompleteOrCancel(() {
          if (mounted && _pointer == null) _press.reverse();
        });
      }
      return;
    }
    if (_press.status == AnimationStatus.forward && tapped) {
      // Still going down: finish, then come back up.
      _press.forward().whenCompleteOrCancel(() {
        if (mounted && _pointer == null) _press.reverse();
      });
      return;
    }
    _press.reverse();
  }

  @override
  void didUpdateWidget(Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _wait?.cancel();
      _pointer = null;
      _press.value = 0;
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PressScope(
      state: this,
      child: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: _up,
        onPointerCancel: _cancel,
        child: AnimatedBuilder(
          animation: _scale,
          // The child is built once; only the transform changes per frame.
          child: widget.child,
          // Always the Transform, at 1 when at rest: swapping it in and out
          // would rebuild everything under the finger.
          builder: (context, child) =>
              Transform.scale(scale: scale, child: child),
        ),
      ),
    );
  }
}

/// How a Pressable tells the ones around it that a touch is its own.
class _PressScope extends InheritedWidget {
  const _PressScope({required this.state, required super.child});

  final PressableState state;

  static PressableState? maybeOf(BuildContext context) =>
      (context.getElementForInheritedWidgetOfExactType<_PressScope>()?.widget
              as _PressScope?)
          ?.state;

  @override
  bool updateShouldNotify(_PressScope oldWidget) => false;
}
