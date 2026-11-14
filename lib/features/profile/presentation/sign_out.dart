import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/volunteer/data/saved_scans.dart';
import 'package:finnet/shared/widgets/confirmation_dialog.dart';

/// Asks, then signs out: the profile is cleared, the session ended and the
/// tabs set back to the first. From Profile and from Settings.
///
/// Door scans this account saved with no signal and hasn't sent yet are
/// said first ([UnsentScansDialog]): send them now, or sign out anyway --
/// they stay on the phone and go the next time this account signs in.
/// Nothing is deleted either way.
///
/// The router takes them to sign-in once the session is gone; pushing
/// onboarding here as well made the screen flicker.
Future<void> confirmSignOut(BuildContext context, WidgetRef ref) async {
  Future<void> signOut() async {
    ref.read(profileProvider.notifier).clearProfile();
    await ref.read(authStateProvider.notifier).logout();
    ref.read(navigationIndexProvider.notifier).state = 0;
  }

  final sender = ref.read(savedScanSenderProvider);
  final unsent = await sender.count();
  if (!context.mounted) return;
  if (unsent == 0) {
    await ConfirmationDialog.showLogout(context: context, onConfirm: signOut);
    return;
  }
  final go = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UnsentScansDialog(
      unsent: unsent,
      send: () => sender.sendAll(force: true),
    ),
  );
  if (go == true) await signOut();
}

/// "3 door scans haven't been sent yet": Send now, Sign out anyway, or
/// Cancel. Pops true to sign out, false or nothing to stay.
///
/// Send now sends every saved scan of the account; once none is left it
/// signs out, as was asked. Some left (no signal, or the server couldn't
/// take them yet): it says how many, and asks again.
class UnsentScansDialog extends StatefulWidget {
  const UnsentScansDialog({
    super.key,
    required this.unsent,
    required this.send,
  });

  final int unsent;
  final Future<SendAllResult> Function() send;

  static const sendNowKey = ValueKey('unsent-scans-send-now');
  static const signOutKey = ValueKey('unsent-scans-sign-out');
  static const cancelKey = ValueKey('unsent-scans-cancel');

  /// "3 door scans haven't been sent yet."
  static String title(int n) => n == 1
      ? "1 door scan hasn't been sent yet"
      : "$n door scans haven't been sent yet";

  static const message = 'They were taken with no signal and are saved on '
      'this phone. Send them now, or sign out anyway: they stay on this '
      'phone and are sent the next time you sign in with this account.';

  /// After Send now, with [n] still not sent.
  static String stillLeft(int n) =>
      "${n == 1 ? "1 scan still wasn't" : "$n scans still weren't"} sent. "
      'Check your signal and try again, or sign out anyway: they stay on '
      'this phone and are sent the next time you sign in.';

  @override
  State<UnsentScansDialog> createState() => _UnsentScansDialogState();
}

class _UnsentScansDialogState extends State<UnsentScansDialog> {
  late int _left = widget.unsent;
  bool _sending = false;
  bool _tried = false;

  Future<void> _sendNow() async {
    setState(() => _sending = true);
    final result = await widget.send();
    if (!mounted) return;
    if (result.left == 0) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _tried = true;
      _left = result.left;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(UnsentScansDialog.title(_left)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_tried
              ? UnsentScansDialog.stillLeft(_left)
              : UnsentScansDialog.message),
          if (_sending) ...[
            const SizedBox(height: 16),
            const Row(children: [
              SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Sending…'),
            ]),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: UnsentScansDialog.cancelKey,
          onPressed: _sending ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: UnsentScansDialog.signOutKey,
          onPressed: _sending ? null : () => Navigator.of(context).pop(true),
          child: const Text('Sign out anyway'),
        ),
        FilledButton(
          key: UnsentScansDialog.sendNowKey,
          onPressed: _sending ? null : _sendNow,
          child: const Text('Send now'),
        ),
      ],
    );
  }
}
