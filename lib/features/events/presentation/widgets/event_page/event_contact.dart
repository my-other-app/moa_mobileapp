import 'package:flutter/material.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_section.dart';

/// "Questions?": who is organising, and their email and phone.
class EventContactSection extends StatelessWidget {
  final EventContact contact;
  final VoidCallback? onEmail;
  final VoidCallback? onCall;

  const EventContactSection({
    super.key,
    required this.contact,
    this.onEmail,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final name = contact.name;
    return EventSection(
      title: 'Questions?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name != null
                ? 'Reach $name, who is organising this event.'
                : 'Reach the organisers directly.',
            style: const TextStyle(fontSize: 14, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 8),
          if (contact.email != null)
            _ContactRow(
              icon: Icons.mail_outline,
              text: contact.email!,
              onTap: onEmail,
            ),
          if (contact.phone != null)
            _ContactRow(
              icon: Icons.phone_outlined,
              text: contact.phone!,
              onTap: onCall,
            ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _ContactRow({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2C333D)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF1D4ED8),
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
