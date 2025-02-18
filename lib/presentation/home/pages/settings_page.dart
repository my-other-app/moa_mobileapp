import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

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
        children: [
          // Event Notification Row
          ListTile(
            leading: _buildIconCircle(Icons.notifications, Colors.orange),
            title: const Text('Event Notification'),
            trailing: Switch(
              value: _eventNotification,
              onChanged: (bool newValue) {
                setState(() => _eventNotification = newValue);
              },
            ),
          ),
          const Divider(height: 1),

          ListTile(
            leading: _buildIconCircle(Icons.group, Colors.grey),
            title: const Text('Club Updates'),
            trailing: Switch(
              value: _clubUpdates,
              onChanged: (bool newValue) {
                setState(() => _clubUpdates = newValue);
              },
            ),
          ),
          const Divider(height: 1),

          // Help Centre Row
          ListTile(
            leading: _buildIconCircle(Icons.help, Colors.red),
            title: const Text('Help Centre'),
            onTap: () {
              // Navigate to help center screen or show dialog
            },
          ),
          const Divider(height: 1),

          // Contact Support Row
          ListTile(
            leading: _buildIconCircle(Icons.phone, Colors.orange),
            title: const Text('Contact Support'),
            onTap: () {
              // Navigate to contact screen or show dialog
            },
          ),
          const Divider(height: 1),

          // Terms and Conditions Row
          ListTile(
            leading: _buildIconCircle(Icons.description, Colors.yellow),
            title: const Text('Terms and Conditions'),
            onTap: () {
              // Navigate to T&C screen or show dialog
            },
          ),
          const Divider(height: 1),

          // Privacy Policy Row
          ListTile(
            leading: _buildIconCircle(Icons.lock, Colors.brown),
            title: const Text('Privacy Policy'),
            onTap: () {
              // Navigate to privacy policy
            },
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }

  // Helper method for that round icon look
  Widget _buildIconCircle(IconData icon, Color bgColor) {
    return CircleAvatar(
      backgroundColor: bgColor.withOpacity(0.1),
      child: Icon(
        icon,
        color: bgColor,
      ),
    );
  }
}
