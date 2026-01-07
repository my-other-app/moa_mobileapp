import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/features/auth/presentation/providers/login_provider.dart';
import 'package:myotherapp/features/profile/presentation/providers/profile_provider.dart';

/// Profile page showing user information and settings.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF1a1a2e),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF1a1a2e)),
            onPressed: () => context.pushNamed('settings'),
          ),
        ],
      ),
      body: profileState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile header
                  _buildProfileHeader(context, profile, ref),
                  const SizedBox(height: 32),

                  // Menu items
                  _buildMenuItem(
                    icon: Icons.edit_outlined,
                    title: 'Edit Profile',
                    onTap: () => context.pushNamed('editProfile'),
                  ),
                  _buildMenuItem(
                    icon: Icons.interests_outlined,
                    title: 'Interests',
                    onTap: () => context.pushNamed(
                      'onboardingInterests',
                      extra: {'isOnboarding': false},
                    ),
                  ),
                  _buildMenuItem(
                    icon: Icons.face_outlined,
                    title: 'Change Avatar',
                    onTap: () => context.pushNamed(
                      'onboardingAvatar',
                      extra: {'isOnboarding': false},
                    ),
                  ),
                  _buildMenuItem(
                    icon: Icons.card_membership_outlined,
                    title: 'My Certificates',
                    onTap: () => context.pushNamed('certificates'),
                  ),
                  _buildMenuItem(
                    icon: Icons.emoji_events_outlined,
                    title: 'My Badges',
                    onTap: () => context.pushNamed('badges'),
                  ),
                  _buildMenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    onTap: () => context.pushNamed('notifications'),
                  ),
                  const SizedBox(height: 24),

                  // Logout button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context, ref),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Logout',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, profile, WidgetRef ref) {
    return Column(
      children: [
        // Avatar
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFCCC1F0),
            border: Border.all(
              color: const Color(0xFF17A58F),
              width: 3,
            ),
          ),
          child: ClipOval(
            child: profile?.avatar?.image.original != null
                ? Image.network(
                    profile.avatar.image.original,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, size: 50),
                  )
                : const Icon(Icons.person, size: 50, color: Color(0xFF8B7ED8)),
          ),
        ),
        const SizedBox(height: 16),
        // Name
        Text(
          profile?.fullName ?? 'User',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1a1a2e),
          ),
        ),
        const SizedBox(height: 4),
        // Email
        Text(
          profile?.email ?? '',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        if (profile?.organization != null) ...[
          const SizedBox(height: 4),
          Text(
            profile.organization.name,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF17A58F).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF17A58F)),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(loginProvider.notifier).signOut();
              context.goNamed('onboarding');
            },
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
