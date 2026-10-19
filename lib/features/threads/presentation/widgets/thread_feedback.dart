import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/error/failures.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';

export 'package:finnet/features/auth/presentation/sign_in_gate.dart'
    show ensureSignedIn;

/// Ask the person to sign in, saying [message]: the "Sign in to continue"
/// sheet, whose SIGN IN opens `/auth/onboarding?from=<this page>`, so
/// signing in comes back here.
///
/// Never signs anyone out. It used to, to reach the sign-in screen through
/// the router -- which, once signed-out browsing lets a person stay on the
/// page, only threw a session away and went nowhere.
void showSignInPrompt(BuildContext context, WidgetRef ref, String message) {
  askToSignIn(context, ref, message);
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
