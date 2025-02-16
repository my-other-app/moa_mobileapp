import 'package:flutter/material.dart';
import 'package:myotherapp/common/views/custom_option_tile.dart';

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

    // Example menu items: label + icon
    final menuItems = [
      {'label': 'Edit Profile', 'icon': Icons.edit},
      {'label': 'My Certificates', 'icon': Icons.folder_open},
      {'label': 'My Badges', 'icon': Icons.workspace_premium},
      {'label': 'Notifications', 'icon': Icons.notifications_none},
      {'label': 'Settings', 'icon': Icons.settings},
      {'label': 'Log Out', 'icon': Icons.logout},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 40,
            children: [
              // 1) Avatar, Name, College
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 16,
                children: [
                  // Use a custom image or Emoji. For demonstration:
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.purple.shade500,
                    child: Image.network(
                      'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Name & College
                  Expanded(
                    child: Column(
                      spacing: 24,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'EDWIN EMMANUEL ROY',
                              style: TextStyle(
                                  fontSize: 36, fontFamily: 'BebasNeue'),
                            ),
                            Text(
                              'COLLEGE OF ENGINEERING TRIVANDRUM',
                              style: TextStyle(
                                  fontSize: 16, fontFamily: 'BebasNeue'),
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

              // 3) Menu Items
              // We'll build a Column of ListTiles, each separated by Divider
              Column(
                children: List.generate(menuItems.length, (index) {
                  final item = menuItems[index];
                  // Return a "row" for each
                  return Column(
                    children: [
                      CustomOptionTile(
                        verticalSpacing: 16,
                        icon: Icon(
                          item['icon'] as IconData,
                          color: Colors.black87,
                        ),
                        title: Text(
                          item['label'] as String,
                          style: const TextStyle(fontSize: 16),
                        ),
                        onTap: () {
                          // TODO: Navigate or handle each item’s action
                        },
                      ),
                      // Divider after each item (skip last if you wish)
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
