import 'package:bloc/bloc.dart';
import '../data/services/authentication_service.dart';

/// Login States
abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final String accessToken;
  final String refreshToken;

  LoginSuccess({required this.accessToken, required this.refreshToken});
}

class LoginFailure extends LoginState {
  final String error;
  LoginFailure({required this.error});
}

/// Login Cubit
class LoginCubit extends Cubit<LoginState> {
  final AuthenticationService authService;

  LoginCubit({required this.authService}) : super(LoginInitial());

  Future<void> loginWithGoogle(String idToken, String platform) async {
    emit(LoginLoading());
    try {
      final result = await authService.signInWithGoogle(
        idToken: idToken,
        platform: platform,
      );
      emit(LoginSuccess(
        accessToken: result['access_token'],
        refreshToken: result['refresh_token'],
      ));
    } catch (e) {
      emit(LoginFailure(error: e.toString()));
    }
  }
}
