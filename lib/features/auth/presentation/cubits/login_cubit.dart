import 'package:myotherapp/common/models/user/user_model.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/core/secure_storage/token_model.dart';
import 'package:myotherapp/features/auth/data/services/authentication_service.dart';
import 'package:myotherapp/features/auth/data/services/profile_service.dart';

/// Login States
abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final String accessToken;
  final String refreshToken;
  final String photoUrl;
  final UserModel? user;

  LoginSuccess({
    required this.accessToken,
    required this.refreshToken,
    required this.photoUrl,
    this.user,
  });
}

class Logout extends LoginState {}

class LoginFailure extends LoginState {
  final String error;
  LoginFailure({required this.error});
}

/// Login Cubit - converted to callback-based class (no Bloc dependency).
class LoginCubit {
  final AuthenticationService authService;
  final ProfileService profileService;

  LoginState _state = LoginInitial();
  LoginState get state => _state;

  // Callback for state changes
  void Function(LoginState)? onStateChanged;

  LoginCubit({
    required this.authService,
    ProfileService? profileService,
  }) : profileService = profileService ?? ProfileService();

  Future<void> loginWithGoogle(
      String idToken, String platform, String photoUrl) async {
    _state = LoginLoading();
    onStateChanged?.call(_state);

    try {
      final result = await authService.signInWithGoogle(
        idToken: idToken,
        platform: platform,
      );

      // Store tokens in secure storage
      final secureStorage = SecureStorage.instance;
      await secureStorage.updateTokens(TokenModel.fromJson(result));

      // Get user profile
      final accessToken = result['access_token'];
      _state = LoginSuccess(
        accessToken: accessToken,
        refreshToken: result['refresh_token'],
        photoUrl: photoUrl,
      );
      onStateChanged?.call(_state);
    } catch (e) {
      _state = LoginFailure(error: e.toString());
      onStateChanged?.call(_state);
    }
  }
}
