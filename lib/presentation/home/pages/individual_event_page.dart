import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/resources/asset_resources.dart';
import '../widget/svg_icon.dart';

class IndividualEventPage extends StatelessWidget {
  const IndividualEventPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'HACKATHON',
          style: TextStyle(fontSize: 24, fontFamily: 'BebasNeue'),
        ),
        actions: [
          IconButton(
            icon: SvgIcon(svgIconPath: AssetResources.share),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcRZXf3nbnry-f9qbUwAUfTt-pQssbF3JVjFjg&s',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Title & Organizer
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // If you have the TinkerHub logo locally,
                // replace this with your own AssetImage or Icon.
                const CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(
                    'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Oasis Hackathon',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Tinkerhub',
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Info Grid: Date, Registration Fee, Time, etc.
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _infoCard(
                  context,
                  icon: Icons.calendar_month,
                  title: 'Date of Event',
                  value: '25th Jan 2024',
                ),
                _infoCard(
                  context,
                  icon: Icons.payment,
                  title: 'Registration Fee',
                  value: '₹ 499',
                ),
                _infoCard(
                  context,
                  icon: Icons.access_time,
                  title: 'Time of Event',
                  value: '10:00 AM',
                ),
                _infoCard(
                  context,
                  icon: Icons.hourglass_bottom,
                  title: 'Duration',
                  value: '2 Days (Accomodation..)',
                ),
                _infoCard(
                  context,
                  icon: Icons.location_on,
                  title: 'Location',
                  value: 'TinkerSpace Kochi',
                ),
                _infoCard(
                  context,
                  icon: Icons.card_giftcard,
                  title: 'Prize Worth',
                  value: '₹ 50,000',
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Main description
            const Text(
              "TinkerHub presents Hack the Future, a 24-hour adrenaline-packed hackathon where creativity meets technology. "
              "This is your stage to solve real-world problems, showcase your innovative ideas, and create groundbreaking solutions. "
              "Whether you’re a coding wizard, a design genius, or an idea machine, this is your time to shine!",
              style: TextStyle(fontSize: 15),
            ),
            const SizedBox(height: 16),

            // What's in store
            const Text(
              "What's in Store?",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const BulletList([
              'Solve real-world challenges with tech',
              'Mentorship from industry experts',
              'Exciting prizes for top teams',
              'Network with like-minded innovators',
            ]),

            const SizedBox(height: 16),

            // Details
            const Text(
              'Details:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const BulletList([
              'Date: Jan 25',
              'Duration: 24 Hours Non-Stop',
              'Venue: Tinkerspace Kochi',
              'Who Can Join?: Students, Professionals, and Innovators of all skill levels',
            ]),

            const SizedBox(height: 16),

            // Perks
            const Text(
              'Perks:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const BulletList([
              'Free Swags for Participants',
              'Certificates for All',
              'Hands-on Learning and Fun!',
            ]),

            const SizedBox(height: 16),

            // Need Help
            const Text(
              'Need Help?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                // TODO: Implement call or contact
              },
              child: Text(
                'Call Organizer',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Registration closing info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Registration closes in 07hrs 32 mins 23secs',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),

            // Register now button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  // TODO: Navigate to registration page or open link
                },
                child: const Text('REGISTER NOW'),
              ),
            ),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }
}

// Helper Widget for info items
Widget _infoCard(BuildContext context,
    {required IconData icon, required String title, required String value}) {
  return Container(
    width: MediaQuery.of(context).size.width * 0.4, // Adjust for layout
    padding: const EdgeInsets.all(8.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      border: Border.all(color: AppColors.border, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        SizedBox(
          height: 10,
        ),
        Text(title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            )),
        SizedBox(
          height: 10,
        ),
        Text(value,
            style: const TextStyle(
              fontSize: 24,
              fontFamily: 'BebasNeue',
            )),
      ],
    ),
  );
}

// A simple bullet-list widget
class BulletList extends StatelessWidget {
  final List<String> items;
  const BulletList(this.items, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map((item) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 14)),
                  ),
                ],
              ))
          .toList(),
    );
  }
}
