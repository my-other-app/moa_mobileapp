import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:myotherapp/features/auth/presentation/providers/login_provider.dart';

/// Settings page with account options.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _eventNotification = true;
  bool _clubUpdates = false;

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
            'Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // TODO: Implement delete account API call
              await ref.read(loginProvider.notifier).signOut();
              if (mounted) context.goNamed('onboarding');
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref.read(loginProvider.notifier).signOut();
              if (mounted) context.goNamed('onboarding');
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C333D)),
            onPressed: () => context.pop()),
        title: const Text('SETTINGS',
            style: TextStyle(
                fontSize: 24,
                fontFamily: 'BebasNeue',
                color: Color(0xFF2C333D))),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Notification settings
          _buildSectionHeader('Notifications'),
          _buildSwitchTile(
            icon: Icons.event_note,
            title: 'Event Notifications',
            value: _eventNotification,
            onChanged: (v) => setState(() => _eventNotification = v),
          ),
          _buildSwitchTile(
            icon: Icons.group,
            title: 'Club Updates',
            value: _clubUpdates,
            onChanged: (v) => setState(() => _clubUpdates = v),
          ),
          const SizedBox(height: 24),

          // Support
          _buildSectionHeader('Support'),
          _buildTile(
              icon: Icons.headset_mic,
              title: 'Contact Support',
              onTap: () => _launchUrl('https://wa.me/917025662019')),
          const SizedBox(height: 24),

          // Legal
          _buildSectionHeader('Legal'),
          _buildTile(
              icon: Icons.description,
              title: 'Terms and Conditions',
              onTap: () => context.push('/profile/settings/terms')),
          _buildTile(
              icon: Icons.privacy_tip,
              title: 'Privacy Policy',
              onTap: () => context.push('/profile/settings/privacy')),
          const SizedBox(height: 24),

          // Account
          _buildSectionHeader('Account'),
          _buildTile(
              icon: Icons.logout,
              title: 'Logout',
              onTap: _showLogoutDialog,
              color: Colors.orange),
          _buildTile(
              icon: Icons.delete_forever,
              title: 'Delete Account',
              onTap: _showDeleteAccountDialog,
              color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600])),
    );
  }

  Widget _buildSwitchTile(
      {required IconData icon,
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: const Color(0xFF17A58F).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: const Color(0xFF17A58F)),
      ),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: const Color(0xFF17A58F)),
    );
  }

  Widget _buildTile(
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      Color? color}) {
    final iconColor = color ?? const Color(0xFF17A58F);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: TextStyle(fontSize: 16, color: color)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}
