import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

export 'package:finnet/features/auth/presentation/sign_in_gate.dart'
    show ensureSignedIn;

/// Ask the person to sign in, saying [message].
///
/// Signed out, that is the sign-in sheet, and signing in comes back here.
/// Signed in to a session the server has since refused, it is a snackbar
/// whose SIGN IN starts from a clean slate the way Settings > Log out does:
/// the stale session is cleared and the router takes the person to sign-in.
/// Either way the session is already gone, so nothing live is lost.
void showSignInPrompt(BuildContext context, WidgetRef ref, String message) {
  if (!ref.read(isAuthenticatedProvider)) {
    askToSignIn(context, ref, message);
    return;
  }
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
