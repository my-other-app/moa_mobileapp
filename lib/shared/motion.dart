import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The app's motion, in one place: how long things take and how they ease.
///
/// Small and quick -- a press, a like, a chip -- so the app answers a touch
/// without making anyone wait for it. Everything eases out: fast at first,
/// settling into place, the way a thing that was pushed comes to rest.
///
/// Every animation asks [reduceMotion] first. When the phone asks for less
/// motion -- Reduce Motion on an iPhone, animations off on Android, or a
/// screen reader running -- there is none: things simply change.
abstract final class Motion {
  /// A press going down, a colour changing, a chip being chosen.
  static const fast = Duration(milliseconds: 150);

  /// Most changes of state: a count ticking over, a button's label, a bar.
  static const medium = Duration(milliseconds: 220);

  /// The largest: content arriving, a list's rows coming in.
  static const slow = Duration(milliseconds: 300);

  /// How much later each of a list's first rows starts than the one above.
  static const stagger = Duration(milliseconds: 40);

  /// Only a list's first rows come in one after another; any row past them
  /// (scrolled to later) is simply there.
  static const staggered = 8;

  /// How far a row rises as it comes in.
  static const entranceOffset = 12.0;

  /// The easing for almost everything.
  static const curve = Curves.easeOutCubic;

  /// The easing back out of a press.
  static const releaseCurve = Curves.easeOut;

  /// How small something gets while pressed.
  static const pressedScale = 0.97;
}

/// Whether to leave animation out: the phone asks for less motion, or a
/// screen reader is running (where movement only gets in the way).
bool reduceMotion(BuildContext context) {
  final media = MediaQuery.maybeOf(context);
  if (media != null &&
      (media.disableAnimations || media.accessibleNavigation)) {
    return true;
  }
  // iOS's Reduce Motion is its own flag, not "disable animations".
  final view = View.maybeOf(context);
  return view?.platformDispatcher.accessibilityFeatures.reduceMotion ?? false;
}

/// [duration], or none at all when [reduceMotion] says so: for an implicit
/// animation (an AnimatedContainer, an AnimatedSwitcher) to jump straight to
/// its end.
Duration motionDuration(BuildContext context, Duration duration) =>
    reduceMotion(context) ? Duration.zero : duration;

/// [child], easing to each new size on the app's timing -- or, with less
/// motion asked for, simply taking it. (An [AnimatedSize] cannot be given
/// no time at all: it would re-lay itself out mid-layout.)
class EasedSize extends StatelessWidget {
  const EasedSize({
    super.key,
    required this.child,
    this.duration = Motion.medium,
    this.alignment = Alignment.center,
  });

  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return child;
    return AnimatedSize(
      duration: duration,
      curve: Motion.curve,
      alignment: alignment,
      child: child,
    );
  }
}

/// The taps the app gives back, kept to two.
///
/// Through the platform channel, as [HapticFeedback] is, so a test can
/// listen on `SystemChannels.platform` for what was felt.
abstract final class Haptics {
  /// Something was done: a like, a follow, a vote.
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Something was chosen: a tab, a chip, a switch.
  static Future<void> selection() => HapticFeedback.selectionClick();
}
