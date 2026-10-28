import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/auth/session_events.dart';
import 'package:finnet/core/services/app_badge.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/auth/data/services/session_services.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';

export 'package:finnet/core/auth/session_events.dart' show SessionEndReason;

/// Authentication state for the application.
class AuthState extends Equatable {
  final UserProfile? user;
  final String? accessToken;
  final String? refreshToken;
  final bool isLoading;
  final String? error;
  final bool isInitialized;

  /// Why the last session ended, until the sign-in screen has said so.
  /// Null when nobody was signed in, and once the notice has been shown.
  final SessionEndReason? endedBecause;

  const AuthState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
    this.endedBecause,
  });

  /// Whether the user is authenticated.
  bool get isAuthenticated => accessToken != null && accessToken!.isNotEmpty;

  /// Create a copy with updated values.
  AuthState copyWith({
    UserProfile? user,
    String? accessToken,
    String? refreshToken,
    bool? isLoading,
    String? error,
    bool? isInitialized,
    bool clearUser = false,
    bool clearError = false,
    bool clearEndReason = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isInitialized: isInitialized ?? this.isInitialized,
      endedBecause: clearEndReason ? null : endedBecause,
    );
  }

  @override
  List<Object?> get props => [
        user,
        accessToken,
        refreshToken,
        isLoading,
        error,
        isInitialized,
        endedBecause,
      ];
}

/// The auth state a fresh session scope starts from, instead of reading
/// secure storage.
///
/// `SessionScope` sets it when it replaces every provider after a sign-out:
/// it already knows nobody is signed in, and why.
final authSeedProvider = Provider<AuthState?>((ref) => null);

/// How long sign-out waits on the server before it carries on regardless.
/// A provider so tests can shorten it.
final signOutServerTimeoutProvider =
    Provider<Duration>((ref) => const Duration(seconds: 3));

/// Provider for the authentication state.
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref, seed: ref.read(authSeedProvider));
});

