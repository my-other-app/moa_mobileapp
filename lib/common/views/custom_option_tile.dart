import 'package:flutter/material.dart';

class CustomOptionTile extends StatelessWidget {
  final String icon;
  final Widget title;
  final VoidCallback onTap;
  final double verticalSpacing;

  const CustomOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.verticalSpacing = 24.0,
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
            CircleAvatar(
              backgroundColor: Color(0xffF3F3F3),
              radius: 24,
              child: Image.asset(
                icon,
              ),
            ),
            title,
          ],
        ),
      ),
    );
  }
}
