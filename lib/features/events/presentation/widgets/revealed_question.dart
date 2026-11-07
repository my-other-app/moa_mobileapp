import 'package:flutter/material.dart';

/// A follow-up question that an answer just revealed: it grows open and
/// fades in beneath the answer, instead of the form jumping. It never takes
/// the focus -- whoever is answering stays where they are, and a screen
/// reader is told of it separately. With the system's reduced motion on
/// ([MediaQuery.disableAnimationsOf]) it is simply there.
class RevealedQuestion extends StatefulWidget {
  final Widget child;

  const RevealedQuestion({super.key, required this.child});

  static const duration = Duration(milliseconds: 220);

  @override
  State<RevealedQuestion> createState() => _RevealedQuestionState();
}

class _RevealedQuestionState extends State<RevealedQuestion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: RevealedQuestion.duration);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The same widgets throughout, so the question's own state (what is
    // typed, the focus) survives the animation ending. At full size the
    // clip is the question's own size: nothing is cut off.
    return SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: _curve, child: widget.child),
    );
  }
}
