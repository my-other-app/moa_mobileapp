import 'package:flutter/material.dart';

class CustomOptionTile extends StatelessWidget {
  final String? leadingImageName;
  final IconData? icon;
  final IconData? leadingIcon;
  final Color? leadingIconColor;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback onTap;
  final double verticalSpacing;
  final Widget? trailing;

  const CustomOptionTile({
    super.key,
    this.leadingImageName,
    this.icon,
    this.leadingIcon,
    this.leadingIconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.verticalSpacing = 24.0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final iconToUse = leadingIcon ?? icon;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(vertical: verticalSpacing),
        child: Row(
          children: [
            if (leadingImageName != null || iconToUse != null)
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  backgroundColor: const Color(0xffF3F3F3),
                  radius: 24,
                  child: leadingImageName != null
                      ? Image.asset(
                          leadingImageName!,
                          height: 25,
                          width: 25,
                        )
                      : Icon(
                          iconToUse,
                          color: leadingIconColor ?? Colors.black54,
                        ),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  title,
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    subtitle!,
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
