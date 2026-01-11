import 'package:flutter/material.dart';
import 'package:myotherapp/features/events/presentation/pages/past_events_page.dart';
import 'package:myotherapp/features/events/presentation/pages/upcoming_events_page.dart';

import 'package:myotherapp/shared/widgets/search_tab_header.dart';

/// Events Page - exact same UI as original.
class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SearchTabHeader(
      tabTitles: const ['REGISTERED', 'PAST'],
      tabPages: const [UpcomingEventsPage(), PastEventsPage()],
      searchHintText: 'Search for events...',
      tabFilterTypes: const ['registered', 'past'],
    );
  }
}
