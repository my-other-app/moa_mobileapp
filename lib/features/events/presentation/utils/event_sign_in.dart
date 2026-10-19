import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';

/// Signed in: true. Signed out: says why an account is needed ([reason]:
/// "Sign in to register for Hack Night."), offers to sign in -- coming back
/// to [returnTo], by default where they are -- and answers false.
///
/// Browsing an event needs no account; registering, rating, a team, a
/// report or a block do. The ask is the app's one sign-in sheet
/// ([askToSignIn]); this answers once it is closed.
Future<bool> ensureSignedInFor(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
  String? returnTo,
}) async {
  if (ref.read(isAuthenticatedProvider)) return true;
  await askToSignIn(context, ref, reason, returnTo: returnTo);
  return false;
}
