import 'package:flutter/material.dart';

/// The way into "Your team" from the event page or the ticket, for an event
/// that runs a competition.
class CompetitionEntryCard extends StatelessWidget {
  final VoidCallback onTap;

  const CompetitionEntryCard({super.key, required this.onTap});

  static const entryKey = ValueKey('competition-entry');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          key: entryKey,
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 10, 12),
            child: Row(
              children: [
                Icon(Icons.groups_2_outlined, color: Color(0xFF5B21B6)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your team and submission',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      SizedBox(height: 2),
                      Text(
                        'Make or join a team, hand in your links, book a mentor.',
                        style:
                            TextStyle(fontSize: 12.5, color: Color(0xFF4B5563)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// After an attended event: the organisers' feedback survey.
///
/// The survey is reached by a link only its guest holds (it carries a key).
/// When the app has that link it opens the survey here; when it doesn't --
/// today's server sends it by email only -- this says where to find it.
class FeedbackEntryCard extends StatelessWidget {
  /// Opens the survey; null when the app has no link to it.
  final VoidCallback? onOpen;
  final String? clubName;

  const FeedbackEntryCard({super.key, this.onOpen, this.clubName});

  static const entryKey = ValueKey('feedback-entry');

  @override
  Widget build(BuildContext context) {
    final who = clubName?.trim().isNotEmpty == true ? clubName! : 'The organisers';
    return Container(
      key: entryKey,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How was it?',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            onOpen != null
                ? '$who would like two minutes of your thoughts.'
                : '$who send a short survey by email after the event. '
                    'Open the link in that email to answer it.',
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF065F46)),
          ),
          if (onOpen != null) ...[
            const SizedBox(height: 10),
            FilledButton(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1F8F6B),
                minimumSize: const Size.fromHeight(44),
              ),
              child: const Text('Share feedback'),
            ),
          ],
        ],
      ),
    );
  }
}
