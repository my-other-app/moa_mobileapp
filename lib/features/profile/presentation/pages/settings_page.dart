import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/common/widgets/custom_option_tile.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/widgets/email_verification_banner.dart';
import 'package:finnet/features/notifications/presentation/widgets/push_switches_section.dart';
import 'package:finnet/features/profile/presentation/pages/settings/blocked_users_page.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/volunteer/presentation/providers/volunteer_provider.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/confirmation_dialog.dart';
import 'package:finnet/features/main/presentation/pages/main_shell.dart';

/// Settings page - fully migrated to Riverpod (no Bloc).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
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
    final profile = ref.watch(profileProvider).profile;

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
          // Only for an email/password account that has not verified yet.
          if (profile != null && profile.needsEmailVerification) ...[
            CustomOptionTile(
              key: const ValueKey('settings-verify-email'),
              verticalSpacing: 16,
              leadingIcon: Icons.mark_email_unread_outlined,
              leadingIconColor: const Color(0xFF17A58F),
              title: const Text(
                'Verify Email',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Bring in tickets you booked on the website',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              onTap: () => openEmailVerification(context, profile.email),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            ),
            const Divider(height: 0),
          ],

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

          // The notification switches, which the server keeps: off stops
          // that kind of push and takes this device out of its FCM topics.
          // Nothing shows on a server that keeps none (the system settings
          // still turn every notification off).
          const PushSwitchesSection(),

          CustomOptionTile(
            key: const ValueKey('settings-blocked-users'),
            verticalSpacing: 16,
            leadingIcon: Icons.block,
            title: const Text('Blocked Users'),
            subtitle: const Text(
              'People whose comments you have hidden',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BlockedUsersPage(),
              ),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const Divider(height: 0),

          // Contact Support: the team inbox, not a personal WhatsApp.
          CustomOptionTile(
            key: const ValueKey('settings-support'),
            verticalSpacing: 16,
            leadingImageName: AssetResources.contsctsupport,
            title: const Text('Contact Support'),
            subtitle: const Text(
              supportEmail,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: _emailSupport,
          ),
          const Divider(height: 0),

          CustomOptionTile(
            key: const ValueKey('settings-website'),
            verticalSpacing: 16,
            leadingIcon: Icons.language,
            title: const Text('Website'),
            subtitle: const Text(
              'myotherapp.in',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            onTap: () => _open(websiteUri),
          ),
          const Divider(height: 0),

          // The policies live on the website, so the copy people read is
          // the one we keep current.
          CustomOptionTile(
            key: const ValueKey('settings-terms'),
            verticalSpacing: 16,
            leadingImageName: AssetResources.termsandcondition,
            title: const Text('Terms and Conditions'),
            onTap: () => _open(termsUri),
          ),
          const Divider(height: 0),

          CustomOptionTile(
            key: const ValueKey('settings-privacy'),
            verticalSpacing: 16,
            leadingImageName: AssetResources.privacypolicy,
            title: const Text('Privacy Policy'),
            onTap: () => _open(privacyPolicyUri),
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

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Open [uri] in the browser, or say it could not be.
  Future<void> _open(Uri uri) async {
    final opened = await ref.read(linkLauncherProvider)(uri);
    if (!opened && mounted) {
      _snack("Couldn't open ${uri.host}${uri.path}. Try again later.");
    }
  }

  /// Write to support. Without a mail app, the address is copied instead,
  /// so there is still a way to reach us.
  Future<void> _emailSupport() async {
    final opened = await ref.read(linkLauncherProvider)(supportEmailUri);
    if (opened || !mounted) return;
    await Clipboard.setData(const ClipboardData(text: supportEmail));
    if (mounted) _snack('No email app found. $supportEmail is copied.');
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    ConfirmationDialog.showDeleteAccount(
      context: context,
      onConfirm: () async {
        try {
          // '/user/delete', not '/api/v1/user/delete': API_BASE_URL already
          // ends in /api/v1, so the prefixed form requested
          // /api/v1/api/v1/user/delete and 404'd every time. Account
          // deletion has therefore never worked -- and the store listings
          // require it to.
          final res = await APIService.instance.request(
            '/user/delete',
            DioMethod.delete,
          );

          if (res.statusCode == 200 || res.data['success'] == true) {
            // Use Riverpod for logout
            ref.read(profileProvider.notifier).clearProfile();
            await ref.read(authStateProvider.notifier).logout();
            ref.read(navigationIndexProvider.notifier).state = 0;

            // The router takes them to sign-in once the session is gone; pushing
            // onboarding here as well made the screen flicker.
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
