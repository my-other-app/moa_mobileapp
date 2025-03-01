part of 'app_bloc_bloc.dart';

abstract class AppBlocState extends Equatable {
  const AppBlocState({this.user, this.accessToken, this.refreshToken, this.profile});

  final UserModel? user;
  final String? accessToken;
  final String? refreshToken;
  final Profile? profile;

  @override
  List<Object?> get props => <Object?>[user, accessToken, refreshToken, profile];
}

class AppBlocInitialState extends AppBlocState {
  const AppBlocInitialState({super.user, super.accessToken, super.refreshToken, super.profile});
  
  @override
  List<Object?> get props => <Object?>[user, accessToken, refreshToken, profile];
}

class AppLoggedInState extends AppBlocState {
  const AppLoggedInState({
    required super.user, 
    required super.accessToken, 
    required super.refreshToken,
    required super.profile,
  });
  
  @override
  List<Object?> get props => <Object?>[user, accessToken, refreshToken, profile];
}

class UpdateUserDetailsState extends AppBlocState {
  const UpdateUserDetailsState({
    required super.user, 
    required super.accessToken, 
    required super.refreshToken,
    required super.profile,
  });
 

  @override
  List<Object?> get props => <Object?>[user, accessToken, refreshToken, profile];
}

class AppLoggedOutState extends AppBlocState {
  const AppLoggedOutState();
  @override
  List<Object?> get props => <Object?>[user, accessToken, refreshToken, profile ];
}
