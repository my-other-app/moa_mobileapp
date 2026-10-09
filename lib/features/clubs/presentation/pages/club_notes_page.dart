import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:finnet/features/clubs/presentation/pages/no_notes_page.dart';
import 'package:finnet/features/clubs/presentation/providers/clubs_provider.dart';
import 'package:finnet/shared/widgets/note_card.dart';

/// The NOTES tab on a club's page.
///
/// This used to be four hardcoded "Tinkerhub HQ" cards with a picsum
/// placeholder image, and it was commented out of the tab anyway -- the tab
/// rendered the empty state unconditionally, so a club's notes were
/// invisible no matter how many it had posted. Nothing in the app had ever
/// called /clubs/notes/list/{club_id}.
class ClubNotesPage extends ConsumerWidget {
  final int clubId;
  final String clubName;
  final String? clubLogoUrl;

  const ClubNotesPage({
    super.key,
    required this.clubId,
    required this.clubName,
    this.clubLogoUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesAsync = ref.watch(clubNotesProvider(clubId));
    // Fetched rather than taken from the route: navigation extras are absent
    // on a deep link, and most callers never set them, so relying on them
    // left every card showing the club's initial instead of its logo.
    final logo = ref.watch(clubLogoProvider(clubId)).valueOrNull ?? clubLogoUrl;

    return ColoredBox(
      color: Colors.white,
      child: notesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _NotesError(
          onRetry: () => ref.invalidate(clubNotesProvider(clubId)),
        ),
        data: (notes) {
          // A club with nothing to say gets the same empty state as before;
          // the difference is that it now means what it says.
          if (notes.isEmpty) return const NoNotesPage();

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(clubNotesProvider(clubId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notes.length,
              // The design leaves a wide gap between cards; they read as
              // separate posts rather than rows of a list.
              separatorBuilder: (_, __) => const SizedBox(height: 28),
              itemBuilder: (context, index) {
                final note = notes[index];
                return NoteCard(
                  logoUrl: logo ?? '',
                  headerTitle: clubName,
                  headerSubtitle: note.relativeTime,
                  cardTitle: note.title,
                  description: note.note,
                  clubId: clubId,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Shown when the notes could not be fetched.
///
/// Distinct from the empty state on purpose: "this club has posted nothing"
/// and "we could not reach the server" are different facts, and the second
/// one is worth retrying.
class _NotesError extends StatelessWidget {
  final VoidCallback onRetry;

  const _NotesError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              "Couldn't load notes",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
