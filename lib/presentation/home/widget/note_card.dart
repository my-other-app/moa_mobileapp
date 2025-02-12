import 'package:flutter/material.dart';

class NoteCard extends StatelessWidget {
  final String logoUrl; // URL to the logo image
  final String headerTitle; // e.g., "Tinkerhub CET"
  final String headerSubtitle; // e.g., "1 hour ago"
  final String cardTitle; // e.g., "Hack. Build. Repeat."
  final String description; // The main body text
  final VoidCallback? onLinkTap;
  // If you want to open a URL or do some action on click of the “open in new” icon

  const NoteCard({
    Key? key,
    required this.logoUrl,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.cardTitle,
    required this.description,
    this.onLinkTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 10.0, right: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFDFC), // Slightly off-white
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E1E1E)), // Dark border
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // The height adjusts based on content
          children: [
            // Top row: logo + header text + open link icon
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Network image
                    Image.network(
                      logoUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 32,
                          height: 32,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    // Header text
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headerSubtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Open link icon
                IconButton(
                  icon: const Icon(
                    Icons.open_in_new,
                    color: Colors.black,
                    size: 30,
                  ),
                  onPressed: onLinkTap,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Card Title
            Text(
              cardTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
