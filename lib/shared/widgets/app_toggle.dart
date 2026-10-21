import 'package:flutter/material.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/motion.dart';

/// The app's on/off switch, after the Settings design: a small pill, the
/// app's yellow with a thin ink edge and the ink knob at the right when on;
/// white with a grey edge and a grey knob at the left when off.
///
/// Not the Material switch, whose shape and colours are its own. Tapping it
/// calls [onChanged] with the other value, with a light tap felt; with no
/// [onChanged] it is drawn faded and does nothing.
///
/// The knob slides across as the track fills, both eased out together --
/// or, when the phone asks for less motion, simply switches.
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// What a screen reader calls it, when nothing beside it says.
  final String? semanticLabel;

  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  static const width = 52.0;
  static const height = 28.0;
  static const _knob = 20.0;
  static const _offEdge = Color(0xFFBDBDBD);
  static const _offKnob = Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final duration = motionDuration(context, Motion.medium);
    void toggle() {
      Haptics.selection();
      onChanged!(!value);
    }

    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? toggle : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? toggle : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: AnimatedContainer(
            duration: duration,
            curve: Motion.curve,
            width: width,
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: value ? AppColors.paleYellow : Colors.white,
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(color: value ? AppColors.ink : _offEdge),
            ),
            child: AnimatedAlign(
              duration: duration,
              curve: Motion.curve,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: duration,
                curve: Motion.curve,
                width: _knob,
                height: _knob,
                decoration: BoxDecoration(
                  color: value ? AppColors.ink : _offKnob,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
