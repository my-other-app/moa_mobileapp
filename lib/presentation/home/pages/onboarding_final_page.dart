import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/screen.dart';

class OnboardingFinalPage extends StatelessWidget {
  const OnboardingFinalPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFFFA0),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      _buildProfileCreatedSection(),
                      const SizedBox(height: 24),
                      _buildProfileImage(),
                      const SizedBox(height: 24),
                      _buildMotivationalText(),
                      const SizedBox(height: 48),
                      _buildStartJourneyButton(context),
                      const SizedBox(
                          height: 80), // Added bottom padding for grass
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/grass.png',
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    return Container(
      width: 150,
      height: 150,
      decoration: ShapeDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/profile_placeholder.png'),
          fit: BoxFit.cover,
        ),
        color: Color(0xFFCCC1F0),
        shape: OvalBorder(),
      ),
    );
  }

  Widget _buildProfileCreatedSection() {
    return SizedBox(
      width: 361,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'PROFILE CREATED  ✅',
                style: TextStyle(
                  color: Color(0xFF1E1E1E),
                  fontSize: 24,
                  fontFamily: 'BebasNeue',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Your profile's all set, now it's time to dive into the events and level up",
            style: TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontFamily: 'DM Sans',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationalText() {
    return SizedBox(
      width: 301,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          children: [
            TextSpan(
              text: "Life's a ",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
            TextSpan(
              text: 'rollercoaster',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: ', and setbacks are just bumps along the ride. ',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
            TextSpan(
              text: 'Success takes time',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: ", so don't rush—",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
            TextSpan(
              text: 'trust the process',
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: " and stay patient. 💫🌱\n\n'",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
            TextSpan(
              text:
                  "Success isn't a sprint, it's a vibe. Keep going, it'll click",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w400,
              ),
            ),
            TextSpan(
              text: ".' ",
              style: TextStyle(
                color: Colors.black,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                fontFamily: 'DM Sans',
                fontWeight: FontWeight.w200,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStartJourneyButton(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: Color(0xFF2C333D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LandingPage()),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 13),
            child: Row(
              children: [
                Text(
                  'START THE JOURNEY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'BebasNeue',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
