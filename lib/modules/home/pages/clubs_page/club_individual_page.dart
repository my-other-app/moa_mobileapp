import 'package:flutter/material.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/club_notes_page.dart';
import 'package:myotherapp/modules/home/pages/clubs_page/club_profile_page.dart';
import 'package:myotherapp/modules/home/custom_widgets/club_tab_header.dart';

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
      tabTitles: ["PROFILE", "NOTES"],
      tabPages: [
        ClubProfilePage(
          id: clubId,
        ),
        ClubNotesPage()
      ],
      clubName: clubname,
      clubSlug: clubSlug,
    );
  }
}
