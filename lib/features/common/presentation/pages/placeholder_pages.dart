import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Placeholder page for features not yet implemented.
class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF2C333D)),
            onPressed: () => context.pop()),
        title: Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 20,
                fontFamily: 'BebasNeue',
                color: Color(0xFF2C333D))),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.construction, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('$title coming soon',
                style: const TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

/// Certificates page placeholder.
class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(title: 'Certificates');
}

/// Badges page placeholder.
class BadgesPage extends StatelessWidget {
  const BadgesPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(title: 'My Badges');
}

/// Notifications page placeholder.
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(title: 'Notifications');
}

/// Terms and conditions page placeholder.
class TermsPage extends StatelessWidget {
  const TermsPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(title: 'Terms & Conditions');
}

/// Privacy policy page placeholder.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) =>
      const PlaceholderPage(title: 'Privacy Policy');
}
