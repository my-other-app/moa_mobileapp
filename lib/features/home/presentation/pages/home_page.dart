import 'package:flutter/material.dart';
import 'package:finnet/shared/widgets/search_tab_header.dart';
import 'package:finnet/features/auth/presentation/widgets/email_verification_banner.dart';

import 'package:finnet/features/home/presentation/pages/home_page_tabs/following_events_page.dart';
import 'package:finnet/features/home/presentation/pages/home_page_tabs/for_you_events_page.dart';

/// Home Page - exact same UI as original, with the verify-your-email banner
/// above it for an email/password account that has not verified yet.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const EmailVerificationBanner(),
        Expanded(
          child: SearchTabHeader(
            tabTitles: const ['FOR YOU', 'FOLLOWING'],
            tabPages: [
              ForYouEventsPage(),
              FollowingEventsPage(),
            ],
            searchHintText: 'Search for Events, Interests, Locations....',
            tabFilterTypes: const ['for_you', 'following'],
          ),
        ),
      ],
    );
  }
}
