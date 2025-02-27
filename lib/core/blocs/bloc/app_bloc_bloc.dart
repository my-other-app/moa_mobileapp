import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show debugPrint, immutable;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:myotherapp/common/models/user/main.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/features/auth/data/models/profile.dart';

part 'app_bloc_event.dart';
part 'app_bloc_state.dart';

class AppBloc extends HydratedBloc<AppBlocEvent, AppBlocState> {
  AppBloc({required this.user}) : super(const AppBlocInitialState()) {
    on<AppStarted>(_onAppStarted);
    on<LoggedIn>(_onLoggedIn);
    on<LoggedOut>(_onLoggedOut);
  }
  final UserModel? user;

  void _onAppStarted(
    AppStarted event,
    Emitter<AppBlocState> emit,
  ){
    // When app starts, check if we have stored state
    // If we already have a logged in state from hydrated storage, keep it
    // Otherwise, remain in initial state
    debugPrint('AppStarted event: Current state type: ${state.runtimeType}');
    
    if (state is AppLoggedInState) {
      debugPrint('User already logged in from hydrated state: ${(state as AppLoggedInState).user?.fullName}');
    } else {
      debugPrint('No logged in state found, remaining in initial state');
    }
  }

  Future<void> _onLoggedIn(
    LoggedIn event,
    Emitter<AppBlocState> emit,
  )async{
    debugPrint('LoggedIn event with user: ${event.user.fullName}');
    
    final response = await APIService.instance.request(
      '/user/profile/me',
      DioMethod.get,
    );

    debugPrint('Profile response: ${response.data}');

    emit(AppLoggedInState(
      user: event.user, 
      accessToken: event.accessToken, 
      refreshToken: event.refreshToken,
      profile: Profile.fromJson(response.data),
    ));
  }

  void _onLoggedOut(
    LoggedOut event,
    Emitter<AppBlocState> emit,
  ){
    SecureStorage.instance.deleteTokens();
    debugPrint('LoggedOut event received');
    emit(const AppBlocInitialState());
  }

  @override
  AppBlocState? fromJson(Map<String, dynamic> json) {
    try {
      if (json['user'] == null || json['accessToken'] == null || json['refreshToken'] == null) {
        print('Missing required fields in stored state, returning initial state');
        return const AppBlocInitialState();
      }
      
      print('Restoring logged in state from storage');
      return AppLoggedInState(
        user: UserModel.fromJson(json['user']),
        accessToken: json['accessToken'],
        refreshToken: json['refreshToken'],
        profile: Profile.fromJson(json['profile']),
      );
    } catch (e) {
      print('Error deserializing AppBlocState: $e');
      return const AppBlocInitialState();
    }
  }

  @override
  Map<String, dynamic>? toJson(AppBlocState state) {
   try {
    if (state is AppLoggedInState && state.user != null) {
      print('Saving logged in state to storage for user: ${state.user?.fullName}');
      return {
        'user': state.user?.toJson(state.user!),
        'accessToken': state.accessToken,
        'refreshToken': state.refreshToken,
      };
    }
    return null;
   } catch (e) {
    print('Error serializing AppBlocState: $e');
    return null;
   }
  }
}
