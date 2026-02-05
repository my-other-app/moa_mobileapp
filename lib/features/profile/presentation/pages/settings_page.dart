import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:myotherapp/common/widgets/custom_option_tile.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/core/utils/error_utils.dart';
import 'package:myotherapp/features/auth/presentation/providers/auth_provider.dart';
import 'package:myotherapp/features/home/presentation/providers/bottom_nav_provider.dart';
import 'package:myotherapp/features/profile/presentation/providers/profile_provider.dart';
import 'package:myotherapp/features/auth/presentation/pages/onboarding_initial_page.dart';
import 'package:myotherapp/features/volunteer/presentation/providers/volunteer_provider.dart';
import 'package:myotherapp/shared/widgets/confirmation_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings page - fully migrated to Riverpod (no Bloc).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // Toggles for switches
  bool _eventNotification = true;
  bool _clubUpdates = false;

  @override
  void initState() {
    super.initState();
    // Fetch volunteer events to check if user is a volunteer
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(volunteerProvider.notifier).fetchVolunteerEvents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final volunteerState = ref.watch(volunteerProvider);
    final hasVolunteerEvents = volunteerState.events.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'SETTINGS',
          style: TextStyle(
            fontSize: 24,
            fontFamily: "BebasNeue",
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // Volunteer section (only show if user has volunteer events)
          if (hasVolunteerEvents) ...[
            CustomOptionTile(
              verticalSpacing: 16,
              leadingIcon: Icons.qr_code_scanner,
              leadingIconColor: const Color(0xFF17A58F),
              title: const Text(
                'Volunteer Check-in',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Scan tickets for your assigned events',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () {
                context.push('/volunteer/events');
              },
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
            const Divider(height: 0),
            const SizedBox(height: 8),
          ],

          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.eventnotification,
            title: const Text('Event Notification'),
            onTap: () {},
            trailing: Switch(
              value: _eventNotification,
              onChanged: (bool newValue) {
                setState(() => _eventNotification = newValue);
              },
            ),
          ),
          const Divider(height: 0),

          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.clubsupdate,
            title: const Text('Club Updates'),
            onTap: () {},
            trailing: Switch(
              value: _clubUpdates,
              onChanged: (bool newValue) {
                setState(() => _clubUpdates = newValue);
              },
            ),
          ),
          const Divider(height: 0),
          const Divider(height: 0),

          // Contact Support Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.contsctsupport,
            title: const Text('Contact Support'),
            onTap: () async {
              if (await canLaunchUrl(Uri.parse("https://wa.me/917025662019"))) {
                await launchUrl(
                  Uri.parse("https://wa.me/917025662019"),
                  mode: LaunchMode.externalApplication,
                );
              }
            },
          ),
          const Divider(height: 0),

          // Terms and Conditions Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.termsandcondition,
            title: const Text('Terms and Conditions'),
            onTap: () {
              context.push('/profile/settings/terms');
            },
          ),
          const Divider(height: 0),

          // Privacy Policy Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.privacypolicy,
            title: const Text('Privacy Policy'),
            onTap: () {
              context.push('/profile/settings/privacy');
            },
          ),
          const Divider(height: 0),

          // Delete Account Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.deleteaccount,
            title: const Text('Delete Account'),
            onTap: () {
              _showDeleteAccountDialog(context, ref);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    ConfirmationDialog.showDeleteAccount(
      context: context,
      onConfirm: () async {
        try {
          final res = await APIService.instance.request(
            '/api/v1/user/delete',
            DioMethod.delete,
          );

          if (res.statusCode == 200 || res.data['success'] == true) {
            // Use Riverpod for logout
            ref.read(profileProvider.notifier).clearProfile();
            await ref.read(authStateProvider.notifier).logout();
            ref.read(bottomNavIndexProvider.notifier).resetToHome();

            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => OnboardingInitialPage(),
                ),
                (route) => false,
              );
            }
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to delete account.')),
              );
            }
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(extractErrorMessage(e,
                      defaultMessage: 'Failed to delete account'))),
            );
          }
        }
      },
    );
  }
}
