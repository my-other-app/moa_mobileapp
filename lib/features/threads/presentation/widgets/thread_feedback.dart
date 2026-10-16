import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// Whether this person can like, vote or comment; if not, says so with a
/// way to sign in, and answers false.
///
/// Reading is open to anyone; acting needs an account.
bool ensureSignedIn(BuildContext context, WidgetRef ref, String reason) {
  if (ref.read(isAuthenticatedProvider)) return true;
  showSignInPrompt(context, ref, reason);
  return false;
}

/// A snackbar with a SIGN IN action.
///
/// Signing in starts from a clean slate the way Settings > Log out does:
/// the stale session is cleared, the router notices and takes the person to
/// the sign-in screen. It is only offered when the session is already gone
/// -- signed out, or refused by the server -- so nothing live is lost.
void showSignInPrompt(BuildContext context, WidgetRef ref, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'SIGN IN',
          onPressed: () async {
            ref.read(profileProvider.notifier).clearProfile();
            await ref.read(authStateProvider.notifier).logout();
          },
        ),
      ),
    );
}

/// Say what went wrong with a like, vote or comment.
///
/// An expired session (a 401) gets the sign-in prompt rather than a dead
/// end. A 403 is an AuthFailure too, but signing in again would not change
/// the answer, so it is shown as said.
void showThreadFailure(BuildContext context, WidgetRef ref, Failure failure) {
  if (!context.mounted) return;
  if (failure is AuthFailure && failure.code != '403') {
    showSignInPrompt(
      context,
      ref,
      'Your session has expired. Sign in again to continue.',
    );
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(failure.message)));
}
