part of 'login_cubit.dart';



/// Login States
abstract class LoginState {}

class LoginInitial extends LoginState {}

class LoginLoading extends LoginState {}

class LoginSuccess extends LoginState {
  final String accessToken;
  final String refreshToken;
  final String photoUrl;
  
  LoginSuccess({
    required this.accessToken,
    required this.refreshToken,
    required this.photoUrl,
  });
}

class LoginFailure extends LoginState {
  final String error;
  
  LoginFailure({required this.error});
}
