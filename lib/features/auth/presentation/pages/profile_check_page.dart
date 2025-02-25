import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_details_page.dart';
import 'package:myotherapp/presentation/home/screen.dart';
import '../../bloc/profile_cubit.dart';
import '../../data/services/profile_service.dart';

class ProfileCheckPage extends StatelessWidget {
  final String accessToken;
  final String profileUrl;
  const ProfileCheckPage(
      {Key? key, required this.accessToken, required this.profileUrl})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (context) => ProfileCubit(profileService: ProfileService())
        ..getProfile(accessToken),
      child: Builder(
        builder: (context) {
          return BlocListener<ProfileCubit, ProfileState>(
            listener: (context, state) {
              if (state is ProfileLoaded) {
                print("Full profile data: ${state.profile}");
                // Check the interest field from the nested profile.
                final interest = state.profile.profile?.interest;
                if (interest == null ||
                    interest.trim().isEmpty ||
                    interest.toLowerCase() == 'string') {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OnboardingDetailsPage(
                        initialName: state.profile.fullName,
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
              } else if (state is ProfileFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Profile error: ${state.error}')),
                );
              }
            },
            child: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        },
      ),
    );
  }
}
