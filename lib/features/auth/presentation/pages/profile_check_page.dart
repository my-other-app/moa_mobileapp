import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/common/models/user/main.dart';
import 'package:myotherapp/core/blocs/bloc/app_bloc_bloc.dart';
import 'package:myotherapp/core/secure_storage/secure_storage.dart';
import 'package:myotherapp/presentation/login/onboarding_final_page.dart';
import 'package:myotherapp/presentation/home/screen.dart';
import '../../../../presentation/login/onboarding_details_page.dart';
import '../../bloc/profile_cubit.dart';
import '../../data/services/profile_service.dart';

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
              print("Full profile data: ${state.profile}");

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
                        LoggedIn(
                          user: user,
                          accessToken: accessToken,
                          refreshToken: tokenModel.refreshToken,
                        ),
                      );

                  // Check the interest field from the nested profile.
                  final interest = state.profile.profile?.interest;
                  if (interest == null ||
                      interest.trim().isEmpty ||
                      interest.toLowerCase() == 'string') {
                    // Navigator.pushReplacement(
                    //   context,
                    //   MaterialPageRoute(
                    //       builder: (context) => OnboardingFinalPage()),
                    // );
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OnboardingDetailsPage(
                          initialName: state.profile.fullName ?? '',
                          profileUrl: profileUrl,
                        ),
                      ),
                    );
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LandingPage()),
                    );
                  }
                }
              }).catchError((error) {
                debugPrint("Error getting tokens: $error");
                // If we can't get the refresh token, navigate back to login
                if (context.mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LandingPage()),
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
