import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';

/// Reading is open to anyone; acting -- following a club, liking, voting,
/// commenting, reporting -- needs an account. This is where the two meet.
///
/// [ensureSignedIn] answers whether the action may go ahead and, when it
/// may not, asks the person to sign in. Signing in from there comes back to
/// the page they were on ([signInReturnProvider], [goAfterSignIn]).

/// Where to go once signed in: the page someone was on when an action asked
/// them to sign in. Null when sign-in started anywhere else.
final signInReturnProvider = StateProvider<SignInReturn?>((ref) => null);

/// A page to come back to.
@immutable
class SignInReturn {
  final String location;

  /// What the page was opened with (a club's slug and name, say), handed
  /// back to it on the way in.
  final Object? extra;

  /// When sign-in was asked for.
  final DateTime at;

  SignInReturn(this.location, {this.extra, DateTime? at})
      : at = at ?? DateTime.now();

  /// How long the page is worth coming back to. Someone who backs out of
  /// sign-in with the system gesture and signs in much later, from
  /// somewhere else, should land at home rather than on a page they left.
  static const keptFor = Duration(minutes: 30);

  bool get isFresh => DateTime.now().difference(at) < keptFor;
}

/// Whether this person may do something that needs an account. If not, asks
/// them to sign in -- saying [reason] -- and answers false; the action is
/// not done, and they can do it once they are back.
bool ensureSignedIn(BuildContext context, WidgetRef ref, String reason) {
  if (ref.read(isAuthenticatedProvider)) return true;
  askToSignIn(context, ref, reason);
  return false;
}

/// The ask: a sheet saying why an account is needed, with SIGN IN and NOT
/// NOW. Answers once the sheet is gone.
Future<void> askToSignIn(
  BuildContext context,
  WidgetRef ref,
  String reason,
) async {
  final go = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SignInPromptSheet(reason: reason),
  );
  if (go == true && context.mounted) startSignIn(context, ref);
}

/// Open the sign-in screen over the current page, remembering the page so
/// signing in comes back to it.
void startSignIn(BuildContext context, WidgetRef ref) {
  final router = GoRouter.maybeOf(context);
  if (router == null) return;
  ref.read(signInReturnProvider.notifier).state = _here(context, router);
  router.push('/auth/onboarding');
}

SignInReturn? _here(BuildContext context, GoRouter router) {
  try {
    final state = GoRouterState.of(context);
    final location = state.uri.toString();
    if (location.isEmpty || location.startsWith('/auth')) return null;
    return SignInReturn(location, extra: state.extra);
  } catch (_) {
    // A context outside any route (a dialog's): the router's own idea of
    // where it is.
    final config = router.routerDelegate.currentConfiguration;
    final location = config.uri.toString();
    if (location.isEmpty || location.startsWith('/auth')) return null;
    return SignInReturn(location, extra: config.extra);
  }
}

/// Where a finished sign-in goes: back to the page that asked for it, or
/// home. The remembered page is used once.
void goAfterSignIn(BuildContext context, WidgetRef ref) {
  final back = ref.read(signInReturnProvider);
  ref.read(signInReturnProvider.notifier).state = null;
  if (back == null || !back.isFresh) {
    context.go('/');
  } else {
    context.go(back.location, extra: back.extra);
  }
}

/// Forget the page to come back to: the person left sign-in without
/// signing in.
void cancelSignInReturn(WidgetRef ref) {
  ref.read(signInReturnProvider.notifier).state = null;
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
