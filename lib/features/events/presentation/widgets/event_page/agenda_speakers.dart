import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/common/models/events/agenda_model.dart';
import 'package:finnet/common/models/events/event_page_model.dart';
import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/events/presentation/widgets/event_page/event_people.dart'
    show PersonAvatar;
import 'package:finnet/features/speakers/domain/speaker.dart';

/// A session's speakers on the event page's agenda, each a small pill with
/// their photo and name. One with a page in the speakers directory
/// (`profile_slug`) opens it on a tap, as their card under Speakers does;
/// one without (a hidden profile) is only named.
class AgendaSpeakers extends StatelessWidget {
  const AgendaSpeakers({super.key, required this.speakers});

  final List<AgendaSpeaker> speakers;

  static ValueKey<String> keyOf(AgendaSpeaker speaker) =>
      ValueKey('agenda-speaker-${speaker.eventSpeakerId ?? speaker.name}');

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final speaker in speakers)
          _SpeakerPill(key: keyOf(speaker), speaker: speaker),
      ],
    );
  }
}

class _SpeakerPill extends StatelessWidget {
  const _SpeakerPill({super.key, required this.speaker});

  final AgendaSpeaker speaker;

  @override
  Widget build(BuildContext context) {
    final slug = speaker.profileSlug;
    final opens = slug != null;
    final pill = Container(
      padding: EdgeInsets.fromLTRB(3, 3, opens ? 4 : 10, 3),
      decoration: BoxDecoration(
        color: opens ? Colors.white : Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PersonAvatar(
            person: EventPerson(name: speaker.name, photo: speaker.photo),
            size: 24,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              speaker.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: opens ? AppColors.ink : Colors.grey[700],
              ),
            ),
          ),
          if (opens)
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFF9CA3AF)),
        ],
      ),
    );
    if (!opens) return pill;
    return Semantics(
      button: true,
      label: "${speaker.name}, speaker's page",
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => context.push(speakerRoute(slug)),
          child: pill,
        ),
      ),
    );
  }
}
