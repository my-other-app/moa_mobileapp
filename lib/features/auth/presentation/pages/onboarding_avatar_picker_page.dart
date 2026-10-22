import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:finnet/features/profile/presentation/widgets/my_picture.dart';

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

/// Onboarding Avatar Picker Page - migrated to Riverpod.
class OnboardingAvatarPickerPage extends ConsumerWidget {
  const OnboardingAvatarPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    // The same picker as Settings: a preset, or a photo.
                    // The old sheet showed an error for a pick the server
                    // had saved (it answers 500 after saving) and never
                    // reloaded the profile, so the last step refused to
                    // go on.
                    GestureDetector(
                      onTap: () => changeAvatar(context),
                      child: const MyPicture(size: 150),
                    ),
                    SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => changeAvatar(context),
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
                  context.go(withSignInFrom(
                      '/onboarding/complete', signInFromOf(context)));
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("CONTINUE"),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 28),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
