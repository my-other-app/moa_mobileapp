import 'dart:async';

/// Why a session ended.
enum SessionEndReason {
  /// The person signed out.
  signedOut,

  /// The server stopped accepting the session: the refresh token expired, or
  /// the session was revoked (ended from the Security page, a guest account's
  /// token_version bumped, a Google or Apple sign-in that took back an
  /// unverified password account).
  expired,

  /// The account was suspended (`ACCOUNT_SUSPENDED`).
  suspended,
}

/// Signals that the server ended the stored session, from the network layer
/// to the auth state.
///
/// [AuthInterceptor] lives under `buildAppDio()`, outside Riverpod, so it
/// cannot reach the auth state directly. It used to delete the tokens and
/// stop there; the auth state had read them once at start-up and went on
/// believing the person was signed in, so an expired session never reached
/// the UI. The interceptor now reports here and the auth state listens.
class SessionEvents {
  SessionEvents._();

  static final StreamController<SessionEndReason> _revoked =
      StreamController<SessionEndReason>.broadcast();

  /// The server refused the stored session; its tokens are already deleted.
  static Stream<SessionEndReason> get revoked => _revoked.stream;

  /// Report that the server refused the stored session.
  static void reportRevoked(SessionEndReason reason) => _revoked.add(reason);
}
