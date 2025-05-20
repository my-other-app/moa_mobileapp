import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:myotherapp/common/widgets/custom_option_tile.dart';
import 'package:myotherapp/core/blocs/app_bloc/app_bloc_bloc.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_bloc.dart';
import 'package:myotherapp/modules/home/bloc/bottom_nav_event.dart';
import 'package:myotherapp/modules/home/pages/profile_page/settings/terms_and_condition_page.dart';
import 'package:myotherapp/modules/login/pages/onboarding_initial_page.dart';
import 'package:url_launcher/url_launcher.dart';

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
        elevation: 0, // Remove AppBar shadow
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

          // CustomOptionTile(
          //   verticalSpacing: 16,
          //   icon: Icons.help,
          //   title: const Text('Help Centre'),
          //   onTap: () {
          //     // Navigate to help center screen or show dialog
          //   },
          // ),
          const Divider(height: 0),

          // Contact Support Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.contsctsupport,
            title: const Text('Contact Support'),
            onTap: () async {
              if (await canLaunchUrl(
                  Uri.parse("https://wa.me/+917025662019"))) {
                await launchUrl(Uri.parse("https://wa.me/+917025662019"));
              } else {
                // You might want to handle the error gracefully.
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
              // Navigate to T&C screen or show dialog
            },
          ),
          const Divider(height: 0),

          // Privacy Policy Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.privacypolicy,
            title: const Text('Privacy Policy'),
            onTap: () {
              // Navigate to privacy policy
            },
          ),
          const Divider(height: 0),

          // Privacy Policy Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.deleteaccount,
            title: const Text('Delete Account'),
            onTap: () {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder: (BuildContext dialogContext) {
                  return AlertDialog(
                    title: const Text('Confirm Delete'),
                    content: const Text(
                        'Are you sure you want to delete your account?'),
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
                          // Close the dialog
                          Navigator.of(dialogContext).pop();
                          // Dispatch logout event to AppBloc
                          if (context.mounted) {
                            context.read<AppBloc>().add(const LoggedOutEvent());
                            context
                                .read<BottomNavigatorBloc>()
                                .add(UpdateIndexEvent(index: 0));

                            // Navigate to login page and clear navigation stack
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => OnboardingInitialPage(),
                              ),
                              (route) => false,
                            );
                          }
                        },
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
