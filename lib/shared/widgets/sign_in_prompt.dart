import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/app/router/pending_location.dart';
import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';

/// "Sign in to continue": for what needs an account in an app that can be
/// used without one.
///
/// For an action (register, follow, rate, comment, report, save):
///
/// ```dart
/// onPressed: () async {
///   if (!await requireSignIn(context, ref, reason: 'Sign in to follow clubs.')) return;
///   follow();
/// }
/// ```
///
/// Signed in, it answers true at once and asks nothing. Signed out, it asks;
/// if the person chooses to sign in, the sign-in screen opens over this one
/// and, once they are signed in, brings them back here (or to [returnTo])
/// -- where they tap again. It answers false then, and when they decline.
///
/// For a whole screen that is about the person, wrap it in
/// [SignInRequired] instead.
Future<bool> requireSignIn(
  BuildContext context,
  WidgetRef ref, {
  String? reason,
  String? returnTo,
}) async {
  if (ref.read(authStateProvider).isAuthenticated) return true;
  final router = GoRouter.maybeOf(context);
  final here = returnTo ?? _currentLocation(router);
  final wantsToSignIn = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SignInPromptSheet(reason: reason),
  );
  if (wantsToSignIn != true || router == null) return false;
  if (!context.mounted) return false;
  startSignIn(ref, router, returnTo: here);
  return false;
}

/// Open sign-in over the current screen, to come back to [returnTo] (or
/// the current screen) once signed in. For a "Sign in" button that needs no
/// question first -- a signed-out Profile tab, say.
void startSignIn(WidgetRef ref, GoRouter router, {String? returnTo}) {
  final here = returnTo ?? _currentLocation(router);
  if (here != null) ref.read(pendingLocationProvider).holdReturn(here);
  router.push(here == null ? signInPath : signInLocation(here));
}

String? _currentLocation(GoRouter? router) {
  if (router == null) return null;
  try {
    final location = router.state.uri.toString();
    return isAuthFlow(location) ? null : location;
  } catch (_) {
    // No route yet: nowhere to come back to.
    return null;
  }
}

/// The question [requireSignIn] asks: pops true for "Sign in", false (or
/// nothing) for "Not now".
class SignInPromptSheet extends StatelessWidget {
  const SignInPromptSheet({super.key, this.reason});

  /// What needs the account, in a sentence: "Sign in to register for this
  /// event." Defaults to a general line.
  final String? reason;

  static const defaultReason =
      'You need an account for this. It takes a minute, and you come straight back here.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign in to continue',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              reason ?? defaultReason,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.grey[700]),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C333D),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('Sign in'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2C333D),
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A screen that is about the signed-in person: shows [child] when someone
/// is signed in, and otherwise says what signing in gives, with a button
/// that signs in and comes back. Never forces sign-in on its own.
class SignInRequired extends ConsumerWidget {
  const SignInRequired({
    super.key,
    required this.child,
    this.title,
    this.message,
  });

  final Widget child;

  /// The app bar's title while signed out.
  final String? title;

  /// What signing in shows here: "Sign in to see your team."
  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn =
        ref.watch(authStateProvider.select((auth) => auth.isAuthenticated));
    if (signedIn) return child;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: title == null ? null : Text(title!),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SignInPlaceholder(message: message),
    );
  }
}

/// The body of a signed-out screen that needs an account: a line saying
/// why, and a Sign in button that comes back here.
class SignInPlaceholder extends ConsumerWidget {
  const SignInPlaceholder({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 56, color: Colors.grey[500]),
            const SizedBox(height: 16),
            Text(
              message ?? 'Sign in to see this.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final router = GoRouter.maybeOf(context);
                if (router != null) startSignIn(ref, router);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2C333D),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
