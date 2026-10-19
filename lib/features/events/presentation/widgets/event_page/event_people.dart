import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_section.dart';
import 'package:finnet/shared/utils/external_links.dart';
import 'package:finnet/shared/widgets/app_network_image.dart';

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

IconData personLinkIcon(PersonLinkKind kind) => switch (kind) {
      PersonLinkKind.linkedin => Icons.work_outline,
      PersonLinkKind.instagram => Icons.camera_alt_outlined,
      PersonLinkKind.x => Icons.alternate_email,
      PersonLinkKind.youtube => Icons.play_circle_outline,
      PersonLinkKind.website => Icons.link,
    };

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
Future<void> showPersonSheet(BuildContext context, EventPerson person) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => PersonSheet(person: person),
  );
}

class PersonSheet extends ConsumerWidget {
  final EventPerson person;

  const PersonSheet({super.key, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonAvatar(person: person, size: 88),
              const SizedBox(height: 12),
              Text(
                person.name,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              if (person.role != null) ...[
                const SizedBox(height: 4),
                Text(
                  person.role!,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                ),
              ],
              if (person.bio != null) ...[
                const SizedBox(height: 16),
                Text(
                  person.bio!,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
              ],
              if (person.links.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final link in person.links)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final opened =
                              await ref.read(linkLauncherProvider)(link.uri);
                          if (!opened && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Couldn't open that link")),
                            );
                          }
                        },
                        icon: Icon(personLinkIcon(link.kind), size: 18),
                        label: Text(link.label),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2C333D),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
