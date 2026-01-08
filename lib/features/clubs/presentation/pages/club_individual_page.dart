import 'package:flutter/material.dart';
import 'package:myotherapp/features/clubs/presentation/pages/club_profile_page.dart';
import 'package:myotherapp/shared/widgets/club_tab_header.dart';
import 'package:myotherapp/features/clubs/presentation/pages/no_notes_page.dart';

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
        NoNotesPage()
        //ClubNotesPage()
      ],
      clubName: clubname,
      clubSlug: clubSlug,
    );
  }
}
