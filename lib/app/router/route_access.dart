/// Which of the app's addresses need an account, and where sign-in goes.
///
/// The app can be used without an account, as the website can: home,
/// discover, events, clubs, topics, posts, a ticket's QR from its link, a
/// certificate and the policies all open signed out. What is about the
/// person -- their events and tickets, their clubs, profile, settings,
/// inbox, badges, certificates, the volunteer scanner, registering -- asks
/// them to sign in first, and comes back to it afterwards.
///
/// Anything not listed here is open: a new screen works without an account
/// unless it is added to [needsAccount] (or wraps itself in
/// `SignInRequired`, `lib/shared/widgets/sign_in_prompt.dart`).
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
  RegExp(r'^/events/[^/]+/register/?$', caseSensitive: false),
  // The Clubs tab: the clubs they follow and pinned.
  RegExp(r'^/clubs/?$', caseSensitive: false),
  // Profile, settings, inbox, badges, certificates.
  RegExp(r'^/profile(/.*)?$', caseSensitive: false),
  RegExp(r'^/volunteer(/.*)?$', caseSensitive: false),
];

/// Whether [path] (a location's path, without its query) needs an account.
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
/// address inside the app: a `from` naming another site, or the sign-in
/// screen itself, is ignored.
String? returnTarget(Uri location) {
  final from = location.queryParameters[returnParameter];
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  if (isAuthFlow(from)) return null;
  return from;
}

String _pathOf(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  return path.isEmpty ? '/' : path.toLowerCase();
}
