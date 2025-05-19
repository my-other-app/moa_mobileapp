import 'package:flutter/material.dart';
import 'package:myotherapp/common/widgets/custom_option_tile.dart';
import 'package:myotherapp/core/resources/asset_resources.dart';

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
            onTap: () {
              // Navigate to contact screen or show dialog
            },
          ),
          const Divider(height: 0),

          // Terms and Conditions Row
          CustomOptionTile(
            verticalSpacing: 16,
            leadingImageName: AssetResources.termsandcondition,
            title: const Text('Terms and Conditions'),
            onTap: () {
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
              // Navigate to privacy policy
            },
          ),
        ],
      ),
    );
  }
}
