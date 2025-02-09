import 'package:flutter/material.dart';

class EventCard extends StatelessWidget {
  // final String title;
  // final String organizer;
  // final String imageUrl;
  // final List<String> tags;
  // final VoidCallback onTap;

  EventCard({
    Key? key,
    // required this.title,
    // required this.organizer,
    // required this.imageUrl,
    // required this.tags,
    // required this.onTap,
  }) : super(key: key);
  final List<String> tags = [
    "workshop",
    "online",
    "22/09/2005",
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Organizer logo
                CircleAvatar(
                  backgroundImage: NetworkImage(
                    'https://via.placeholder.com/50', // Placeholder logo, replace with actual logo
                  ),
                  radius: 20,
                ),
                const SizedBox(width: 8),
                // Title and organizer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'test',
                        //title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Muhammed R',
                        //organizer,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Share icon
                IconButton(
                  onPressed: () {
                    // Share event logic
                  },
                  icon: const Icon(Icons.share, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Event Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
            child: Image.network(
              "https://fastly.picsum.photos/id/288/536/354.jpg?hmac=0_DALLGv6guhuEVpDdbFjlA-yvbIhMjnl1YhHtfhW10",
              //imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Tags Row
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: tags
                  .map(
                    (tag) => Row(
                      children: [
                        Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const Text(
                          " ★ ",
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),

          // Call-to-Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'TAKE A CLOSER LOOK OF THE EVENT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
