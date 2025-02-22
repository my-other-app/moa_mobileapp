import 'package:flutter/material.dart';

import '../../../core/resources/asset_resources.dart';
// Replace these with your actual imports
import '../../../core/themes/app_colors.dart';
import '../widget/svg_icon.dart';

// Helper Widget for info items
Widget _infoCard(BuildContext context,
    {required IconData icon, required String title, required String value}) {
  return Container(
    width: (MediaQuery.of(context).size.width - 48) / 2,
    padding: const EdgeInsets.all(8.0),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      border: Border.all(color: AppColors.border, width: 0.5),
    ),
    child: Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Color(0xffF3F3F3),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 24),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w300,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontFamily: 'BebasNeue',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

// A simple bullet-list widget
class BulletList extends StatelessWidget {
  final List<String> items;
  const BulletList(this.items, {super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (item) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(
                    child: Text(item, style: const TextStyle(fontSize: 14))),
              ],
            ),
          )
          .toList(),
    );
  }
}

class IndividualEventPage extends StatelessWidget {
  const IndividualEventPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // AppBar
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

      // Body: Make it scrollable
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 24,
                children: [
                  // Event poster
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: Image.network(
                        'https://static.vecteezy.com/system/resources/previews/022/590/539/original/summer-party-poster-design-music-party-flyer-artwork-template-vector.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // Title & Organizer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
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

                  // Info Grid
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
                        value: '2 Days (Accommodation..)',
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

                  // Main description
                  const Text(
                    "TinkerHub presents Hack the Future, a 24-hour adrenaline-packed hackathon where creativity meets technology. "
                    "This is your stage to solve real-world problems, showcase your innovative ideas, and create groundbreaking solutions. "
                    "Whether you’re a coding wizard, a design genius, or an idea machine, this is your time to shine!",
                    style: TextStyle(fontSize: 15),
                  ),

                  // What's in store
                  const Text(
                    "What's in Store?",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const BulletList([
                    'Solve real-world challenges with tech',
                    'Mentorship from industry experts',
                    'Exciting prizes for top teams',
                    'Network with like-minded innovators',
                  ]),

                  // Details
                  const Text(
                    'Details:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const BulletList([
                    'Date: Jan 25',
                    'Duration: 24 Hours Non-Stop',
                    'Venue: Tinkerspace Kochi',
                    'Who Can Join?: Students, Professionals, and Innovators of all skill levels',
                  ]),

                  // Perks
                  const Text(
                    'Perks:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const BulletList([
                    'Free Swags for Participants',
                    'Certificates for All',
                    'Hands-on Learning and Fun!',
                  ]),

                  // Need Help
                  const Text(
                    'Need Help?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () {
                      // TODO: Implement call or contact
                    },
                    child: Text(
                      'Call Organizer',
                      style: TextStyle(
                        color: Colors.green.shade600,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0).copyWith(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(128),
                  spreadRadius: 5,
                  blurRadius: 7,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Registration closes in 07hrs 32 mins 23secs',
                      textAlign: TextAlign.left,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                  // Register now button
                  FilledButton(
                    onPressed: () {
                      // TODO: Navigate to registration page or open link
                    },
                    child: const Text('REGISTER NOW'),
                  ),
                ],
              ),
            ),
          )
        ],
      ),

      // BottomSheet: pinned at the bottom
      // bottomSheet: Container(
      //   color: Colors.white,
      //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      //   child: Column(
      //     mainAxisSize: MainAxisSize.min, // Only occupy space for the content
      //     children: [
      //       // Registration closes text

      //     ],
      //   ),
      // ),
    );
  }
}
