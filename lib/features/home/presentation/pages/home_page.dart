import 'package:flutter/material.dart';
import 'package:myotherapp/shared/widgets/search_tab_header.dart';

import 'package:myotherapp/features/home/presentation/pages/home_page_tabs/following_events_page.dart';
import 'package:myotherapp/features/home/presentation/pages/home_page_tabs/for_you_events_page.dart';

/// Home Page - exact same UI as original.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SearchTabHeader(
      tabTitles: const ['FOR YOU', 'FOLLOWING'],
      tabPages: [
        ForYouEventsPage(),
        FollowingEventsPage(),
      ],
      searchHintText: 'Search for Events, Interests, Locations....',
      tabFilterTypes: const ['for_you', 'following'],
    );
  }
}
