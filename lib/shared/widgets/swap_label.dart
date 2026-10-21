import 'package:flutter/material.dart';
import 'package:finnet/shared/motion.dart';

/// A button's label that changes with what the button does -- FOLLOW,
/// then UNFOLLOW -- fading from one word to the next and easing to the new
/// width rather than jumping.
class SwapLabel extends StatelessWidget {
  const SwapLabel(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final duration = motionDuration(context, Motion.medium);
    return EasedSize(
      child: AnimatedSwitcher(
        duration: duration,
        switchInCurve: Motion.curve,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.9, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: Text(text, key: ValueKey(text), style: style),
      ),
    );
  }
}
