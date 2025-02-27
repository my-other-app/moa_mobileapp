part of 'app_bloc_bloc.dart';

@immutable
sealed class AppBlocEvent extends Equatable{
  const AppBlocEvent();

   @override
  List<Object> get props => <Object>[];
}


class AppStarted extends AppBlocEvent {
  const AppStarted({this.user, this.refreshToken, this.accessToken,});

  final UserModel? user;
  final String? refreshToken;
  final String? accessToken;

}

class LoggedIn extends AppBlocEvent {
  const LoggedIn({
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

class LoggedOut extends AppBlocEvent {
  const LoggedOut();
}
