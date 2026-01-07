import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/common/widgets/custom_option_tile.dart';
import 'package:myotherapp/core/api/api_helper.dart';
import 'package:myotherapp/core/blocs/app_bloc/app_bloc_bloc.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_bloc.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_event.dart';
import 'package:myotherapp/modules/home/pages/profile_page/settings/privacy_policy_page.dart';
import 'package:myotherapp/modules/home/pages/profile_page/settings/terms_and_condition_page.dart';
import 'package:myotherapp/modules/login/pages/onboarding_initial_page.dart';
import 'package:url_launcher/url_launcher.dart';

/// Settings page - migrated to Riverpod with exact same UI.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Toggles for switches
  bool _eventNotification = true;
  bool _clubUpdates = false;

  @override
  Widget build(BuildContext context) {
    // Wrap in ProviderScope to enable Riverpod in this screen
    return ProviderScope(
      child: _SettingsPageContent(
        eventNotification: _eventNotification,
        clubUpdates: _clubUpdates,
        onEventNotificationChanged: (v) =>
            setState(() => _eventNotification = v),
        onClubUpdatesChanged: (v) => setState(() => _clubUpdates = v),
      ),
    );
  }
}

class _SettingsPageContent extends ConsumerWidget {
  final bool eventNotification;
  final bool clubUpdates;
  final ValueChanged<bool> onEventNotificationChanged;
  final ValueChanged<bool> onClubUpdatesChanged;

  const _SettingsPageContent({
    required this.eventNotification,
    required this.clubUpdates,
    required this.onEventNotificationChanged,
    required this.onClubUpdatesChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.eventnotification,
            title: const Text('Event Notification'),
            onTap: () {},
            trailing: Switch(
              value: eventNotification,
              onChanged: onEventNotificationChanged,
            ),
          ),
          const Divider(height: 0),

          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.clubsupdate,
            title: const Text('Club Updates'),
            onTap: () {},
            trailing: Switch(
              value: clubUpdates,
              onChanged: onClubUpdatesChanged,
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
              } else {
                throw 'Could not launch https://wa.me/+917025662019';
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
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TermsAndConditionPage()),
              );
            },
          ),
          const Divider(height: 0),

          // Privacy Policy Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.privacypolicy,
            title: const Text('Privacy Policy'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PrivacyPolicyPage()),
              );
            },
          ),
          const Divider(height: 0),

          // Delete Account Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.deleteaccount,
            title: const Text('Delete Account'),
            onTap: () {
              _showDeleteAccountDialog(context);
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete your account?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();

                try {
                  final res = await APIService.instance.request(
                    '/api/v1/user/delete',
                    DioMethod.delete,
                  );

                  if (res.statusCode == 200 || res.data['success'] == true) {
                    if (context.mounted) {
                      context.read<AppBloc>().add(const LoggedOutEvent());
                      context
                          .read<BottomNavigatorBloc>()
                          .add(UpdateIndexEvent(index: 0));

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
                        SnackBar(content: Text('Failed to delete account.')),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }
}
