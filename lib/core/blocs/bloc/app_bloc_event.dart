part of 'app_bloc_bloc.dart';

@immutable
sealed class AppBlocEvent extends Equatable{
  const AppBlocEvent({this.user, this.refreshToken, this.accessToken, this.profile});

  final UserModel? user;
  final String? refreshToken;
  final String? accessToken;
  final Profile? profile;

   @override
  List<dynamic> get props => [user, refreshToken, accessToken, profile];
}


class AppStarted extends AppBlocEvent {
  const AppStarted({user, refreshToken, accessToken,profile});

  

}

class LoggedInEvent extends AppBlocEvent {
  const LoggedInEvent({
   required super.user,
   required super.accessToken,
   required super.refreshToken,
   required super.profile,
  });

  
}

class UpdateUserDetailsEvent extends AppBlocEvent{
  const UpdateUserDetailsEvent({super.accessToken, super.user, super.refreshToken, required super.profile});
  
}

class LoggedOutEvent extends AppBlocEvent {
  const LoggedOutEvent();
}
