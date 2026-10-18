import 'package:finnet/features/auth/data/models/profile.dart';
import 'package:finnet/features/auth/data/services/profile_service.dart';
import 'package:finnet/core/network/api_exception.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/sign_in_errors.dart';

/// Profile state classes (no longer using Bloc).
abstract class ProfileState {}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final Profile profile;
  ProfileLoaded({required this.profile});
}

class ProfileFailure extends ProfileState {
  /// What to show: already worded for a person.
  final String error;

  /// Whether signing in again is the way out: the session the profile was
  /// asked for with is over, or the account cannot use the app at all.
  /// Trying again would only fail the same way.
  final bool needsSignIn;

  ProfileFailure({required this.error, this.needsSignIn = false});
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
      final api = apiExceptionOf(e);
      final type = api?.type;
      _state = ProfileFailure(
        // The profile endpoint takes attendee accounts only, so a 403 with
        // INSUFFICIENT_PERMISSIONS here is a club's account.
        error: api?.errorCode == 'INSUFFICIENT_PERMISSIONS'
            ? clubAccountMessage
            : signInErrorMessage(
                e,
                defaultMessage: 'Could not load your profile. Please try again.',
              ),
        needsSignIn: type == ApiExceptionType.unauthorized ||
            type == ApiExceptionType.forbidden,
      );
      onStateChanged?.call(_state);
    }
  }
}
