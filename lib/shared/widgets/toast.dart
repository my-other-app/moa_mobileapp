import 'package:flutter/material.dart';

/// A short confirmation -- "Copied", "Saved" -- in a small floating bar
/// that slides up from the bottom and leaves by itself.
///
/// The app's snack bar (see the theme), with an icon before the words, and
/// any earlier one cleared first so two never queue up.
void showToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline,
  Duration duration = const Duration(seconds: 2),
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: duration,
      content: Row(
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    ));
}