/// State notifier for managing authentication state.
class AuthStateNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  StreamSubscription<SessionEndReason>? _revocations;

  /// Set while [logout] talks to the server. A refresh it sets off may be
  /// refused, which the interceptor reports as an expired session; that
  /// must not turn the person's own sign-out into "your session has ended".
  bool _signingOut = false;

  AuthStateNotifier(this._ref, {AuthState? seed})
      : super(seed ?? const AuthState()) {
    // The network layer deletes the tokens when the server refuses them;
    // this is how the UI finds out.
    _revocations = SessionEvents.revoked.listen(_onRevoked);
    if (seed == null) _initialize();
  }

  @override
  void dispose() {
    _revocations?.cancel();
    super.dispose();
  }

  /// Initialize auth state from secure storage.
  Future<void> _initialize() async {
    try {
      final storage = _ref.read(secureStorageServiceProvider);
      final accessToken = await storage.getAccessToken();
      final refreshToken = await storage.getRefreshToken();
      if (!mounted) return;

      if (accessToken != null && accessToken.isNotEmpty) {
        state = state.copyWith(
            accessToken: accessToken,
            refreshToken: refreshToken,
            isInitialized: true);
        debugPrint('AuthStateNotifier: Restored session from storage');
        unawaited(_ref.read(pushRegistrationProvider).onSessionRestored());
      } else {
        state = state.copyWith(isInitialized: true);
        debugPrint('AuthStateNotifier: No saved session found');
        // Nobody signed in: no number on the icon, whatever the last
        // session or push left there.
        unawaited(_ref.read(appBadgeProvider).clear());
      }
    } catch (e) {
      debugPrint('AuthStateNotifier: Error initializing: $e');
      if (mounted) state = state.copyWith(isInitialized: true);
    }
  }

  /// Set loading state.
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading, clearError: true);
  }

  /// Set authenticated state after successful login.
  Future<void> setAuthenticated(
      {required String accessToken,
      required String refreshToken,
      UserProfile? user}) async {
    // Whoever used the phone before -- this person or another -- leaves
    // nothing behind for the new session: no saved answers, tickets, PDFs
    // or private pictures. Normally the last sign-out already did this; an
    // app killed mid-sign-out, or a session ended while nothing listened,
    // did not.
    await _ref.read(sessionCachesProvider).clearAll();
    final storage = _ref.read(secureStorageServiceProvider);
    await storage.saveTokens(
        accessToken: accessToken, refreshToken: refreshToken);

    state = AuthState(
        user: user,
        accessToken: accessToken,
        refreshToken: refreshToken,
        isLoading: false,
        isInitialized: true);
    debugPrint('AuthStateNotifier: User authenticated');
    // The moment to ask for push permission: the person has just chosen to
    // sign in, rather than being met by a prompt before the app has shown
    // anything.
    unawaited(_ref.read(pushRegistrationProvider).onSignedIn());
  }

  /// The same person's session, on new tokens: after a password change,
  /// which ends every session the account had, this one included. Unlike
  /// [setAuthenticated] it keeps what is saved on the phone (tickets,
  /// answers, the scanner's queue) -- it is still their phone and their
  /// account -- and asks for nothing.
  Future<void> renewSession({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _ref.read(secureStorageServiceProvider).saveTokens(
        accessToken: accessToken, refreshToken: refreshToken);
    if (!mounted) return;
    state = state.copyWith(
      accessToken: accessToken,
      refreshToken: refreshToken,
      isInitialized: true,
    );
  }

  /// Sign out: tell the server to forget this device's push token, end the
  /// session on the server, delete the FCM token, delete the tokens.
  ///
  /// The server calls go first, while the tokens are still stored, so an
  /// access token that has expired can be refreshed once on the way -- the
  /// revoke used to run after the refresh token was cleared, and failed
  /// silently for anyone signed in longer than an access token lasts. They
  /// are best effort and capped ([signOutServerTimeoutProvider], 3 s): a
  /// sign-out never waits long on the network or fails because of it.
  ///
  /// Setting the state is the last step: `SessionScope` sees it and replaces
  /// every provider, so the next person to sign in starts with nothing of
  /// this one's.
  Future<void> logout() async {
    final storage = _ref.read(secureStorageServiceProvider);
    final push = _ref.read(pushRegistrationProvider);
    final revoker = _ref.read(sessionRevokerProvider);
    final cap = _ref.read(signOutServerTimeoutProvider);
    _signingOut = true;
    try {
      String? accessToken;
      try {
        accessToken = await storage.getAccessToken();
      } catch (e) {
        debugPrint('AuthStateNotifier: could not read the token: $e');
      }
      if (accessToken != null && accessToken.isNotEmpty) {
        final token = accessToken;
        try {
          await () async {
            await push.unregisterOnServer();
            await revoker.revoke(token, stored: true);
          }()
              .timeout(cap);
        } catch (e) {
          debugPrint('AuthStateNotifier: server sign-out cut short: $e');
        }
      }
      unawaited(push.onSignedOut());
      // The person's unread count leaves the icon with them.
      unawaited(_ref.read(appBadgeProvider).clear());
      try {
        await storage.clearTokens();
      } catch (e) {
        debugPrint('AuthStateNotifier: Error during logout: $e');
      }
      // Everything kept about this person goes with them.
      await _ref.read(sessionCachesProvider).clearAll();
    } finally {
      _signingOut = false;
    }
    if (!mounted) return;
    state = const AuthState(
      isInitialized: true,
      endedBecause: SessionEndReason.signedOut,
    );
    debugPrint('AuthStateNotifier: User logged out');
  }

  /// The server refused the stored session. The interceptor has deleted the
  /// tokens; take the person to sign-in and say why.
  Future<void> _onRevoked(SessionEndReason reason) async {
    if (_signingOut || !state.isAuthenticated) return;
    debugPrint('AuthStateNotifier: session ended by the server ($reason)');
    unawaited(_ref.read(pushRegistrationProvider).onSignedOut());
    unawaited(_ref.read(appBadgeProvider).clear());
    try {
      await _ref.read(secureStorageServiceProvider).clearTokens();
    } catch (e) {
      debugPrint('AuthStateNotifier: could not clear tokens: $e');
    }
    await _ref.read(sessionCachesProvider).clearAll();
    if (!mounted) return;
    state = AuthState(isInitialized: true, endedBecause: reason);
  }

  /// The sign-in screen has told the person why they were signed out.
  void acknowledgeSessionEnd() {
    if (state.endedBecause == null) return;
    state = state.copyWith(clearEndReason: true);
  }
}

/// What the sign-in screen says about how the last session ended, or null
/// when there is nothing to say (nobody was signed in, or they chose to sign
/// out).
String? sessionEndNotice(SessionEndReason? reason) {
  switch (reason) {
    case SessionEndReason.expired:
      return 'Your session has ended. Please sign in again.';
    case SessionEndReason.suspended:
      return 'This account has been suspended. If you think this is a '
          'mistake, write to support@myotherapp.in.';
    case SessionEndReason.signedOut:
    case null:
      return null;
  }
}

/// Provider for checking if user is authenticated.
final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(authStateProvider).isAuthenticated);
