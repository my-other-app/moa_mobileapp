import 'package:flutter/material.dart';

class RegSuccessfullPage extends StatelessWidget {
  const RegSuccessfullPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // If you need an AppBar with a custom back button, include it here.
      // appBar: AppBar(...),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Top heading text
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  "WOOHOO! YOU’RE OFFICIALLY IN! 🎉🔥",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontFamily: "BebasNeue",
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // The circle with the GIF inside
              Container(
                width: 260,
                height: 260,
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/ticketconfirm.gif', // <-- Your GIF file
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Bottom subtext
              const Text(
                "Hang tight while we whip up your ticket",
                style: TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
