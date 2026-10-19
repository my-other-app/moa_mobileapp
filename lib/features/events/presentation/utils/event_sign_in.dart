import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';

/// The sign-in screen, told where to come back to.
///
/// `from` is the address the person was on (the event page, say). The
/// router and the sign-in flow take them back there once they are in (see
/// the batch D and C notes in the report); until they do, signing in lands
/// on Home as it always has.
String signInLocation({String? returnTo}) {
  final back = returnTo?.trim() ?? '';
  return back.isEmpty || !back.startsWith('/')
      ? '/auth/onboarding'
      : Uri(path: '/auth/onboarding', queryParameters: {'from': back})
          .toString();
}

/// Where the person is now, to come back to after signing in; null outside
/// a router.
String? currentLocation(BuildContext context) {
  try {
    return GoRouterState.of(context).uri.toString();
  } catch (_) {
    return null;
  }
}

/// Signed in: true. Signed out: says why an account is needed ([reason]:
/// "Sign in to register for Hack Night."), offers to sign in -- coming back
/// to [returnTo], by default where they are -- and answers false.
///
/// Browsing an event needs no account; registering, rating, a team, a
/// report or a block do.
Future<bool> ensureSignedInFor(
  BuildContext context,
  WidgetRef ref, {
  required String reason,
  String? returnTo,
}) async {
  if (ref.read(isAuthenticatedProvider)) return true;
  final back = returnTo ?? currentLocation(context);
  final signIn = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Sign in to continue',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(reason,
                style: const TextStyle(fontSize: 15, color: Color(0xFF4B5563))),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(sheet).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C333D),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Sign in'),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheet).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    ),
  );
  if (signIn == true && context.mounted) {
    // Pushed, so Back from sign-in returns here.
    GoRouter.maybeOf(context)?.push(signInLocation(returnTo: back));
  }
  return false;
}
