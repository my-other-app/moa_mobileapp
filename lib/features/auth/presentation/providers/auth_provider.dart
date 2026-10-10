import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/core/storage/secure_storage_service.dart';
import 'package:finnet/features/profile/domain/entities/profile_entity.dart';
import 'package:finnet/core/services/notification_service.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

/// Authentication state for the application.
class AuthState extends Equatable {
  final UserProfile? user;
  final String? accessToken;
  final String? refreshToken;
  final bool isLoading;
  final String? error;
  final bool isInitialized;

  const AuthState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.isLoading = false,
    this.error,
    this.isInitialized = false,
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
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  @override
  List<Object?> get props =>
      [user, accessToken, refreshToken, isLoading, error, isInitialized];
}

/// Provider for the authentication state.
final authStateProvider =
    StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier(ref);
});

/// State notifier for managing authentication state.
class AuthStateNotifier extends StateNotifier<AuthState> {
  final Ref _ref;

  AuthStateNotifier(this._ref) : super(const AuthState()) {
    _initialize();
  }

  /// Initialize auth state from secure storage.
  Future<void> _initialize() async {
    try {
      final storage = _ref.read(secureStorageServiceProvider);
      final accessToken = await storage.getAccessToken();
      final refreshToken = await storage.getRefreshToken();

      if (accessToken != null && accessToken.isNotEmpty) {
        state = state.copyWith(
            accessToken: accessToken,
            refreshToken: refreshToken,
            isInitialized: true);
        debugPrint('AuthStateNotifier: Restored session from storage');
        // Register FCM token now that we have session
        NotificationService().registerToken();
        if (state.user != null) {
          Fluttertoast.showToast(
            msg: "Logged in as User ID: ${state.user!.id}",
            backgroundColor: Colors.blue,
            textColor: Colors.white,
            toastLength: Toast.LENGTH_LONG,
          );
        }
      } else {
        state = state.copyWith(isInitialized: true);
        debugPrint('AuthStateNotifier: No saved session found');
      }
    } catch (e) {
      debugPrint('AuthStateNotifier: Error initializing: $e');
      state = state.copyWith(isInitialized: true);
    }
  }

  /// Set loading state.
  void setLoading(bool isLoading) {
    state = state.copyWith(isLoading: isLoading, clearError: true);
  }

  /// Set error state.
  void setError(String error) {
    state = state.copyWith(error: error, isLoading: false);
  }

  /// Set authenticated state after successful login.
  Future<void> setAuthenticated(
      {required String accessToken,
      required String refreshToken,
      UserProfile? user}) async {
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
    // Register FCM token after login
    NotificationService().registerToken();
    if (user != null) {
      Fluttertoast.showToast(
        msg: "Logged in as User ID: ${user.id}",
        backgroundColor: Colors.blue,
        textColor: Colors.white,
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  /// Update user profile.
  void updateUser(UserProfile user) {
    state = state.copyWith(user: user);
    debugPrint('AuthStateNotifier: User profile updated');
  }

  /// Logout and clear session.
  Future<void> logout() async {
    try {
      final storage = _ref.read(secureStorageServiceProvider);
      await storage.clearTokens();
      state = const AuthState(isInitialized: true);
      debugPrint('AuthStateNotifier: User logged out');
    } catch (e) {
      debugPrint('AuthStateNotifier: Error during logout: $e');
      state = const AuthState(isInitialized: true);
    }
  }
}

/// Provider for checking if user is authenticated.
final isAuthenticatedProvider =
    Provider<bool>((ref) => ref.watch(authStateProvider).isAuthenticated);

/// Provider for checking if auth is initialized.
final isAuthInitializedProvider =
    Provider<bool>((ref) => ref.watch(authStateProvider).isInitialized);

/// Provider for getting the current user.
final currentUserProvider =
    Provider<UserProfile?>((ref) => ref.watch(authStateProvider).user);
