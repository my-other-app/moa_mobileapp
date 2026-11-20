import 'package:flutter/material.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/shared/motion.dart';
import 'package:finnet/shared/widgets/pressable.dart';

/// The app's filter and choice chip, in place of [FilterChip] and
/// [ChoiceChip]: the pill the topic rows use -- soft grey, and pale yellow
/// with an ink edge once chosen -- with an optional icon or count, a press
/// that sinks a little and a selection tick felt in the hand.
///
/// The pill is 32 high; the touch is 44, above and below it.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.onTap,
    this.icon,
    this.count,
    this.trailingIcon,
    this.idle,
    this.semanticsLabel,
  });

  final String label;
  final bool selected;

  /// A filter's toggle: told the new state (not [selected]).
  final ValueChanged<bool>? onSelected;

  /// For a chip that opens something (a "Sort: Newest" pill): wins over
  /// [onSelected].
  final VoidCallback? onTap;
  final IconData? icon;

  /// A number after the label, quieter: "DevFest · 12".
  final int? count;

  /// After the label: a close mark on a filter that a tap removes.
  final IconData? trailingIcon;

  /// The unchosen fill; soft grey when null (white on a grey screen).
  final Color? idle;
  final String? semanticsLabel;

  /// The pill's height, and the touch around it.
  static const height = 32.0;
  static const touch = 44.0;

  /// The chosen fill and edge, the unchosen fill, and the ink.
  static const chosenFill = AppColors.paleYellow;
  static const chosenEdge = Color(0xFF1E1E1E);
  static const idleFill = AppColors.softGrey;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || onSelected != null;
    final radius = BorderRadius.circular(60);
    final fill = selected ? chosenFill : (idle ?? idleFill);
    final duration = motionDuration(context, Motion.medium);
    void tap() {
      Haptics.selection();
      if (onTap != null) {
        onTap!();
      } else {
        onSelected?.call(!selected);
      }
    }

    final pill = AnimatedContainer(
      duration: duration,
      curve: Motion.curve,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: selected ? chosenEdge : fill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.ink),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.ink,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              )),
          if (count != null) ...[
            const SizedBox(width: 5),
            Text('$count',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B6B))),
          ],
          if (trailingIcon != null) ...[
            const SizedBox(width: 4),
            Icon(trailingIcon, size: 16, color: AppColors.ink),
          ],
        ],
      ),
    );

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      selected: onTap == null ? selected : null,
      label: semanticsLabel ?? (count == null ? label : '$label, $count'),
      onTap: enabled ? tap : null,
      excludeSemantics: true,
      child: Pressable(
        enabled: enabled,
        scale: 0.94,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: enabled ? tap : null,
            borderRadius: radius,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: touch),
              child: Center(widthFactor: 1, child: pill),
            ),
          ),
        ),
      ),
    );
  }
}
