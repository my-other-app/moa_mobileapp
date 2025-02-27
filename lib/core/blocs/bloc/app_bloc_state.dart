part of 'app_bloc_bloc.dart';

abstract class AppBlocState extends Equatable {
  const AppBlocState({this.user, this.accessToken, this.refreshToken, this.profile});

  final UserModel? user;
  final String? accessToken;
  final String? refreshToken;
  final Profile? profile;

  @override
  List<Object?> get props => <Object?>[user, accessToken, refreshToken];
}

class AppBlocInitialState extends AppBlocState {
  const AppBlocInitialState();
  
  @override
  List<Object?> get props => <Object?>[user, accessToken, refreshToken];
}

class AppLoggedInState extends AppBlocState {
  const AppLoggedInState({
    required UserModel user, 
    required String accessToken, 
    required String refreshToken,
    required Profile profile,
  }) : super(
    user: user, 
    accessToken: accessToken, 
    refreshToken: refreshToken,
    profile: profile
  );
  
  @override
  List<Object?> get props => <Object?>[user, accessToken, refreshToken];
}

class AppLoggedOutState extends AppBlocState {
  const AppLoggedOutState();
  @override
  List<Object?> get props => <Object?>[user, accessToken, refreshToken];
}
