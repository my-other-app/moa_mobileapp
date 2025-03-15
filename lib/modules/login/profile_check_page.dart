import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/common/models/user/user_model.dart';
import 'package:myotherapp/core/blocs/app_bloc/app_bloc_bloc.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/modules/home/screen.dart';
import 'package:myotherapp/modules/login/cubit/profile_cubit.dart';
import 'package:myotherapp/modules/login/data/models/profile.dart';
import 'package:myotherapp/modules/login/data/services/profile_service.dart';
import 'package:myotherapp/modules/login/pages/onboarding_details_page.dart';
import 'package:myotherapp/modules/login/pages/onboarding_initial_page.dart';

class ProfileCheckPage extends StatelessWidget {
  final String accessToken;
  final String profileUrl;
  const ProfileCheckPage(
      {super.key, required this.accessToken, required this.profileUrl});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (context) => ProfileCubit(profileService: ProfileService())
        ..getProfile(accessToken),
      child: Scaffold(
        body: BlocConsumer<ProfileCubit, ProfileState>(
          listener: (context, state) {
            if (state is ProfileLoaded) {
              debugPrint("Full profile data: ${state.profile}");

              // Create a UserModel from the profile data
              final user = UserModel(
                fullName: state.profile.fullName ?? '',
                email: state.profile.email ?? '',
                phone: state.profile.phone ?? '',
              );

              // Get the refresh token from secure storage
              SecureStorage.instance.getAccessToken().then((tokenModel) {
                if (context.mounted) {
                  // Update the AppBloc with the user and tokens
                  context.read<AppBloc>().add(
                        LoggedInEvent(
                          user: user,
                          accessToken: accessToken,
                          refreshToken: tokenModel.refreshToken,
                          profile: state.profile,
                        ),
                      );

                  // Check the interest field from the nested profile.
                  final ProfileDetails? profile = state.profile.profile;
                  if (profile == null) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => OnboardingDetailsPage(
                                profileUrl: profileUrl,
                                initialName: state.profile.fullName,
                              )),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LandingPage()),
                      // MaterialPageRoute(builder: (context) => OnboardingAvatarPickerPage()),
                    );
                  }
                }
              }).catchError((error) {
                debugPrint("Error getting tokens: $error");
                // If we can't get the refresh token, navigate back to login
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => OnboardingInitialPage()),
                  );
                }
              });
            } else if (state is ProfileFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Profile error: ${state.error}')),
              );
            }
          },
          builder: (context, state) {
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}
