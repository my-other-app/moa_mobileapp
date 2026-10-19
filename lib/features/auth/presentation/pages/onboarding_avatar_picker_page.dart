import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/auth/presentation/pages/widgest/avatar_picker_bottom_sheet.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

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
      color: const Color(0xFFCCC1F0),
      shape: const OvalBorder(),
    ),
    child: ClipOval(
      child: AppNetworkImage(
        url: avatarUrl,
        width: 150,
        height: 150,
        placeholder: (_) => const Center(child: CircularProgressIndicator()),
        errorWidget: (_) => const Icon(Icons.face),
      ),
    ),
  );
}

/// Onboarding Avatar Picker Page - migrated to Riverpod.
class OnboardingAvatarPickerPage extends ConsumerWidget {
  const OnboardingAvatarPickerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final profileState = ref.watch(profileProvider);
    final avatarUrl = profileState.profile?.avatar?.image.original;

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
                    _buildProfileImage(avatarUrl),
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
                  context.go('/onboarding/complete');
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
