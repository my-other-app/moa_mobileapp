import 'package:flutter/material.dart';

class CustomOptionTile extends StatelessWidget {
  final String? leadingImageName;
  final IconData? icon;
  final Widget title;
  final VoidCallback onTap;
  final double verticalSpacing;
  final Widget? trailing;

  const CustomOptionTile({
    super.key,
    this.leadingImageName,
    this.icon,
    required this.title,
    required this.onTap,
    this.verticalSpacing = 24.0,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: EdgeInsets.symmetric(vertical: verticalSpacing),
        child: Row(
          spacing: 16,
          children: [
            if (leadingImageName != null || icon != null)
              CircleAvatar(
                backgroundColor: Color(0xffF3F3F3),
                radius: 24,
                child: leadingImageName != null
                    ? Image.asset(
                        leadingImageName!,
                        height: 25,
                        width: 25,
                      )
                    : Icon(icon),
              ),
            title,
            if (trailing != null) ...[Spacer(), trailing!],
          ],
        ),
      ),
    );
  }
}
