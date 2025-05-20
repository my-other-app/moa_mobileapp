import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontSize: 24,
            fontFamily: "BebasNeue",
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              SizedBox(height: 4),
              Text(
                'Last Updated: 20-May-2025',
                style: TextStyle(color: Colors.grey),
              ),
              SizedBox(height: 20),
              Text(
                'Welcome to Myotherapp! We care about your privacy, so here’s the lowdown on how we handle your data.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '1. What We Collect',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'When you use Myotherapp, we may collect:\n\n'
                '- Basic Info: Your name, email, college ID, and profile photo.\n'
                '- Event Interactions: Events you register for, points you earn, and clubs you follow.\n'
                '- Device Info: Stuff like your device type, OS, and app usage stats (used to improve your experience).\n'
                '- Location (Optional): If enabled, we may use your location to suggest nearby events.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '2. Why We Collect It',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '- To create and manage your account\n'
                '- To show you personalized events and feeds\n'
                '- To let you earn and redeem points\n'
                '- To send you notifications about events you’re into\n'
                '- To help clubs manage event participation and logistics\n'
                '- To make the app better based on what’s working (and what’s not)',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '3. Who We Share It With',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We don’t sell your data, ever. We only share it with:\n\n'
                '- Event Organizers: Limited details like your name and email for registration and communication.\n'
                '- Analytics Providers: Anonymized usage data to help improve app performance.\n'
                '- Legal Authorities: Only if we’re legally required to.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '4. Your Controls',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'You’ve got power. You can:\n\n'
                '- Edit or delete your profile anytime\n'
                '- Turn off push notifications\n'
                '- Request deletion of your account and data by emailing support@myotherapp.com',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '5. Data Storage & Security',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We store your info securely using trusted cloud services. We use encryption and best practices to protect your data, but no system is 100% hack-proof. So stay safe out there.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '6. Cookies & Tracking',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'We don’t use cookies (because it’s a mobile app), but we do use app analytics tools like Firebase or Mixpanel to see what features you love most.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '7. Changes to This Policy',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'If we change anything major, we’ll let you know via the app or email. You can always see the latest version here.',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 24),
              Text(
                '8. Contact Us',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Got questions? Privacy concerns? Meme ideas? Hit us up:\n'
                'Email: support@myotherapp.com',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
