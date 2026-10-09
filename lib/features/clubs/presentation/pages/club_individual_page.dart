import 'package:flutter/material.dart';
import 'package:finnet/features/clubs/presentation/pages/club_profile_page.dart';
import 'package:finnet/shared/widgets/club_tab_header.dart';
import 'package:finnet/features/clubs/presentation/pages/club_notes_page.dart';

class ClubIndividualPage extends StatelessWidget {
  final int clubId;
  final String clubname;
  final String clubSlug;
  final String? clubLogoUrl;
  const ClubIndividualPage(
      {super.key,
      required this.clubId,
      required this.clubname,
      required this.clubSlug,
      this.clubLogoUrl});

  @override
  Widget build(BuildContext context) {
    return ClubTabHeader(
      tabTitles: ["PROFILE", "NOTES"],
      tabPages: [
        ClubProfilePage(
          id: clubId,
        ),
        // Was NoNotesPage() with ClubNotesPage() commented out beside it,
        // so the tab reported "no notes" however many the club had posted.
        ClubNotesPage(
          clubId: clubId,
          clubName: clubname,
          clubLogoUrl: clubLogoUrl,
        )
      ],
      clubName: clubname,
      clubSlug: clubSlug,
    );
  }
}
