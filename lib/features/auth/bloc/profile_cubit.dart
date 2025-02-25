import 'package:bloc/bloc.dart';
import '../data/models/profile.dart';
import '../data/services/profile_service.dart';

abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final Profile profile;
  ProfileLoaded({required this.profile});
}

class ProfileFailure extends ProfileState {
  final String error;
  ProfileFailure({required this.error});
}

class ProfileCubit extends Cubit<ProfileState> {
  final ProfileService profileService;

  ProfileCubit({required this.profileService}) : super(ProfileInitial());

  Future<void> getProfile(String accessToken) async {
    emit(ProfileLoading());
    try {
      final profile = await profileService.getProfile(accessToken);
      print(
          "Profile fetched: $profile"); // This now uses your custom toString()
      emit(ProfileLoaded(profile: profile));
    } catch (e, stacktrace) {
      print("Error fetching profile: $e");
      print("Stacktrace: $stacktrace");
      emit(ProfileFailure(error: e.toString()));
    }
  }
}
