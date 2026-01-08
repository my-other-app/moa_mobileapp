import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:myotherapp/modules/home/pages/event_page/past_events_page.dart';
import 'package:myotherapp/modules/home/pages/event_page/upcoming_events_page.dart';

import '../../custom_widgets/search_tab_header.dart';

/// Events Page - migrated to Riverpod with exact same UI.
class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Wrap in ProviderScope for Riverpod access in child pages
    return ProviderScope(
      child: SearchTabHeader(
        tabTitles: const ['REGISTERED', 'PAST'],
        tabPages: const [UpcomingEventsPage(), PastEventsPage()],
        searchHintText: 'Search for events...',
      ),
    );
  }
}
