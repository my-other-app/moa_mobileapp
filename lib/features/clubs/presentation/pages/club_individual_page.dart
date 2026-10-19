import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finnet/features/clubs/presentation/pages/club_profile_page.dart';
import 'package:finnet/features/clubs/presentation/providers/club_page_provider.dart';
import 'package:finnet/features/threads/presentation/pages/club_threads_page.dart';
import 'package:finnet/shared/widgets/club_tab_header.dart';

/// A club: its PROFILE and its THREADS. `/clubs/:clubId`, with the club's
/// slug and name in `extra` when the way in knew them.
///
/// The header's name and share link fill in from the club once it loads,
/// so a club opened without them (a notification, the way back after
/// signing in) still shares its page on the website,
/// `myotherapp.in/clubs/{slug}`. Signed out, the slug is what the club is
/// read by.
class ClubIndividualPage extends ConsumerWidget {
  final int clubId;
  final String clubname;
  final String clubSlug;
  const ClubIndividualPage(
      {super.key,
      required this.clubId,
      required this.clubname,
      required this.clubSlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final club =
        ref.watch(clubInfoProvider(ClubKey(clubId, clubSlug))).valueOrNull;
    final name = clubname.trim().isNotEmpty ? clubname : (club?.name ?? '');
    final slug = clubSlug.trim().isNotEmpty ? clubSlug : (club?.slug ?? '');
    // A link by slug alone knows the id only once the club has loaded.
    final id = clubId > 0 ? clubId : (club?.id ?? 0);

    return ClubTabHeader(
      tabTitles: const ["PROFILE", "THREADS"],
      tabPages: [
        ClubProfilePage(id: clubId, slug: clubSlug),
        // Was NOTES. Clubs post Threads from their dashboard now and no
        // longer write notes, so the tab shows those instead. Each post
        // carries its club's name and logo, so nothing is needed from the
        // route beyond the id. Public: it reads the same signed out.
        if (id > 0)
          ClubThreadsPage(
            clubId: id,
            clubName: name,
          )
        else
          const SizedBox.shrink(),
      ],
      clubName: name,
      clubSlug: slug,
      clubId: id,
    );
  }
}
