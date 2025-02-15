import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({Key? key}) : super(key: key);

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: SafeArea(
          child: Column(
            children: [
              // 1) Avatar, Name, College
              Row(
                children: [
                  // Use a custom image or Emoji. For demonstration:
                  CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.purple.shade100,
                      child: Image.network(
                        'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
                        fit: BoxFit.cover,
                      )),
                  const SizedBox(width: 16),
                  // Name & College
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'EDWIN EMMANUEL ROY',
                        style: TextStyle(fontSize: 36, fontFamily: 'BebasNeue'),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'COLLEGE OF ENGINEERING TRIVANDRUM',
                        style: TextStyle(fontSize: 16, fontFamily: 'BebasNeue'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2) Tags
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: tag['color'] as Color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      tag['label'] as String,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // 3) Menu Items
              // We'll build a Column of ListTiles, each separated by Divider
              Column(
                children: List.generate(menuItems.length, (index) {
                  final item = menuItems[index];
                  // Return a "row" for each
                  return Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey.shade200,
                          child: Icon(
                            item['icon'] as IconData,
                            color: Colors.black87,
                          ),
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
                        const Divider(height: 0, thickness: 1),
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
