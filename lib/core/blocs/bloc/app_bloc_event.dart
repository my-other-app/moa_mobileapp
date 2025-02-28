part of 'app_bloc_bloc.dart';

@immutable
sealed class AppBlocEvent extends Equatable{
  const AppBlocEvent();

   @override
  List<Object> get props => <Object>[];
}


class AppStarted extends AppBlocEvent {
  const AppStarted({this.user, this.refreshToken, this.accessToken,this.profile});

  final UserModel? user;
  final String? refreshToken;
  final String? accessToken;
  final Profile? profile;

}

class LoggedInEvent extends AppBlocEvent {
  const LoggedInEvent({
   required this.user,
   required this.accessToken,
   required this.refreshToken,
   required this.profile,
  });

  final UserModel user;
  final String accessToken;
  final String refreshToken;
  final Profile profile;
}

class UpdateUserDetailsEvent extends AppBlocEvent{
  const UpdateUserDetailsEvent({required this.profile});
  
  final Profile profile;
}

class LoggedOutEvent extends AppBlocEvent {
  const LoggedOutEvent();
}
