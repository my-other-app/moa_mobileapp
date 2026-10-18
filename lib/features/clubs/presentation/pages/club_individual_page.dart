import 'package:flutter/material.dart';
import 'package:finnet/features/clubs/presentation/pages/club_profile_page.dart';
import 'package:finnet/features/threads/presentation/pages/club_threads_page.dart';
import 'package:finnet/shared/widgets/club_tab_header.dart';

class ClubIndividualPage extends StatelessWidget {
  final int clubId;
  final String clubname;
  final String clubSlug;
  const ClubIndividualPage(
      {super.key,
      required this.clubId,
      required this.clubname,
      required this.clubSlug});

  @override
  Widget build(BuildContext context) {
    return ClubTabHeader(
      tabTitles: const ["PROFILE", "THREADS"],
      tabPages: [
        ClubProfilePage(
          id: clubId,
        ),
        // Was NOTES. Clubs post Threads from their dashboard now and no
        // longer write notes, so the tab shows those instead. Each post
        // carries its club's name and logo, so nothing is needed from the
        // route beyond the id.
        ClubThreadsPage(
          clubId: clubId,
          clubName: clubname,
        ),
      ],
      clubName: clubname,
      clubSlug: clubSlug,
      clubId: clubId,
    );
  }
}
