import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/auth/presentation/sign_in_gate.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/presentation/widgets/my_picture.dart';

/// Onboarding Final Page - migrated to Riverpod.
class OnboardingFinalPage extends ConsumerWidget {
  const OnboardingFinalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFA0),
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/grass.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        const SizedBox(height: 48),
                        _buildProfileCreatedSection(),
                        Spacer(),
                        _buildProfileImage(),
                        const SizedBox(height: 24),
                        _buildMotivationalText(),
                        Spacer(),
                        Spacer(),
                        FilledButton(
                          onPressed: () {
                            // An avatar or an uploaded photo.
                            if (profile?.pictureUrl() != null) {
                              // A new account made from "sign in to follow"
                              // (say) goes back to that club, else home.
                              goAfterSignIn(
                                  context, signInFromOf(context));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('select profile pic to proceed')),
                              );
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("START THE JOURNEY"),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 28),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40), // bottom padding for grass
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCreatedSection() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Color(0xFF0A9D46), width: 2),
          ),
          padding: const EdgeInsets.all(6),
          child: const Icon(
            Icons.check,
            size: 32,
            color: Color(0xFF0A9D46),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'PROFILE',
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.w400,
            color: Color(0xFF2C333D),
          ),
        ),
        Text(
          'CREATED',
          style: TextStyle(
            fontSize: 28,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.w400,
            color: Color(0xFF2C333D),
          ),
        ),
      ],
    );
  }

  /// The avatar chosen a step earlier. Not tappable: there is no picker
  /// here, so it no longer looks like one ("+ add pic" did nothing).
  Widget _buildProfileImage() => const MyPicture(size: 120);

  Widget _buildMotivationalText() {
    return Column(
      children: [
        Text(
          "LET'S GO!",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontFamily: 'BebasNeue',
            fontWeight: FontWeight.w400,
            color: Color(0xFF2C333D),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Fuel your success journey, Crush every challenge, and Create unforgettable memories while doing it.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF5A5A5A),
            ),
          ),
        ),
      ],
    );
  }
}
