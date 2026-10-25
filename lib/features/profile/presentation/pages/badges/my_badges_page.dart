import 'package:flutter/material.dart';
import 'package:finnet/core/resources/asset_resources.dart';

class MyBadgesPage extends StatelessWidget {
  const MyBadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'BADGES',
          style: TextStyle(
            fontSize: 24,
            fontFamily: "BebasNeue",
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The badge from the old Profile menu row. The GIF this showed
            // (assets/images/mybadges.gif) was deleted in January, so every
            // visit failed to load it.
            Padding(
              padding: const EdgeInsets.all(16),
              child: Image.asset(
                AssetResources.mybadges,
                width: 160,
                height: 160,
              ),
            ),

            const SizedBox(height: 20),

            // The big text message with emojis
            const Text(
              'BADGES DROPPING\nSOON! 🏅🔥',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 48,
                fontFamily: "BebasNeue",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
