import 'package:flutter/material.dart';

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
            // Bordered box containing the GIF
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Some internal padding
                child: Image.asset(
                  'assets/images/mybadges.gif',
                ),
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
