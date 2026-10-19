import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/app/router/route_access.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';

// The one check of a way back, shared with the router.
export 'package:finnet/app/router/route_access.dart' show safeReturnPath;

/// Reading is open to anyone; acting -- following a club, liking, voting,
/// commenting, reporting -- needs an account. This is where the two meet.
///
/// [ensureSignedIn] answers whether the action may go ahead and, when it
/// may not, asks the person to sign in -- without ever signing anyone out.
///
/// The way back is in the address: sign-in opens as
/// `/auth/onboarding?from=<the page>`, every step after it (the profile
/// check; for a new account the details, interests, avatar and the last
/// page; the email code; a password reset) passes `from` on, and the last
/// one goes there ([goAfterSignIn]). Batches A and B send people to the
/// same address; batch D's router sends a signed-in
/// `/auth/onboarding?from=X` to `/auth/profile-check?from=X`.

/// The query parameter that carries the page to come back to.
const signInFromParam = returnParameter;

/// [path] with `?from=` [from] added, when [from] is safe to go back to;
/// [path] as it is otherwise.
String withSignInFrom(String path, String? from) {
  final back = safeReturnPath(from);
  if (back == null) return path;
  final uri = Uri.parse(path);
  return uri.replace(queryParameters: {
    ...uri.queryParameters,
    signInFromParam: back,
  }).toString();
}

/// The page to come back to, as the current route was opened with it; null
/// when there is none (or it is not safe).
String? signInFromOf(BuildContext context) {
  try {
    return safeReturnPath(
        GoRouterState.of(context).uri.queryParameters[signInFromParam]);
  } catch (_) {
    // Not under a router (a test's MaterialApp): nowhere to come back to.
    return null;
  }
}

/// Whether this person may do something that needs an account. If not, asks
/// them to sign in -- saying [reason] -- and answers false; the action is
/// not done, and they can do it once they are back (at [returnTo], by
/// default this page). Signed in, it answers true and asks nothing.
bool ensureSignedIn(
  BuildContext context,
  WidgetRef ref,
  String reason, {
  String? returnTo,
}) {
  if (ref.read(isAuthenticatedProvider)) return true;
  askToSignIn(context, ref, reason, returnTo: returnTo);
  return false;
}

/// The ask: a sheet saying why an account is needed, with SIGN IN and NOT
/// NOW. Answers once the sheet is gone.
Future<void> askToSignIn(
  BuildContext context,
  WidgetRef ref,
  String reason, {
  String? returnTo,
}) async {
  final go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SignInPromptSheet(reason: reason),
  );
  if (go == true && context.mounted) {
    startSignIn(context, ref, returnTo: returnTo);
  }
}

/// Open the sign-in screen over the current page:
/// `/auth/onboarding?from=<the page>`, so signing in comes back to it (or
/// to [returnTo]).
void startSignIn(BuildContext context, WidgetRef ref, {String? returnTo}) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  router.push(
      withSignInFrom(signInPath, returnTo ?? _here(context, router)));
}

/// Where the person is, as an address to come back to.
String? _here(BuildContext context, GoRouter router) {
  String location;
  try {
    location = GoRouterState.of(context).uri.toString();
  } catch (_) {
    // A context outside any route (a dialog's): the router's own idea of
    // where it is.
    location = router.routerDelegate.currentConfiguration.uri.toString();
  }
  return safeReturnPath(location);
}

/// Where a finished sign-in goes: back to [from] when it is a safe page of
/// this app, else home.
void goAfterSignIn(BuildContext context, String? from) {
  context.go(safeReturnPath(from) ?? '/');
}

/// "Sign in to follow clubs", with the way in and the way out.
class SignInPromptSheet extends StatelessWidget {
  final String reason;

  const SignInPromptSheet({super.key, required this.reason});

  static const _ink = Color(0xFF2C333D);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        key: const ValueKey('sign-in-prompt'),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SIGN IN TO CONTINUE',
              style: TextStyle(
                fontSize: 28,
                fontFamily: 'BebasNeue',
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              reason,
              style: const TextStyle(fontSize: 16, color: _ink),
            ),
            const SizedBox(height: 4),
            Text(
              "It takes a moment, and you'll come straight back here.",
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('sign-in-prompt-go'),
                style: FilledButton.styleFrom(
                  backgroundColor: _ink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'SIGN IN',
                  style: TextStyle(fontSize: 22, fontFamily: 'BebasNeue'),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: TextButton(
                key: const ValueKey('sign-in-prompt-later'),
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Not now', style: TextStyle(color: _ink)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
