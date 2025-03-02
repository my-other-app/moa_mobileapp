import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A pale yellow background transitioning to white
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF9FFA1), // Pale yellow-ish
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            const Spacer(),

            // The large text with quotes and emojis
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text('"HANG TIGHT FOR\nTHE COURSES!\n 🚀🔥"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: "BebasNeue", fontSize: 48)),
            ),

            const Spacer(),

            // The teacher & students illustration
            // Replace the asset path with your own SVG file location
            SvgPicture.asset(
              'assets/images/teacher.svg',
              width: MediaQuery.of(context).size.width * 0.8,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
