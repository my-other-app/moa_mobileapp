import 'package:flutter/material.dart';

import '../widget/search_tab_header.dart';
import 'home_page_tabs/following_events_page.dart';
import 'home_page_tabs/for_you_events_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SearchTabHeader(
      tabTitles: const ['FOR YOU', 'FOLLOWING'],
      tabPages: const [
        ForYouEventsPage(),
        FollowingEventsPage(),
      ],
      searchHintText: 'Search for Events, Interests, Locations....',
      // If you have a custom SearchDelegate, provide it here:
      // searchDelegate: MyHomeSearchDelegate(),
    );
  }
}
