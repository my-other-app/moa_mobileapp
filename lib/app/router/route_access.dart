/// Which of the app's addresses need an account, and where sign-in goes.
///
/// The app can be used without an account, as the website can: home,
/// discover, events, clubs, topics, posts, a ticket's QR from its link, a
/// certificate and the policies all open signed out. What is about the
/// person -- their events and tickets, their clubs, profile, settings,
/// inbox, badges, certificates, the volunteer scanner -- asks them to sign
/// in first, and comes back to it afterwards.
///
/// Anything not listed here is open: a new screen works without an account
/// unless it is added to [needsAccount]. Screens that are open but have an
/// action needing an account -- following, registering, the competition,
/// the feedback survey -- ask at that action themselves, with
/// `ensureSignedIn` (`lib/features/auth/presentation/sign_in_gate.dart`).
library;

/// The sign-in screen.
const signInPath = '/auth/onboarding';

/// The query parameter that carries where sign-in returns to.
const returnParameter = 'from';

/// Private addresses, by path (no query). Matched without regard to case,
/// as the router matches its routes.
final List<RegExp> _private = [
  // The Events tab: the person's registrations and tickets.
  RegExp(r'^/events/?$', caseSensitive: false),
  RegExp(r'^/events/registration-success/?$', caseSensitive: false),
  // The Clubs tab: the clubs they follow and pinned.
  RegExp(r'^/clubs/?$', caseSensitive: false),
  // Profile, settings, inbox, badges, certificates.
  RegExp(r'^/profile(/.*)?$', caseSensitive: false),
  RegExp(r'^/volunteer(/.*)?$', caseSensitive: false),
];

/// Whether [path] (a location's path, without its query) needs an account.
///
/// The one place that decides it. A feature that wants to say its own
/// addresses are open (batch A's `isDiscoverLocation`, say) adds one line
/// at the top: `if (isDiscoverLocation(path)) return false;`. Not needed
/// today -- every address not listed below is open already.
bool needsAccount(String path) {
  final clean = _pathOf(path);
  return _private.any((pattern) => pattern.hasMatch(clean));
}

/// The splash screen, sign-in and onboarding: open to everyone, always.
bool isAuthFlow(String path) {
  final clean = _pathOf(path);
  return clean == '/splash' ||
      clean == '/auth' ||
      clean.startsWith('/auth/') ||
      clean == '/onboarding' ||
      clean.startsWith('/onboarding/');
}

/// The tabs of the bottom bar. A sign-in that started from one goes back to
/// it with `go`, not `push`: the tab is the page, not something above home.
bool isTabRoot(String path) =>
    const {'/', '/events', '/clubs', '/profile'}.contains(_pathOf(path));

/// The sign-in screen, told to come back to [from] once signed in.
String signInLocation(String from) => Uri(
      path: signInPath,
      queryParameters: {returnParameter: from},
    ).toString();

/// Where a sign-in screen at [location] returns to, if anywhere. Only an
/// address inside the app -- a path starting with `/` -- is accepted: a
/// `from` naming another site (`https://...`, `//host`, `/\\host`), or the
/// sign-in flow itself, is ignored.
String? returnTarget(Uri location) =>
    safeReturnPath(location.queryParameters[returnParameter]);

/// [from] when it is a path inside the app, else null. See [returnTarget].
String? safeReturnPath(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  if (from.contains('\\')) return null;
  final uri = Uri.tryParse(from);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  if (isAuthFlow(uri.path)) return null;
  return from;
}

/// The profile check, told where to go once it has the profile (an
/// existing account goes straight back to [from]).
String profileCheckLocation(String? from) {
  final back = safeReturnPath(from);
  return back == null
      ? '/auth/profile-check'
      : Uri(
          path: '/auth/profile-check',
          queryParameters: {returnParameter: back}).toString();
}

String _pathOf(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  return path.isEmpty ? '/' : path.toLowerCase();
}
