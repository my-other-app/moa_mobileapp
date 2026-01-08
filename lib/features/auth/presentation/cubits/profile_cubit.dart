import 'package:myotherapp/features/auth/data/models/profile.dart';
import 'package:myotherapp/features/auth/data/services/profile_service.dart';

/// Profile state classes (no longer using Bloc).
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

/// ProfileCubit - converted to simple callback-based class (no Bloc dependency).
class ProfileCubit {
  final ProfileService profileService;
  ProfileState _state = ProfileInitial();

  ProfileState get state => _state;

  // Callback for state changes
  void Function(ProfileState)? onStateChanged;

  ProfileCubit({required this.profileService});

  Future<void> getProfile(String accessToken) async {
    _state = ProfileLoading();
    onStateChanged?.call(_state);

    try {
      final profile = await profileService.getProfile(accessToken);
      _state = ProfileLoaded(profile: profile);
      onStateChanged?.call(_state);
    } catch (e) {
      _state = ProfileFailure(error: e.toString());
      onStateChanged?.call(_state);
    }
  }
}
