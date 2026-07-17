import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:finnet/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:finnet/features/auth/domain/entities/user_entity.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// State for login operations.
class LoginState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final String? photoUrl;

  const LoginState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.photoUrl,
  });

  LoginState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    String? photoUrl,
  }) {
    return LoginState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}

/// Provider for login state management.
final loginProvider = StateNotifierProvider<LoginNotifier, LoginState>((ref) {
  return LoginNotifier(ref);
});

/// Notifier for handling login operations.
class LoginNotifier extends StateNotifier<LoginState> {
  final Ref _ref;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  LoginNotifier(this._ref) : super(const LoginState());

  /// Sign in with Google.
  Future<bool> signInWithGoogle() async {
    state = const LoginState(isLoading: true);

    try {
      // Trigger Google Sign In
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled
        state = const LoginState(error: 'Sign in was cancelled');
        return false;
      }

      // Get auth details
      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        state = const LoginState(error: 'Failed to get authentication token');
        return false;
      }

      // Store photo URL
      state = state.copyWith(photoUrl: googleUser.photoUrl);

      String platformStr = 'web';
      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          platformStr = 'ios';
        } else if (defaultTargetPlatform == TargetPlatform.android) {
          platformStr = 'android';
        }
      }

      // Call our API with the token
      final authRepository = _ref.read(authRepositoryProvider);
      final credentials = GoogleCredentials(
        idToken: idToken,
        platform: platformStr,
        photoUrl: googleUser.photoUrl,
      );

      final result = await authRepository.signInWithGoogle(credentials);

      return result.fold(
        (failure) {
          state = LoginState(error: failure.message);
          return false;
        },
        (tokens) async {
          // Update auth state
          await _ref.read(authStateProvider.notifier).setAuthenticated(
                accessToken: tokens.accessToken,
                refreshToken: tokens.refreshToken,
              );

          // Load user profile
          await _ref.read(profileProvider.notifier).loadProfile();

          state = const LoginState(isSuccess: true);
          return true;
        },
      );
    } catch (e) {
      debugPrint('LoginNotifier: Error during Google sign in: $e');
      state = LoginState(error: 'An error occurred during sign in: $e');
      return false;
    }
  }

  /// Reset login state.
  void reset() {
    state = const LoginState();
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _ref.read(authStateProvider.notifier).logout();
      _ref.read(profileProvider.notifier).clearProfile();
      state = const LoginState();
    } catch (e) {
      debugPrint('LoginNotifier: Error during sign out: $e');
    }
  }
}

/// Provider for Google sign in flow state.
final isGoogleSignInLoadingProvider = Provider<bool>((ref) {
  return ref.watch(loginProvider).isLoading;
});
