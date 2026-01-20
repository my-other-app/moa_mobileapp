import 'package:flutter/material.dart';

/// A beautifully styled confirmation dialog matching the app design.
///
/// Used for critical actions like logout and delete account.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  final Color confirmColor;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    this.cancelText = 'CANCEL',
    required this.onConfirm,
    this.onCancel,
    this.confirmColor = const Color(0xFFD32F2F), // Red for destructive
    this.isDestructive = true,
  });

  /// Show a logout confirmation dialog
  static Future<void> showLogout({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ConfirmationDialog(
        title: 'LOG OUT?',
        message: 'You\'re about to log out of your account. '
            'You can always log back in anytime! 👋',
        confirmText: 'LOG OUT',
        onConfirm: () {
          Navigator.of(ctx).pop();
          onConfirm();
        },
        onCancel: () => Navigator.of(ctx).pop(),
        confirmColor: const Color(0xFF1A1A2E), // Dark theme color
        isDestructive: false,
      ),
    );
  }

  /// Show a delete account confirmation dialog
  static Future<void> showDeleteAccount({
    required BuildContext context,
    required VoidCallback onConfirm,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ConfirmationDialog(
        title: 'DELETE YOUR ACCOUNT?',
        message: 'Hold up! This action is permanent and you\'ll lose '
            'all your data, progress, and saved events. 😢\n'
            'Are you really sure you want to delete your account?',
        confirmText: 'DELETE',
        onConfirm: () {
          Navigator.of(ctx).pop();
          onConfirm();
        },
        onCancel: () => Navigator.of(ctx).pop(),
        confirmColor: const Color(0xFFD32F2F), // Red for delete
        isDestructive: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'BebasNeue',
                letterSpacing: 1.2,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Message
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[600],
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  confirmText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: onCancel ?? () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: const BorderSide(color: Colors.black26),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  cancelText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
