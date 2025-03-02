import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SvgIcon extends StatelessWidget {
  final String svgIconPath;
  final Color color;
  const SvgIcon({
    super.key,
    required this.svgIconPath,
    this.color = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      svgIconPath,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
