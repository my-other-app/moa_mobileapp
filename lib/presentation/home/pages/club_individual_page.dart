import 'package:flutter/material.dart';
import 'package:myotherapp/presentation/home/pages/club_notes_page.dart';
import 'package:myotherapp/presentation/home/pages/club_profile_page.dart';
import 'package:myotherapp/presentation/home/widget/club_tab_header.dart';

class ClubIndividualPage extends StatelessWidget {
  const ClubIndividualPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ClubTabHeader(
        tabTitles: ["PROFILE", "NOTES"],
        tabPages: [ClubProfilePage(), ClubNotesPage()]);
  }
}
