import 'package:flutter/material.dart';
import 'package:myotherapp/common/views/custom_option_tile.dart';
import 'package:myotherapp/presentation/home/pages/certificate_page.dart';
import 'package:myotherapp/presentation/home/pages/edit_profile_page.dart';
import 'package:myotherapp/presentation/home/pages/my_badges_page.dart';
import 'package:myotherapp/presentation/home/pages/notifications_page.dart';
import 'package:myotherapp/presentation/home/pages/settings_page.dart';

import '../../../core/resources/asset_resources.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Example tags
    final tags = [
      {'label': 'Coding', 'color': Colors.lightBlue.shade100},
      {'label': 'Entrepreneurship', 'color': Colors.yellow.shade100},
      {'label': 'UI/UX', 'color': Colors.red.shade100},
      {'label': 'Project Management', 'color': Colors.green.shade100},
      {'label': 'Leadership', 'color': Colors.amber.shade100},
      {'label': 'DSA', 'color': Colors.pink.shade100},
      {'label': 'Competitive Coding', 'color': Colors.purple.shade100},
    ];

    // For each menu item, define a label, icon, and onTap function
    final menuItems = [
      {
        'label': 'Edit Profile',
        'icon': AssetResources.editprofile,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditProfilePage()),
          );
        },
      },
      {
        'label': 'My Certificates',
        'icon': AssetResources.mycertificates,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CertificatePage()),
          );
        },
      },
      {
        'label': 'My Badges',
        'icon': AssetResources.mybadges,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MyBadgesPage()),
          );
        },
      },
      {
        'label': 'Notifications',
        'icon': AssetResources.notifications,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NotificationsNewPage()),
          );
        },
      },
      {
        'label': 'Settings',
        'icon': AssetResources.settings,
        'onTap': (BuildContext context) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SettingsPage()),
          );
        },
      },
      {
        'label': 'Log Out',
        'icon': AssetResources.logout,
        'onTap': (BuildContext context) {
          // Perform logout logic here, or navigate to a login page, etc.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Logged out')),
          );
        },
      },
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 40, // If you're using a package like spaced_column
            children: [
              // 1) Avatar, Name, College
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16, // If you're using spaced_row or similar
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.purple.shade500,
                    child: Image.network(
                      'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
                      fit: BoxFit.cover,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      spacing: 24, // If using spaced_column
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: const [
                            Text(
                              'EDWIN EMMANUEL ROY',
                              style: TextStyle(
                                fontSize: 36,
                                fontFamily: 'BebasNeue',
                              ),
                            ),
                            Text(
                              'COLLEGE OF ENGINEERING TRIVANDRUM',
                              style: TextStyle(
                                fontSize: 16,
                                fontFamily: 'BebasNeue',
                              ),
                            ),
                          ],
                        ),
                        // 2) Tags
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              decoration: BoxDecoration(
                                color: tag['color'] as Color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tag['label'] as String,
                                style: const TextStyle(fontSize: 12),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 2) The menu list
              Column(
                children: List.generate(menuItems.length, (index) {
                  final item = menuItems[index];
                  return Column(
                    children: [
                      CustomOptionTile(
                        verticalSpacing: 16,
                        leadingImageName: item['icon'].toString(),
                        title: Text(
                          item['label'] as String,
                          style: const TextStyle(fontSize: 16),
                        ),
                        onTap: () {
                          // Call the function we stored in 'onTap'
                          final onTapFunc =
                              item['onTap'] as void Function(BuildContext);
                          onTapFunc(context);
                        },
                      ),
                      if (index < menuItems.length - 1)
                        const Divider(height: 0),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
