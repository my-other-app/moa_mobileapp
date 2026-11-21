import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/core/themes/app_colors.dart';

/// The app's share icon (`assets/icons/share.svg`, the one the event and
/// club cards use), in place of Material's `Icons.share` and
/// `Icons.ios_share`.
class AppShareIcon extends StatelessWidget {
  const AppShareIcon({super.key, this.size = 22, this.color});

  final double size;

  /// The icon theme's colour (the app bar's, a button's) when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? IconTheme.of(context).color ?? AppColors.ink;
    return SvgPicture.asset(
      AssetResources.share,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
      excludeFromSemantics: true,
    );
  }
}

/// An icon button with [AppShareIcon], told its own context when pressed
/// so the share sheet can point at it (`shareOriginOf`).
class AppShareButton extends StatelessWidget {
  const AppShareButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Share',
    this.color,
    this.size = 22,
  });

  /// Given the button's context; null disables it.
  final ValueChanged<BuildContext>? onPressed;
  final String tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final press = onPressed;
    return Builder(
      builder: (button) => IconButton(
        tooltip: tooltip,
        icon: AppShareIcon(size: size, color: color),
        onPressed: press == null ? null : () => press(button),
      ),
    );
  }
}
