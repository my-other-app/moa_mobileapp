import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show debugPrint, immutable;
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:myotherapp/common/models/user/user_model.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/modules/login/data/models/profile.dart';

part 'app_bloc_event.dart';
part 'app_bloc_state.dart';

class AppBloc extends HydratedBloc<AppBlocEvent, AppBlocState> {
  AppBloc() : super(const AppBlocInitialState()) {
    on<AppStarted>(_onAppStarted);
    on<LoggedInEvent>(_onLoggedIn);
    on<LoggedOutEvent>(_onLoggedOut);
    on<UpdateUserDetailsEvent>(_onUpdateUserDetails);
  }

  void _onAppStarted(
    AppStarted event,
    Emitter<AppBlocState> emit,
  ) async {
    // When app starts, check if we have stored state
    // If we already have a logged in state from hydrated storage, keep it
    // Otherwise, remain in initial state
    debugPrint('AppStarted event: Current state type: ${state.runtimeType}');

    if (state is AppLoggedInState) {
      final response = await APIService.instance.request(
        '/user/profile/me',
        DioMethod.get,
      );

      if (response.data == null) {

         Profile updatedProfile = Profile.fromJson(response.data);

         debugPrint('Updated profile: $updatedProfile');
        emit(UpdateUserDetailsState(
            user: state.user,
            accessToken: state.accessToken,
            refreshToken: state.refreshToken,
            profile: updatedProfile));
      }

      debugPrint('Profile response: ${response.data}');
      debugPrint(
          'User already logged in from hydrated state: ${(state as AppLoggedInState).user?.fullName}');
    } else {
      debugPrint('No logged in state found, remaining in initial state');
    }
  }

  Future<void> _onUpdateUserDetails(
    UpdateUserDetailsEvent event,
    Emitter<AppBlocState> emit,
  ) async {
    debugPrint('UpdateUserDetails event with user: ${event.profile?.fullName}');
    log('UpdateUserDetails event with user: ${event.profile?.toJson()}');
    emit(UpdateUserDetailsState(
      user: event.user,
      accessToken: event.accessToken,
      refreshToken: event.refreshToken,
      profile: event.profile,
    ));
  }

  Future<void> _onLoggedIn(
    LoggedInEvent event,
    Emitter<AppBlocState> emit,
  ) async {
    debugPrint('LoggedIn event with user: ${event.user?.fullName}');

    try {
      final response = await APIService.instance.request(
        '/user/profile/me',
        DioMethod.get,
      );

      debugPrint('Profile response: ${response.data}');

      // Check if the response data is valid
      if (response.data == null) {
        debugPrint('Profile response data is null');
        // Emit state without profile if data is null
        emit(AppLoggedInState(
          user: event.user,
          accessToken: event.accessToken,
          refreshToken: event.refreshToken,
          profile: event.profile,
        ));
        return;
      }

      // Check the structure of the response data
      debugPrint('Profile response data type: ${response.data.runtimeType}');

      Profile? recentlyFetchedProfile;
      try {
        recentlyFetchedProfile = Profile.fromJson(response.data);
        debugPrint('Profile parsed successfully: $recentlyFetchedProfile');
      } catch (e) {
        debugPrint('Error parsing profile from JSON: $e');
        // Try to see if the data is nested
        if (response.data is Map<String, dynamic> &&
            response.data.containsKey('data') &&
            response.data['data'] != null) {
          try {
            recentlyFetchedProfile = Profile.fromJson(response.data['data']);
            debugPrint('Profile parsed from nested data: $recentlyFetchedProfile');
          } catch (e) {
            debugPrint('Error parsing profile from nested data: $e');
          }
        }
      }

      emit(AppLoggedInState(
        user: event.user,
        accessToken: event.accessToken,
        refreshToken: event.refreshToken,
        profile: recentlyFetchedProfile,
      ));
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      // Still emit logged in state but without profile
      emit(AppLoggedInState(
        user: event.user,
        accessToken: event.accessToken,
        refreshToken: event.refreshToken,
        profile: event.profile,
      ));
    }
  }

  void _onLoggedOut(
    LoggedOutEvent event,
    Emitter<AppBlocState> emit,
  ) {
    SecureStorage.instance.deleteTokens();
    debugPrint('LoggedOut event received');
    emit(const AppBlocInitialState());
  }

  @override
  AppBlocState? fromJson(Map<String, dynamic> json) {
    try {
      final stateType = json['stateType'] as String?;
      debugPrint('fromJson called with stateType: $stateType');
      debugPrint('Full JSON: $json');

      if (stateType == null) {
        return const AppBlocInitialState();
      }

      if (stateType == 'AppBlocInitialState') {
        return const AppBlocInitialState();
      }

      if (stateType == 'AppLoggedOutState') {
        return const AppLoggedOutState();
      }

      return AppLoggedInState(
        user: UserModel.fromJson(json['user']),
        accessToken: json['accessToken'],
        refreshToken: json['refreshToken'],
        profile:
            json['profile'] != null ? Profile.fromJson(json['profile']) : null,
      );
    } catch (e) {
      debugPrint('Error deserializing AppBlocState: $e');
      return const AppBlocInitialState();
    }
  }

  @override
  Map<String, dynamic>? toJson(AppBlocState state) {
    try {
      if (state is AppLoggedInState && state.user != null) {
        debugPrint(
            'Saving logged in state to storage for user: ${state.user?.fullName}');
        return {
          'stateType': 'AppLoggedInState',
          'user': state.user?.toJson(state.user!),
          'accessToken': state.accessToken,
          'refreshToken': state.refreshToken,
          'profile': state.profile?.toJson(),
        };
      } else if (state is AppLoggedOutState) {
        return {
          'stateType': 'AppLoggedOutState',
        };
      } else if (state is AppBlocInitialState) {
        return {
          'stateType': 'AppBlocInitialState',
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error serializing AppBlocState: $e');
      return null;
    }
  }
}
