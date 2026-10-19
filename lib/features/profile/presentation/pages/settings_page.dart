import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/core/resources/asset_resources.dart';
import 'package:finnet/core/utils/error_utils.dart';
import 'package:finnet/features/auth/presentation/providers/auth_provider.dart';
import 'package:finnet/features/auth/presentation/widgets/email_verification_banner.dart';
import 'package:finnet/features/notifications/presentation/widgets/push_switches_section.dart';
import 'package:finnet/features/profile/presentation/pages/settings/blocked_users_page.dart';
import 'package:finnet/features/profile/presentation/pages/settings/privacy_switches_section.dart';
import 'package:finnet/features/profile/presentation/providers/profile_provider.dart';
import 'package:finnet/features/profile/presentation/sign_out.dart';
import 'package:finnet/features/volunteer/presentation/providers/volunteer_provider.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/confirmation_dialog.dart';
import 'package:finnet/shared/widgets/settings_row.dart';
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
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      // One flat list of the Settings design: an emoji in a grey circle and
      // a name, a divider between each two -- switches first, then what
      // opens something, then leaving.
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        children: [
          // The notification switches, which the server keeps: off stops
          // that kind of push and takes this device out of its FCM topics.
          // Nothing shows on a server that keeps none (the system settings
          // still turn every notification off).
          const PushSwitchesSection(),

          // Usage analytics and crash reports: on until turned off, kept on
          // this phone, applied at once and at every start.
          const PrivacySwitchesSection(),

          ...dividedRows([
            // Only for an email/password account that has not verified yet:
            // it brings in tickets booked on the website.
            if (profile != null && profile.needsEmailVerification)
              SettingsRow(
                key: const ValueKey('settings-verify-email'),
                emoji: '📧',
                label: 'Verify Email',
                onTap: () => openEmailVerification(context, profile.email),
              ),

            // Only for a volunteer: scan tickets at their assigned events.
            if (hasVolunteerEvents)
              SettingsRow(
                key: const ValueKey('settings-volunteer'),
                emoji: '🎟️',
                label: 'Volunteer Check-in',
                onTap: () => context.push('/volunteer/events'),
              ),

            // People whose comments are hidden.
            SettingsRow(
              key: const ValueKey('settings-blocked-users'),
              emoji: '🚫',
              label: 'Blocked Users',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BlockedUsersPage(),
                ),
              ),
            ),

            SettingsRow(
              key: const ValueKey('settings-help'),
              emoji: '🚨',
              label: 'Help Centre',
              onTap: () => _open(helpCentreUri),
            ),

            // Contact Support: the team inbox, not a personal WhatsApp.
            SettingsRow(
              key: const ValueKey('settings-support'),
              asset: AssetResources.contsctsupport,
              label: 'Contact Support',
              onTap: _emailSupport,
            ),

            // The policies live on the website, so the copy people read is
            // the one we keep current.
            SettingsRow(
              key: const ValueKey('settings-terms'),
              asset: AssetResources.termsandcondition,
              label: 'Terms and Conditions',
              onTap: () => _open(termsUri),
            ),

            SettingsRow(
              key: const ValueKey('settings-privacy'),
              asset: AssetResources.privacypolicy,
              label: 'Privacy Policy',
              onTap: () => _open(privacyPolicyUri),
            ),

            SettingsRow(
              key: const ValueKey('settings-website'),
              emoji: '🌐',
              label: 'Website',
              onTap: () => _open(websiteUri),
            ),

            SettingsRow(
              key: const ValueKey('settings-delete-account'),
              asset: AssetResources.deleteaccount,
              label: 'Delete Account',
              onTap: () => _showDeleteAccountDialog(context, ref),
            ),

            SettingsRow(
              key: const ValueKey('settings-log-out'),
              asset: AssetResources.logout,
              label: 'Log Out',
              onTap: () => confirmSignOut(context, ref),
            ),
          ]),
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
