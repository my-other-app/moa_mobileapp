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
        child: Padding(
          padding: const EdgeInsets.only(
              left: 20.0, right: 10.0, top: 5, bottom: 10),
          child: SizedBox(
            width: 361,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        'Last Updated: 20-May-2025\n\nWelcome to Finnet! We care about your privacy, so here\'s the lowdown on how we handle your data.\n\n1. What We Collect\nWhen you use Finnet, we may collect:\n- Basic Info: Your name, email, college ID, and profile photo.\n- Event Interactions: Events you register for, points you earn, and clubs you follow.\n- Device Info: Stuff like your device type, OS, and app usage stats (used to improve your experience).\n- Location (Optional): If enabled, we may use your location to suggest nearby events.\n\n2. Why We Collect It\n- To create and manage your account\n- To show you personalized events and feeds\n- To let you earn and redeem points\n- To send you notifications about events you\'re into\n- To help clubs manage event participation and logistics\n- To make the app better based on what\'s working (and what\'s not)\n\n3. Who We Share It With\nWe don\'t sell your data, ever. We only share it with:\n- Event Organizers: Limited details like your name and email for registration and communication.\n- Analytics Providers: Anonymized usage data to help improve app performance.\n- Legal Authorities: Only if we\'re legally required to.\n\n4. Your Controls\nYou\'ve got power. You can:\n- Edit or delete your profile anytime\n- Turn off push notifications\n- Request deletion of your account and data by emailing support@myotherapp.in\n\n5. Data Storage & Security\nWe store your info securely using trusted cloud services. We use encryption and best practices to protect your data, but no system is 100% hack-proof. So stay safe out there.\n\n6. Cookies & Tracking\nWe don\'t use cookies (because it\'s a mobile app), but we do use app analytics tools like Firebase or Mixpanel to see what features you love most.\n\n7. Changes to This Policy\nIf we change anything major, we\'ll let you know via the app or email. You can always see the latest version here.\n\n8. Contact Us\nGot questions? Privacy concerns? Meme ideas? Hit us up:\nEmail: support@myotherapp.in\n',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'DM Sans',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
