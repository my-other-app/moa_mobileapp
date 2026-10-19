import 'package:flutter/material.dart';
import 'package:finnet/core/api/api_helper.dart';
import 'package:finnet/features/events/presentation/utils/event_feed.dart';
import 'package:finnet/features/events/presentation/utils/saved_feed.dart';
import 'package:finnet/shared/widgets/event_card.dart';
import 'package:finnet/shared/widgets/error_view.dart';
import 'package:finnet/shared/widgets/shimmer_widgets.dart';
import 'package:finnet/features/events/presentation/pages/no_past_events_page.dart';

class PastEventsPage extends StatefulWidget {
  const PastEventsPage({super.key});

  @override
  State<PastEventsPage> createState() => _PastEventsPageState();
}

class _PastEventsPageState extends State<PastEventsPage>
    with AutomaticKeepAliveClientMixin, SavedFirstPageFeed<PastEventsPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  String feedPage(int offset) =>
      '/events/list?is_registered=true&is_ended=true&offset=$offset&limit=${SavedFirstPageFeed.pageSize}';

  /// The person's own registrations: encrypted.
  @override
  CachePolicy get feedPolicy => CachePolicy.personal;

  @override
  String get feedErrorFallback => 'Could not load past events.';

  @override
  void initState() {
    super.initState();
    fetchFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (isLoading) {
      return Container(
        color: Colors.white,
        child: const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              ShimmerEventCard(),
              SizedBox(height: 32),
              ShimmerEventCard(),
              SizedBox(height: 32),
              ShimmerEventCard(),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        color: Colors.white,
        child: ErrorView(
          message: errorMessage,
          onRetry: fetchFirstPage,
        ),
      );
    }

    if (events.isEmpty) {
      return NoPastEventsPage();
    }

    return NotificationListener<ScrollNotification>(
      onNotification: onFeedScroll,
      child: RefreshIndicator(
        onRefresh: fetchFirstPage,
        child: ListView.separated(
          primary: true,
          padding: const EdgeInsets.all(16),
          itemCount: events.length + (hasMore ? 1 : 0),
          separatorBuilder: (context, index) => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(
              thickness: 1,
              color: Colors.black,
              indent: 50,
              endIndent: 50,
            ),
          ),
          itemBuilder: (context, index) {
            if (index == events.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final event = Map<String, dynamic>.from(
                events[index] as Map? ?? const <String, dynamic>{});
            return eventCardFromJson(
              event,
              status: event['is_attended'] == true
                  ? EventCardStatus.attended
                  : EventCardStatus.notAttended,
              certificateUrl: event['certificate_url'] is String
                  ? event['certificate_url'] as String
                  : null,
              showShareIcon: false,
            );
          },
        ),
      ),
    );
  }
}
