import 'package:flutter/material.dart';

class ClubProfilePage extends StatefulWidget {
  const ClubProfilePage({Key? key}) : super(key: key);

  @override
  State<ClubProfilePage> createState() => _ClubProfilePageState();
}

class _ClubProfilePageState extends State<ClubProfilePage> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Sample tags
    final tags = [
      {'label': 'Coding', 'color': Colors.lightBlue.shade100},
      {'label': 'Entrepreneurship', 'color': Colors.yellow.shade100},
      {'label': 'UI/UX', 'color': Colors.red.shade100},
      {'label': 'Project Management', 'color': Colors.green.shade100},
      {'label': 'Leadership', 'color': Colors.amber.shade100},
      {'label': 'DSA', 'color': Colors.pink.shade100},
      {'label': 'Competitive Coding', 'color': Colors.purple.shade100},
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    'https://avatars.githubusercontent.com/u/98015594?s=280&v=4',
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TinkerHub CET',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          )),
                      const SizedBox(height: 4),
                      const Text('123 Followers',
                          style: TextStyle(
                            fontSize: 12,
                          )),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: tag['color'] as Color,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              tag['label'] as String,
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // Join team logic
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(width: 1.5, color: Color(0xFF2C333D)),
                    ),
                    child: const Text(
                      'JOIN THE TEAM',
                      style: TextStyle(fontSize: 24, color: Color(0xFF2C333D)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      // Follow logic
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF2C333D),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'FOLLOW',
                      style: TextStyle(
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildDescriptionSection(context),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildInfoCard(
                  icon: Icons.school,
                  label: 'College',
                  value: 'COLLEGE OF ENGINEERING\nTRIVANDRUM',
                ),
                _buildInfoCard(
                  icon: Icons.location_on,
                  label: 'Location',
                  value: 'SREEKARYAM, TRIVANDRUM',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton('PAST EVENTS', () {
                  // Navigate to past events
                }),
                _buildActionButton('UPCOMING EVENTS', () {
                  // Navigate to upcoming events
                }),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSocialIcon(Icons.camera_alt, 'Instagram'),
                _buildSocialIcon(Icons.linked_camera, 'LinkedIn'),
                _buildSocialIcon(Icons.video_library, 'YouTube'),
                _buildSocialIcon(Icons.web, 'Website'),
              ],
            ),
            const SizedBox(height: 24),
            _buildRatingSection(context),
            const SizedBox(height: 24),
            Text(
              'ACHIEVEMENTS',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAchievementPlaceholder(),
                _buildAchievementPlaceholder(),
                _buildAchievementPlaceholder(),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Need Help?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Got any questions? We're here to help—hit us up!",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                // Implement call logic, or navigate to contact page
              },
              child: const Text(
                'Call Committee',
                style: TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    const description = """Welcome to TinkerHub CET, a community of 
passionate innovators, creators, and tech enthusiasts driven by 
the mission to learn, build, and grow together! 💡✨
We’re all about cultivating a culture of curiosity and empowering 
students with skills for the future. Through hands-on workshops, 
hackathons, boot camps, and peer-to-peer learning, we aim to 
bridge the gap between academics and real-world applications...""";

    final lines = _expanded ? null : 3; // limit lines if not expanded

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          description,
          maxLines: lines,
          overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          style: const TextStyle(height: 1.4, fontSize: 14),
        ),
        InkWell(
          onTap: () {
            setState(() => _expanded = !_expanded);
          },
          child: Text(
            _expanded ? 'Show Less' : 'Read More',
            style: const TextStyle(
                color: Color(0xFF17A58F),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
                decorationColor: Color(0xFF17A58F),
                fontSize: 14),
          ),
        )
      ],
    );
  }

  // Helper: build the "College" and "Location" cards
  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Helper: "Past Events" / "Upcoming Events" buttons
  Widget _buildActionButton(String text, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  // Helper: build each social icon widget
  Widget _buildSocialIcon(IconData icon, String label) {
    return InkWell(
      onTap: () {
        // Link to the relevant social page
      },
      child: Column(
        children: [
          Icon(icon, size: 32),
          // Or place an Image.asset for a custom social icon
        ],
      ),
    );
  }

  // Helper: rating section
  Widget _buildRatingSection(BuildContext context) {
    return Column(
      children: [
        // The star row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star, color: Colors.amber, size: 32),
            Icon(Icons.star, color: Colors.amber, size: 32),
            Icon(Icons.star, color: Colors.amber, size: 32),
            Icon(Icons.star, color: Colors.amber, size: 32),
            Icon(Icons.star_half, color: Colors.amber, size: 32),
          ],
        ),
        const SizedBox(height: 8),
        // 4.2 RATED
        Text(
          '4.2 RATED',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Rated by 145 Participants',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  // Helper: Achievement placeholder
  Widget _buildAchievementPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        shape: BoxShape.circle, // or a custom shape
      ),
    );
  }
}
