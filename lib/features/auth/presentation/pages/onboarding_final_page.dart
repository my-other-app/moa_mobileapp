import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';

/// Onboarding Final Page - migrated to Riverpod.
class OnboardingFinalPage extends ConsumerWidget {
  const OnboardingFinalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;
    final avatarUrl = profile?.avatar?.image.original;

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
                        _buildProfileImage(avatarUrl),
                        const SizedBox(height: 24),
                        _buildMotivationalText(),
                        Spacer(),
                        Spacer(),
                        FilledButton(
                          onPressed: () {
                            final currentAvatar = profile?.avatar;
                            if (currentAvatar != null) {
                              context.go('/');
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

  Widget _buildProfileImage(String? imageUrl) {
    return GestureDetector(
      onTap: () {
        // TODO: Open avatar picker
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFA855F7),
        ),
        child: ClipOval(
          child: imageUrl != null && imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(Icons.person, size: 60, color: Colors.white),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 40, color: Colors.white),
                      SizedBox(height: 4),
                      Text(
                        'add pic',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

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
