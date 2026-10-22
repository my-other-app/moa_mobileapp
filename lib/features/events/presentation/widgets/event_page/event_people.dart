import 'package:flutter/material.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_section.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';
import 'package:finnet/shared/widgets/detail_sheet.dart';

export 'package:finnet/shared/widgets/detail_sheet.dart'
    show personLinkIcon, showDetailSheet, DetailSheet;

/// A person's round photo, over their initials: the initials show while it
/// loads, and if it never does.
class PersonAvatar extends StatelessWidget {
  final EventPerson person;
  final double size;

  const PersonAvatar({super.key, required this.person, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final photo = person.photo;
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFEDEFF2),
      foregroundImage: photo == null
          ? null
          : appImageProvider(
              photo,
              decodeWidth: decodeWidthFor(
                  size, size, MediaQuery.devicePixelRatioOf(context)),
            ),
      onForegroundImageError: photo == null ? null : (_, __) {},
      child: Text(
        person.initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF4B5563),
        ),
      ),
    );
  }
}

/// Speakers, the organising team, or the club's team: one row each, and a
/// sheet with the bio and links on a tap.
class EventPeopleSection extends StatelessWidget {
  final String title;
  final List<EventPerson> people;

  /// Beside the heading ("About the club").
  final Widget? trailing;

  /// Speakers get the bigger photo and their bio's first lines.
  final bool speakers;

  const EventPeopleSection({
    super.key,
    required this.title,
    required this.people,
    this.trailing,
    this.speakers = false,
  });

  @override
  Widget build(BuildContext context) {
    return EventSection(
      title: title,
      trailing: trailing,
      child: Column(
        children: [
          for (final person in people)
            _PersonRow(
              key: ValueKey('person-${person.name}'),
              person: person,
              speaker: speakers,
            ),
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  final EventPerson person;
  final bool speaker;

  const _PersonRow({super.key, required this.person, required this.speaker});

  @override
  Widget build(BuildContext context) {
    final bio = person.bio;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => showPersonSheet(context, person),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PersonAvatar(person: person, size: speaker ? 56 : 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  if (person.role != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        person.role!,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF6B7280)),
                      ),
                    ),
                  if (speaker && bio != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, height: 1.35, color: Color(0xFF4B5563)),
                      ),
                    ),
                ],
              ),
            ),
            if (person.hasMore)
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              ),
          ],
        ),
      ),
    );
  }
}

/// One person: their photo, name, role, bio and links.
Future<void> showPersonSheet(BuildContext context, EventPerson person) =>
    showDetailSheet(context, PersonSheet(person: person));

/// A person's [DetailSheet]: the one the club page's team opens too.
class PersonSheet extends StatelessWidget {
  final EventPerson person;

  const PersonSheet({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return DetailSheet(
      picture: PersonAvatar(person: person, size: 88),
      name: person.name,
      role: person.role,
      body: person.bio,
      links: person.links,
    );
  }
}
