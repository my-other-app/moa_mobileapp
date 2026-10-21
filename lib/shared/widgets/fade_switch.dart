import 'package:flutter/widgets.dart';
import 'package:finnet/shared/motion.dart';

/// What a screen is showing: its skeleton, its content, or why it has none.
///
/// [FadeSwitch] cross-fades when this changes, and only then: new data in
/// content already on screen is just drawn.
enum ScreenPhase { loading, content, empty, error }

/// The skeleton giving way to the content (or the error) with a short
/// cross-fade rather than a pop.
///
/// The one leaving is out of the way while it fades: it takes no touches,
/// says nothing to a screen reader, and lets go of the page's scroll
/// controller, so the content arriving is the one the status bar scrolls.
class FadeSwitch extends StatelessWidget {
  const FadeSwitch({
    super.key,
    required this.phase,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  /// Which of the screen's states [child] is; a change of it cross-fades.
  final ScreenPhase phase;
  final Widget child;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: motionDuration(context, Motion.medium),
      switchInCurve: Motion.curve,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        fit: StackFit.passthrough,
        alignment: alignment,
        children: [
          for (final leaving in previous)
            // Kept at their size, but not in charge of the stack's.
            Positioned.fill(
              child: IgnorePointer(
                child: ExcludeSemantics(
                  // A hero on its way out is not the page's hero.
                  child: HeroMode(
                    enabled: false,
                    child: PrimaryScrollController.none(child: leaving),
                  ),
                ),
              ),
            ),
          if (current != null) current,
        ],
      ),
      child: KeyedSubtree(key: ValueKey(phase), child: child),
    );
  }
}
