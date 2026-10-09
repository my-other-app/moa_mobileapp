import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:finnet/core/themes/app_colors.dart';

class NoteCard extends StatelessWidget {
  final String logoUrl; // URL to the logo image
  final String headerTitle; // e.g., "Tinkerhub CET"
  final String headerSubtitle; // e.g., "1 hour ago"
  final String cardTitle; // e.g., "Hack. Build. Repeat."
  final String description; // The main body text

  /// The club this note belongs to, for the tap on its logo.
  ///
  /// Previously the tap was hardcoded to `/clubs/1` behind a TODO, so every
  /// note on every club opened the same club -- and on this account that is
  /// a club the user has muted. Null disables the tap rather than sending
  /// someone somewhere arbitrary.
  final int? clubId;
  final String? clubSlug;

  const NoteCard({
    super.key,
    required this.logoUrl,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.cardTitle,
    required this.description,
    this.clubId,
    this.clubSlug,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFC), // Slightly off-white
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5), // Dark border
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // The height adjusts based on content
        children: [
          // Top row: logo + header text + open link icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  // Network image
                  InkWell(
                    onTap: clubId == null
                        ? null
                        : () => context.push('/clubs/$clubId', extra: {
                              'clubSlug': clubSlug ?? '',
                              'clubName': headerTitle,
                              'clubLogoUrl': logoUrl,
                            }),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        logoUrl,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          // A club without a logo is ordinary, so this is a
                          // neutral placeholder rather than a broken-image
                          // icon.
                          return Container(
                            width: 32,
                            height: 32,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: Text(
                              headerTitle.isEmpty
                                  ? '?'
                                  : headerTitle.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Header text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headerTitle,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        headerSubtitle,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w400,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ],
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
          const SizedBox(height: 2),
          // Description
          Text(description, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
