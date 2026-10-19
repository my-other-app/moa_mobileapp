import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/shared/widgets/confirmation_dialog.dart';

/// Asks, then signs out: the profile is cleared, the session ended and the
/// tabs set back to the first. From Profile and from Settings.
///
/// The router takes them to sign-in once the session is gone; pushing
/// onboarding here as well made the screen flicker.
void confirmSignOut(BuildContext context, WidgetRef ref) {
  ConfirmationDialog.showLogout(
    context: context,
    onConfirm: () async {
      ref.read(profileProvider.notifier).clearProfile();
      await ref.read(authStateProvider.notifier).logout();
      ref.read(navigationIndexProvider.notifier).state = 0;
    },
  );
}
