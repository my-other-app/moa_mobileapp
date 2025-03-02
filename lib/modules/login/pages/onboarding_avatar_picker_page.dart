import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/core/blocs/app_bloc/app_bloc_bloc.dart';
import 'package:myotherapp/modules/login/pages/onboarding_final_page.dart';
import 'package:myotherapp/modules/login/pages/widgest/avatar_picker_bottom_sheet.dart';

Widget _buildDragIndicator() {
  return Row(
    children: [
      Expanded(
        child: Container(
          height: 4,
          decoration: ShapeDecoration(
            color: const Color(0xFF17A58F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 4,
          decoration: ShapeDecoration(
            color: const Color(0xFF17A58F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 4,
          decoration: ShapeDecoration(
            color: const Color(0xFF17A58F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildProfileImage(String? avatarUrl) {
  return Container(
    width: 150,
    height: 150,
    decoration: ShapeDecoration(
      // image: DecorationImage(
      //   image: profileImageUrl != null
      //       ? NetworkImage(profileImageUrl!)
      //       : const AssetImage('assets/images/profile_placeholder.png')
      //           as ImageProvider,
      //   fit: BoxFit.cover,
      // ),
      color: const Color(0xFFCCC1F0),
      shape: const OvalBorder(),
    ),
    child: CachedNetworkImage(
      imageUrl: avatarUrl ?? '',
      imageBuilder: (context, imageProvider) => Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: imageProvider,
            fit: BoxFit.cover,
          ),
        ),
      ),
      placeholder: (context, url) => const CircularProgressIndicator(),
      errorWidget: (context, url, error) => const Icon(Icons.face),
    ),
  );
}

class OnboardingAvatarPickerPage extends StatefulWidget {
  const OnboardingAvatarPickerPage({super.key});

  @override
  OnboardingAvatarPickerPageState createState() =>
      OnboardingAvatarPickerPageState();
}

class OnboardingAvatarPickerPageState
    extends State<OnboardingAvatarPickerPage> {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0).copyWith(bottom: 32),
          child: Column(
            spacing: 8,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDragIndicator(),
              Text(
                "Time to flex with your profile pic",
                style: textTheme.headlineSmall,
              ),
              Text("Choose your profile pic", style: textTheme.bodyMedium),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BlocConsumer<AppBloc, AppBlocState>(
                      listener: (context, state) {},
                      buildWhen: (previous, current) =>
                          previous.profile?.profile?.avatar !=
                          current.profile?.profile?.avatar,
                      builder: (context, state) {
                        //TODO  : need to add high res images
                        return _buildProfileImage(
                            state.profile?.profile?.avatar?.image.original);
                      },
                    ),
                    SizedBox(height: 16),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                            context: context,
                            builder: (_) => AvatarPickerBottomSheet());
                      },
                      child: Text(
                        "Tap to choose",
                        style: textTheme.bodyLarge!.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  ],
                ),
              ),
              Spacer(),
              FilledButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OnboardingFinalPage(),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("START THE JOURNEY"),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 28),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
