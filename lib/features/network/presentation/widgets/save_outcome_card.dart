import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:finnet/core/themes/app_colors.dart';
import 'package:finnet/features/network/domain/network.dart';
import 'package:finnet/features/network/presentation/providers/network_saver.dart';
import 'package:finnet/features/network/presentation/widgets/note_sheet.dart';
import 'package:finnet/features/network/presentation/widgets/profile_view.dart';

/// How a save went, as a card: who was saved and a way to add a note; or
/// that it waits for a signal; or why it didn't happen.
class SaveOutcomeCard extends StatefulWidget {
  const SaveOutcomeCard({super.key, required this.attempt, this.onClose});

  final SaveAttempt attempt;

  /// The scanner's: back to scanning.
  final VoidCallback? onClose;

  static const savedKey = ValueKey('save-outcome-saved');
  static const laterKey = ValueKey('save-outcome-later');
  static const refusedKey = ValueKey('save-outcome-refused');
  static const noteKey = ValueKey('save-outcome-note');
  static const profileKey = ValueKey('save-outcome-profile');

  @override
  State<SaveOutcomeCard> createState() => _SaveOutcomeCardState();
}

class _SaveOutcomeCardState extends State<SaveOutcomeCard> {
  /// The person as last saved: a note added here shows here.
  NetworkPerson? _person;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: switch (widget.attempt) {
          Saved(:final result) => _saved(context, result),
          SavedLater() => _line(
              key: SaveOutcomeCard.laterKey,
              emoji: '📶',
              title: 'Saved, syncing',
              text: "No signal here. They're saved on this phone and will "
                  'reach your network once you are back online.',
            ),
          SaveRefused(:final message) => _line(
              key: SaveOutcomeCard.refusedKey,
              emoji: '✋',
              title: 'Not saved',
              text: message,
            ),
        },
      ),
    );
  }

  Widget _close() => widget.onClose == null
      ? const SizedBox.shrink()
      : IconButton(
          tooltip: 'Scan the next person',
          onPressed: widget.onClose,
          icon: const Icon(Icons.close),
        );

  Widget _line({
    required Key key,
    required String emoji,
    required String title,
    required String text,
  }) {
    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(text, style: const TextStyle(fontSize: 13.5, height: 1.3)),
            ],
          ),
        ),
        _close(),
      ],
    );
  }

  Widget _saved(BuildContext context, SaveResult result) {
    final person = _person ?? result.person;
    final brief = person.person;
    final profile = result.profile;
    final headline = profile?.headline ?? brief.headline;
    final status = person.mutual
        ? "You've saved each other"
        : !result.created && result.newEncounter
            ? 'Already in your network: met again'
            : !result.created
                ? 'Already in your network'
                : 'Saved to your network';
    final locked = profile?.locked == true;
    return Column(
      key: SaveOutcomeCard.savedKey,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            PersonAvatar(
                picture: profile?.picture ?? brief.picture,
                initials: brief.initials,
                radius: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(profile?.fullName ?? brief.fullName,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  if (headline != null)
                    Text(headline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                          person.mutual
                              ? Icons.handshake_outlined
                              : Icons.check_circle,
                          size: 15,
                          color: const Color(0xFF15803D)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(status,
                            style: const TextStyle(
                                fontSize: 12.5, color: Color(0xFF15803D))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _close(),
          ],
        ),
        if (locked) ...[
          const SizedBox(height: 8),
          const Text("You'll see more if they save you back.",
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ],
        if (person.note != null) ...[
          const SizedBox(height: 8),
          Text('“${person.note}”',
              style:
                  const TextStyle(fontSize: 13.5, fontStyle: FontStyle.italic)),
        ],
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  key: SaveOutcomeCard.noteKey,
                  onPressed: () async {
                    final saved = await showNoteSheet(context, person);
                    if (saved != null && mounted) {
                      setState(() => _person = saved);
                    }
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.ink),
                  icon: const Icon(Icons.edit_note, size: 20),
                  label: Text(person.note == null ? 'Add a note' : 'Edit note'),
                ),
              ),
              if (brief.route != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    key: SaveOutcomeCard.profileKey,
                    onPressed: () => context.push(brief.route!),
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink),
                    child: const Text('View profile'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
