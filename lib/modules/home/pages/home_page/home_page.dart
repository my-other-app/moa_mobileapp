import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/shared/widgets/search_tab_header.dart';

import 'home_page_tabs/following_events_page.dart';
import 'home_page_tabs/for_you_events_page.dart';

/// Home Page - migrated to Riverpod with exact same UI.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap in ProviderScope for Riverpod access in child pages
    return ProviderScope(
      child: SearchTabHeader(
        tabTitles: const ['FOR YOU', 'FOLLOWING'],
        tabPages: [
          ForYouEventsPage(),
          FollowingEventsPage(),
        ],
        searchHintText: 'Search for Events, Interests, Locations....',
      ),
    );
  }
}
